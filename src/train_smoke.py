"""Train/evaluate a compact binary U-Net on Boreal Subset C smoke masks."""
from __future__ import annotations

import argparse
import random
from pathlib import Path

import numpy as np
from PIL import Image
import torch
from torch import nn
from torch.utils.data import DataLoader, Dataset


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "raw" / "Boreal-Forest-Fire" / "Boreal-Forest-Fire-Subset-C"
CHECKPOINT = ROOT / "models" / "smoke_unet.pt"


class SmokePairs(Dataset):
    def __init__(self, split: str, mask_kind: str, size: int):
        self.image_dir = DATA / "images" / split
        self.mask_dir = DATA / mask_kind / split
        self.size = size
        self.pairs = []
        for image_path in sorted(self.image_dir.iterdir()):
            if image_path.suffix.lower() not in {".jpg", ".jpeg", ".png"}:
                continue
            mask_path = self.mask_dir / f"{image_path.stem}.png"
            if mask_path.is_file():
                self.pairs.append((image_path, mask_path))
        if not self.pairs:
            raise FileNotFoundError(f"No image/mask pairs in {self.image_dir} and {self.mask_dir}")

    def __len__(self):
        return len(self.pairs)

    def __getitem__(self, index):
        image_path, mask_path = self.pairs[index]
        image = Image.open(image_path).convert("RGB").resize((self.size, self.size), Image.Resampling.BILINEAR)
        mask = Image.open(mask_path).convert("L").resize((self.size, self.size), Image.Resampling.NEAREST)
        image_array = np.asarray(image, dtype=np.float32) / 255.0
        mask_array = (np.asarray(mask, dtype=np.uint8) >= 128).astype(np.float32)
        image_tensor = torch.from_numpy(image_array).permute(2, 0, 1)
        mask_tensor = torch.from_numpy(mask_array).unsqueeze(0)
        return image_tensor, mask_tensor


class ConvBlock(nn.Module):
    def __init__(self, in_channels: int, out_channels: int):
        super().__init__()
        self.layers = nn.Sequential(
            nn.Conv2d(in_channels, out_channels, 3, padding=1, bias=False),
            nn.BatchNorm2d(out_channels), nn.ReLU(inplace=True),
            nn.Conv2d(out_channels, out_channels, 3, padding=1, bias=False),
            nn.BatchNorm2d(out_channels), nn.ReLU(inplace=True),
        )

    def forward(self, x):
        return self.layers(x)


class SmokeUNet(nn.Module):
    def __init__(self, width: int = 16):
        super().__init__()
        self.pool = nn.MaxPool2d(2)
        self.enc1 = ConvBlock(3, width)
        self.enc2 = ConvBlock(width, width * 2)
        self.enc3 = ConvBlock(width * 2, width * 4)
        self.enc4 = ConvBlock(width * 4, width * 8)
        self.center = ConvBlock(width * 8, width * 16)
        self.up4 = nn.ConvTranspose2d(width * 16, width * 8, 2, stride=2)
        self.dec4 = ConvBlock(width * 16, width * 8)
        self.up3 = nn.ConvTranspose2d(width * 8, width * 4, 2, stride=2)
        self.dec3 = ConvBlock(width * 8, width * 4)
        self.up2 = nn.ConvTranspose2d(width * 4, width * 2, 2, stride=2)
        self.dec2 = ConvBlock(width * 4, width * 2)
        self.up1 = nn.ConvTranspose2d(width * 2, width, 2, stride=2)
        self.dec1 = ConvBlock(width * 2, width)
        self.head = nn.Conv2d(width, 1, 1)

    def forward(self, x):
        e1 = self.enc1(x)
        e2 = self.enc2(self.pool(e1))
        e3 = self.enc3(self.pool(e2))
        e4 = self.enc4(self.pool(e3))
        center = self.center(self.pool(e4))
        d4 = self.dec4(torch.cat((self.up4(center), e4), dim=1))
        d3 = self.dec3(torch.cat((self.up3(d4), e3), dim=1))
        d2 = self.dec2(torch.cat((self.up2(d3), e2), dim=1))
        d1 = self.dec1(torch.cat((self.up1(d2), e1), dim=1))
        return self.head(d1)


def dice_score(logits, targets):
    predictions = (torch.sigmoid(logits) >= 0.5).float()
    intersection = (predictions * targets).sum(dim=(1, 2, 3))
    denominator = predictions.sum(dim=(1, 2, 3)) + targets.sum(dim=(1, 2, 3))
    return ((2 * intersection + 1) / (denominator + 1)).mean().item()


def run_epoch(model, loader, optimizer, device, scaler, training):
    model.train(training)
    bce = nn.BCEWithLogitsLoss()
    loss_total = dice_total = 0.0
    context = torch.enable_grad() if training else torch.no_grad()
    with context:
        for images, masks in loader:
            images, masks = images.to(device), masks.to(device)
            if training:
                optimizer.zero_grad(set_to_none=True)
            with torch.autocast(device_type="cuda", dtype=torch.float16, enabled=device.type == "cuda"):
                logits = model(images)
                loss = bce(logits, masks)
            if training:
                scaler.scale(loss).backward()
                scaler.step(optimizer)
                scaler.update()
            loss_total += loss.item()
            dice_total += dice_score(logits.detach(), masks)
    return loss_total / len(loader), dice_total / len(loader)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--size", type=int, default=128)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--evaluate", action="store_true", help="evaluate saved checkpoint on manual test masks")
    args = parser.parse_args()
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Device: {device}" + (f" ({torch.cuda.get_device_name(0)})" if device.type == "cuda" else ""))
    model = SmokeUNet().to(device)

    if args.evaluate:
        if not CHECKPOINT.exists():
            raise FileNotFoundError(f"Train first; checkpoint not found: {CHECKPOINT}")
        state = torch.load(CHECKPOINT, map_location=device, weights_only=True)
        model.load_state_dict(state["model"])
        test = SmokePairs("test", "manual_masks", args.size)
        test_loader = DataLoader(test, batch_size=args.batch_size, shuffle=False, num_workers=0)
        loss, dice = run_epoch(model, test_loader, None, device, None, False)
        print(f"Manual-mask test: {len(test)} pairs | BCE {loss:.4f} | Dice {dice:.4f}")
        return

    train = SmokePairs("train", "sam_masks", args.size)
    valid = SmokePairs("valid", "sam_masks", args.size)
    train_loader = DataLoader(train, batch_size=args.batch_size, shuffle=True, num_workers=0, pin_memory=device.type == "cuda")
    valid_loader = DataLoader(valid, batch_size=args.batch_size, shuffle=False, num_workers=0, pin_memory=device.type == "cuda")
    print(f"Paired samples: train={len(train)}, validation={len(valid)}; manual test excluded")
    optimizer = torch.optim.AdamW(model.parameters(), lr=1e-3)
    scaler = torch.amp.GradScaler("cuda", enabled=device.type == "cuda")
    best_dice = -1.0
    CHECKPOINT.parent.mkdir(parents=True, exist_ok=True)
    for epoch in range(1, args.epochs + 1):
        train_loss, train_dice = run_epoch(model, train_loader, optimizer, device, scaler, True)
        val_loss, val_dice = run_epoch(model, valid_loader, None, device, scaler, False)
        print(f"Epoch {epoch:02d}/{args.epochs}: train loss={train_loss:.4f} dice={train_dice:.4f} | val loss={val_loss:.4f} dice={val_dice:.4f}")
        if val_dice > best_dice:
            best_dice = val_dice
            torch.save({"model": model.state_dict(), "size": args.size, "epoch": epoch, "val_dice": val_dice}, CHECKPOINT)
            print(f"Saved best checkpoint: {CHECKPOINT}")


if __name__ == "__main__":
    main()
