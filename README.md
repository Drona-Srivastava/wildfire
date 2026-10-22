# IGNIS-FORECAST: smoke segmentation starter

The available labeled image data is **Boreal Forest Fire Subset C**, a smoke-segmentation dataset. The trained smoke model is separate from the wildfire simulation: it does not label flames or burned area and is not being applied to synthetic fire-grid states.

## Data handling

The extracted dataset is expected at `data/raw/Boreal-Forest-Fire/Boreal-Forest-Fire-Subset-C`.

- Training: image/SAM-mask pairs from `images/train` and `sam_masks/train` (1,150 pairs; 34 images do not have a SAM mask and are skipped).
- Validation: image/SAM-mask pairs from `images/valid` and `sam_masks/valid` (227 pairs; 21 images are skipped).
- Final evaluation: the 40 image/manual-mask pairs in `images/test` and `manual_masks/test`. These are intentionally excluded from training and validation.

SAM masks are machine-generated pseudo-labels. The current best checkpoint was selected at epoch 13 (validation Dice 0.8469); its score on the 40 manually labeled test images was Dice 0.7233. Do not interpret smoke segmentation as flame detection or burn-scar mapping.

## Run

The current global `py` environment already has PyTorch with CUDA support, Pillow, and NumPy. The verified bring-up run used 128x128 images and batch size 8; defaults match that quick configuration. From the project root:

```powershell
py src\train_smoke.py --epochs 1
```

Once the one-epoch smoke test completes, train longer with `--epochs 20`. Increase resolution for more detail with `--size 256 --batch-size 4` if GPU memory allows. The best checkpoint is written to `models/smoke_unet.pt`. Use `--evaluate` to evaluate that checkpoint against the manual test masks.

```powershell
py src\train_smoke.py --evaluate
```

To segment one image:

```powershell
py src\predict_smoke.py path\to\image.jpg --output prediction.png
```

The unused Subset A archive was removed during cleanup because its bounding-box/object-detection labels are not used by the smoke model. The incomplete `.crdownload` for BurnedAreaUAV remains untouched while it is downloading.

## Simulation

MATLAB R2026b and the following add-ons are installed: UAV Toolbox, Aerospace Blockset and Aerospace Toolbox, Simulink 3D Animation, Computer Vision Toolbox, and Image Processing Toolbox. The current simulation uses native UAV Scenario blocks for its forest scene and vehicle visualization plus custom MATLAB Function blocks for the illustrative fire spread and grid sensor.

Run the executable wildfire/UAV starter model with:

```powershell
matlab -batch "cd('C:\path\to\wildfire-uav'); addpath('simulation'); run_ignis_sim"
```

See [simulation/README.md](simulation/README.md) for the grid, scene, signal units, assumptions, and next integration stages. It logs a deterministic 300-second scenario to `simulation/results/starter_run.mat`.

## Dataset sources

- [Boreal Forest Fire dataset (Fairdata DOI)](https://doi.org/10.23729/fd-72c6cf74-b8eb-3687-860d-bf93a1ab94c9) — the dataset paper describes Subset C smoke segmentation: [Scientific Data article](https://www.nature.com/articles/s41597-025-05634-0).
- [BurnedAreaUAV v1.1 (Zenodo)](https://doi.org/10.5281/zenodo.7944963) — manually labeled burned/unburned segmentation data. Keep this for the later burned-area task after its download finishes.
