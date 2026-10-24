# EcoVision waste material classifier

Artifact metadata version: `ecovision-mobilenetv2-trashnet-20261024-v2`.

This is an actual trained six-class classifier, not a recorded response. A pretrained MobileNetV2 ONNX backbone extracts 1,000-dimensional features, and a small multinomial logistic classifier is fitted on real TrashNet labels. Backbone weights remain frozen. The classifier head is folded into ONNX Gemm/Softmax operators for Java CPU inference. No Python service, runtime training or weight download is required in production.

## Sources and licences

- [TrashNet](https://github.com/garythung/trashnet), Gary Thung and Mindy Yang: repository MIT licence, distributed with the artifact as `TRASHNET-LICENSE.txt`.
- [ONNX Model Zoo MobileNet](https://github.com/onnx/models/tree/main/validated/vision/classification/mobilenet): repository Apache-2.0 licence, distributed as `ONNX-MODELS-LICENSE.txt`. The pretrained backbone originates from ImageNet training; this project does not redistribute the ImageNet dataset or claim ownership of it.
- DOA coordinates and bin telemetry are **not** training data.

The training script downloads only these public artifacts when explicitly invoked with `--download`. Model and archive SHA-256 values are saved in `metrics.json`, `split-manifest.json` and the packaged metadata. The Java loader verifies the packaged ONNX checksum before enabling it.

## Data, preprocessing and split

2,524 real images remain after removing three exact duplicates. macOS archive metadata is excluded. dHash pairs with Hamming distance at most three are grouped before splitting; no group crosses train/validation/test. Source object identities are unavailable, so undetected near-duplicate/object leakage cannot be ruled out.

Seed: 20261024. Train: 1,754 images; validation: 375; held-out test: 395. No augmentation or synthetic training images are used. Validation chooses the logistic regularisation parameter from 0.01/0.1/1.0; the held-out test is not used to choose it.

Preprocessing: apply EXIF orientation, RGB conversion, explicit half-pixel nearest-neighbour resize to 224×224, divide channels by 255, subtract `[0.485, 0.456, 0.406]`, divide by `[0.229, 0.224, 0.225]`, and arrange NCHW `[1,3,224,224]`. A full tensor comparison test and output comparison on six real image fixtures check Java/Python consistency.

Class order: cardboard, glass, metal, paper, plastic, trash. Generic plastic is not PET verification; generic metal is not aluminum verification. The model cannot read a verified DOA mark or establish deposit eligibility.

## Held-out results

| Metric | Observed |
|---|---:|
| Macro-F1 | 0.7881 |
| Majority-class baseline macro-F1 | 0.0624 |
| Overall accuracy on this test split | 0.8253 |
| Fraction below 0.65 score threshold | 0.2051 |
| Accuracy among retained samples only | 0.9140 |

| Class | Precision | Recall | F1 | Test images |
|---|---:|---:|---:|---:|
| cardboard | 0.9412 | 0.8889 | 0.9143 | 72 |
| glass | 0.8333 | 0.7746 | 0.8029 | 71 |
| metal | 0.8158 | 0.8611 | 0.8378 | 72 |
| paper | 0.8351 | 0.8901 | 0.8617 | 91 |
| plastic | 0.7500 | 0.7941 | 0.7714 | 68 |
| trash | 0.6250 | 0.4762 | 0.5405 | 21 |

The full confusion matrix and machine-readable metrics are in `metrics.json`. These results are not field accuracy. Softmax/classifier scores are not calibrated correctness probabilities. There is no separate labelled out-of-distribution, multiple-object or poor-light evaluation set. A high score can still be wrong. Single-object photos and a user confirmation/retake path remain necessary.

Local Python CPU p95 over 30 held-out image runs was approximately 9.27 ms in the recorded run, excluding HTTP, decoding and database work. Render latency and memory must be evaluated separately; `docs/verification.md` records deployment-shaped tests. One concurrent Java local inference and input bounds protect the small-instance budget. The native allocator/pattern cache is disabled to reduce retained memory.

## Reproduce

```powershell
python -m venv .venv-ml
.\.venv-ml\Scripts\python.exe -m pip install -r ml/requirements.txt
.\.venv-ml\Scripts\python.exe -u ml/train.py --download
```

Generated features and raw images remain ignored development artifacts. The ONNX model, metadata, licences, split manifest, metrics and the small real-image comparison fixtures are delivery artifacts. Synthetic colour blocks in a unit test verify preprocessing only and are not included in reported accuracy.
