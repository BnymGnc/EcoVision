"""Reproducible MobileNetV2 feature extraction + a small trained classifier.

Run manually in development. Never called by Maven, a request or application startup.
All downloads are public source artifacts. No DOA coordinates are training data.
"""
import argparse
import gzip
import hashlib
import json
import time
import urllib.request
import zipfile
from pathlib import Path

import numpy as np
import onnx
import onnxruntime as ort
from onnx import helper, numpy_helper, TensorProto
from PIL import Image, ImageOps
from sklearn.dummy import DummyClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report, confusion_matrix, f1_score
from sklearn.model_selection import GroupShuffleSplit
from sklearn.preprocessing import StandardScaler
from threadpoolctl import threadpool_limits

ROOT = Path(__file__).resolve().parent
CACHE = ROOT / "cache"
DATA = ROOT / "dataset"
OUTPUT = ROOT.parent / "backend/src/main/resources/ml"
SEED = 20261024
LABELS = ["cardboard", "glass", "metal", "paper", "plastic", "trash"]
DATA_URL = "https://raw.githubusercontent.com/garythung/trashnet/master/data/dataset-resized.zip"
MODEL_URL = "https://media.githubusercontent.com/media/onnx/models/main/validated/vision/classification/mobilenet/model/mobilenetv2-12.onnx"


def download(url, destination):
    if not destination.exists():
        print("Downloading", destination.name, flush=True)
        urllib.request.urlretrieve(url, destination)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def preprocess(path):
    with Image.open(path) as image:
        image = ImageOps.exif_transpose(image).convert("RGB")
        # Explicit half-pixel coordinates avoid Pillow/Java tie-rounding differences.
        x = np.minimum(image.width - 1, np.floor((np.arange(224, dtype=np.float64) + 0.5) * image.width / 224)).astype(np.int64)
        y = np.minimum(image.height - 1, np.floor((np.arange(224, dtype=np.float64) + 0.5) * image.height / 224)).astype(np.int64)
        data = np.asarray(image, dtype=np.float32)[y[:, None], x[None, :]] / 255.0
    data = (data - np.array([0.485, 0.456, 0.406], dtype=np.float32)) / np.array([0.229, 0.224, 0.225], dtype=np.float32)
    return np.transpose(data, (2, 0, 1))[None]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--download", action="store_true")
    args = parser.parse_args()
    CACHE.mkdir(parents=True, exist_ok=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    if args.download:
        download(DATA_URL, CACHE / "trashnet.zip")
        download(MODEL_URL, CACHE / "mobilenetv2-12.onnx")
        for name, url in {
            "TRASHNET-LICENSE.txt": "https://raw.githubusercontent.com/garythung/trashnet/master/LICENSE",
            "ONNX-MODELS-LICENSE.txt": "https://raw.githubusercontent.com/onnx/models/main/LICENSE",
        }.items():
            download(url, OUTPUT / name)
        if not DATA.exists():
            with zipfile.ZipFile(CACHE / "trashnet.zip") as archive:
                for member in archive.infolist():
                    resolved = (DATA / member.filename).resolve()
                    if not resolved.is_relative_to(DATA.resolve()):
                        raise ValueError("Unsafe dataset archive path")
                archive.extractall(DATA)

    session_options = ort.SessionOptions()
    session_options.intra_op_num_threads = 2
    session_options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(CACHE / "mobilenetv2-12.onnx"), session_options,
                                  providers=["CPUExecutionProvider"])
    input_name = session.get_inputs()[0].name
    examples, seen_hashes, duplicate_count = [], set(), 0
    for label in LABELS:
        for path in sorted(DATA.rglob(label + "/*.jpg")):
            if path.name.startswith(".") or "__MACOSX" in path.parts:
                continue
            digest = sha(path)
            if digest in seen_hashes:
                duplicate_count += 1
                continue
            seen_hashes.add(digest)
            examples.append({"path": str(path.relative_to(DATA)), "sha256": digest, "label": label})
    if len(examples) < 100:
        raise RuntimeError("Real labeled training images are missing")
    print("Real images:", len(examples), "exact duplicates removed:", duplicate_count, flush=True)
    # Group near-duplicate images before splitting. Object IDs are unavailable
    # in TrashNet, so this reduces leakage without asserting an identity guarantee.
    labels = np.array([LABELS.index(item["label"]) for item in examples])
    perceptual = []
    for item in examples:
        with Image.open(DATA / item["path"]) as image:
            pixels = np.asarray(image.convert("L").resize((9, 8), Image.Resampling.NEAREST))
            perceptual.append(int.from_bytes(np.packbits((pixels[:, 1:] > pixels[:, :-1]).reshape(-1)).tobytes(), "big"))
    groups = list(range(len(examples)))
    def root(index):
        while groups[index] != index:
            groups[index] = groups[groups[index]]
            index = groups[index]
        return index
    for i, first in enumerate(perceptual):
        for j in range(i):
            if (first ^ perceptual[j]).bit_count() <= 3:
                groups[root(i)] = root(j)
    groups = np.array([root(i) for i in range(len(examples))])
    train, held_out = next(GroupShuffleSplit(n_splits=1, test_size=0.30, random_state=SEED)
                           .split(np.arange(len(examples)), labels, groups))
    val_indexes, test_indexes = next(GroupShuffleSplit(n_splits=1, test_size=0.5, random_state=SEED)
                                    .split(held_out, labels[held_out], groups[held_out]))
    validation, test = held_out[val_indexes], held_out[test_indexes]
    assert not set(groups[train]) & set(groups[test])
    assert not set(groups[validation]) & set(groups[test])
    split = {"seed": SEED, "duplicates_removed": duplicate_count, "source_url": DATA_URL,
             "dataset_archive_sha256": sha(CACHE / "trashnet.zip"),
             "split_method": "grouped by exact hash and dHash Hamming distance <=3; object identities unavailable",
             "train": [examples[i] for i in train], "validation": [examples[i] for i in validation],
             "test": [examples[i] for i in test]}
    (ROOT / "split-manifest.json").write_text(json.dumps(split, ensure_ascii=False, indent=2), encoding="utf-8")
    feature_cache = CACHE / "features-half-pixel-nearest-v2.npz"
    if feature_cache.exists():
        features = np.load(feature_cache)["features"]
        if len(features) != len(examples):
            raise RuntimeError("Feature cache belongs to a different dataset")
    else:
        values = []
        for index, example in enumerate(examples):
            values.append(session.run(None, {input_name: preprocess(DATA / example["path"])})[0].reshape(-1))
            if index % 200 == 0:
                print("Extracted", index, "/", len(examples), flush=True)
        features = np.asarray(values)
        np.savez_compressed(feature_cache, features=features)

    scaler = StandardScaler().fit(features[train])
    candidates = []
    for regularization in [0.01, 0.1, 1.0]:
        fitted = LogisticRegression(C=regularization, max_iter=2000, random_state=SEED)
        fitted.fit(scaler.transform(features[train]), labels[train])
        score = f1_score(labels[validation], fitted.predict(scaler.transform(features[validation])), average="macro")
        candidates.append((score, fitted))
    classifier = max(candidates, key=lambda item: item[0])[1]
    predictions = classifier.predict(scaler.transform(features[test]))
    baseline = DummyClassifier(strategy="most_frequent").fit(features[train], labels[train])
    probabilities = classifier.predict_proba(scaler.transform(features[test]))
    selected = probabilities.max(axis=1) >= 0.65
    metrics = {
        "model_version": "ecovision-mobilenetv2-trashnet-20261024-v2",
        "data_count": len(examples), "train_count": len(train), "validation_count": len(validation), "test_count": len(test),
        "macro_f1": f1_score(labels[test], predictions, average="macro"),
        "majority_baseline_macro_f1": f1_score(labels[test], baseline.predict(features[test]), average="macro"),
        "classification_report": classification_report(labels[test], predictions, target_names=LABELS, output_dict=True),
        "confusion_matrix": confusion_matrix(labels[test], predictions).tolist(),
        "rejection_threshold": 0.65, "rejection_rate": float(1 - selected.mean()),
        "accepted_accuracy": float((predictions[selected] == labels[test][selected]).mean()) if selected.any() else None,
        "ood_multiple_object_low_light_evaluation": "not available; no field accuracy claim",
        "object_identity_leakage": "exact duplicates removed; source dataset has no object IDs, so near-duplicate object leakage cannot be excluded",
    }
    model = onnx.load(CACHE / "mobilenetv2-12.onnx")
    original_output = model.graph.output[0].name
    weight = (classifier.coef_ / scaler.scale_).T.astype(np.float32)
    bias = (classifier.intercept_ - (classifier.coef_ / scaler.scale_) @ scaler.mean_).astype(np.float32)
    model.graph.initializer.extend([numpy_helper.from_array(weight, "eco_head_weight"),
                                    numpy_helper.from_array(bias, "eco_head_bias")])
    model.graph.node.extend([
        helper.make_node("Gemm", [original_output, "eco_head_weight", "eco_head_bias"], ["eco_logits"]),
        helper.make_node("Softmax", ["eco_logits"], ["eco_probabilities"], axis=1),
    ])
    del model.graph.output[:]
    model.graph.output.append(helper.make_tensor_value_info("eco_probabilities", TensorProto.FLOAT, [1, len(LABELS)]))
    onnx.checker.check_model(model)
    model_path = OUTPUT / "waste-mobilenet-v1.onnx"
    onnx.save(model, model_path)
    metrics["artifact_sha256"] = sha(model_path)
    metrics["backbone_sha256"] = sha(CACHE / "mobilenetv2-12.onnx")
    exported = ort.InferenceSession(str(model_path), session_options, providers=["CPUExecutionProvider"])
    fixture_dir = ROOT.parent / "backend/src/test/resources/ml"
    fixture_dir.mkdir(parents=True, exist_ok=True)
    fixtures = []
    for label_index in range(len(LABELS)):
        index = next(int(i) for i in test if labels[i] == label_index)
        with Image.open(DATA / examples[index]["path"]) as source:
            fixture = ImageOps.exif_transpose(source).convert("RGB")
            fixture.info.clear()
            fixture_path = fixture_dir / (LABELS[label_index] + ".png")
            fixture.save(fixture_path)
        scores = exported.run(None, {input_name: preprocess(fixture_path)})[0][0]
        with gzip.open(fixture_dir / (fixture_path.name + ".tensor.gz"), "wb") as tensor_file:
            tensor_file.write(preprocess(fixture_path).astype("<f4").tobytes())
        fixtures.append({"file": fixture_path.name, "type": LABELS[int(scores.argmax())],
                         "score": float(scores.max()), "source_sha256": examples[index]["sha256"]})
    (fixture_dir / "expected.json").write_text(json.dumps(fixtures, indent=2), encoding="utf-8")
    timings = []
    for index in test[:30]:
        image = preprocess(DATA / examples[index]["path"])
        started = time.perf_counter()
        output = exported.run(None, {input_name: image})[0]
        timings.append((time.perf_counter() - started) * 1000)
        expected = classifier.predict_proba(scaler.transform(features[index:index + 1]))
        np.testing.assert_allclose(output, expected, atol=1e-4)
    metrics["local_python_cpu_p95_ms"] = float(np.percentile(timings, 95))
    (OUTPUT / "labels.json").write_text(json.dumps(LABELS), encoding="utf-8")
    (ROOT / "metrics.json").write_text(json.dumps(metrics, ensure_ascii=False, indent=2), encoding="utf-8")
    (OUTPUT / "model-metadata.json").write_text(json.dumps({
        "version": metrics["model_version"], "sha256": metrics["artifact_sha256"],
        "input_name": input_name, "input_shape": [1, 3, 224, 224], "labels": LABELS,
        "preprocessing": "EXIF transpose, RGB, 224x224 explicit half-pixel nearest-neighbor, /255, ImageNet mean/std, NCHW",
        "source": DATA_URL, "backbone": MODEL_URL, "seed": SEED,
    }, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in metrics.items() if k not in ["classification_report", "confusion_matrix"]}, indent=2), flush=True)


if __name__ == "__main__":
    with threadpool_limits(limits=2):
        main()
