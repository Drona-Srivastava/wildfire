"""Run the trained smoke segmentation model on one image."""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image
import torch

from train_smoke import CHECKPOINT, SmokeUNet


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    parser.add_argument("--output", type=Path, default=Path("smoke_prediction.png"))
    args = parser.parse_args()
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    state = torch.load(CHECKPOINT, map_location=device, weights_only=True)
    size = int(state["size"])
    model = SmokeUNet().to(device)
    model.load_state_dict(state["model"])
    model.eval()
    image = Image.open(args.image).convert("RGB")
    resized = image.resize((size, size), Image.Resampling.BILINEAR)
    tensor = torch.from_numpy(np.asarray(resized, dtype=np.float32) / 255.0).permute(2, 0, 1).unsqueeze(0).to(device)
    with torch.no_grad():
        mask = (torch.sigmoid(model(tensor))[0, 0] >= 0.5).cpu().numpy().astype(np.uint8) * 255
    output = Image.fromarray(mask).resize(image.size, Image.Resampling.NEAREST)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output)
    print(f"Saved smoke mask to {args.output.resolve()}")


if __name__ == "__main__":
    main()
