import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TfliteService {
  static const _modelPath = 'assets/models/waste.tflite';
  static const _labelsPath = 'assets/models/labels.txt';

  final Logger _logger;

  Interpreter? _interpreter;
  List<String> _labels = const [];

  TfliteService({Logger? logger}) : _logger = logger ?? Logger();

  Future<String> runModelOnImage(String imagePath) async {
    await _ensureLoaded();

    final imageBytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw StateError('Seçilen görsel okunamadı.');
    }

    final interpreter = _interpreter!;
    final inputTensor = interpreter.getInputTensor(0);
    final input = _buildInput(decoded, inputTensor);
    final outputTensors = interpreter.getOutputTensors();
    if (_isObjectDetectionModel(outputTensors)) {
      return _runObjectDetection(interpreter, input, outputTensors);
    }

    final outputTensor = outputTensors.first;
    final output = _emptyTensor(outputTensor.shape, outputTensor.type);
    interpreter.run(input, output);
    return _highestConfidenceLabel(_flattenNumbers(output));
  }

  bool _isObjectDetectionModel(List<Tensor> outputs) {
    return outputs.length >= 4 &&
        outputs[0].shape.length == 3 &&
        outputs[0].shape.last == 4;
  }

  String _runObjectDetection(
    Interpreter interpreter,
    Object input,
    List<Tensor> tensors,
  ) {
    final outputs = <int, Object>{};
    for (var index = 0; index < tensors.length; index++) {
      outputs[index] = _emptyTensor(tensors[index].shape, tensors[index].type);
    }
    interpreter.runForMultipleInputs([input], outputs);

    final classes = _flattenNumbers(outputs[1]!);
    final scores = _flattenNumbers(outputs[2]!);
    final detectedCount =
        _flattenNumbers(outputs[3]!).firstOrNull?.round() ?? 0;
    final candidateCount = detectedCount.clamp(
      0,
      classes.length < scores.length ? classes.length : scores.length,
    );
    if (candidateCount == 0) {
      throw StateError('Görselde tanımlanabilir bir atık bulunamadı.');
    }

    var bestDetection = 0;
    for (var index = 1; index < candidateCount; index++) {
      if (scores[index] > scores[bestDetection]) bestDetection = index;
    }
    final labelIndex = classes[bestDetection].round();
    if (labelIndex < 0 || labelIndex >= _labels.length) {
      throw StateError('Model geçersiz bir atık etiketi döndürdü.');
    }
    _logger.i(
      '${_labels[labelIndex]} etiketi ${scores[bestDetection]} güvenle algılandı',
    );
    return _labels[labelIndex];
  }

  String _highestConfidenceLabel(List<double> scores) {
    if (scores.isEmpty) {
      throw StateError('TFLite modeli bir tahmin puanı döndürmedi.');
    }

    int bestIndex = 0;
    double bestScore = scores.first;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > bestScore) {
        bestIndex = i;
        bestScore = scores[i];
      }
    }

    if (bestIndex >= _labels.length) {
      _logger.w(
        'TFLite output index $bestIndex has no matching label. '
        'labels=${_labels.length}, scores=${scores.length}',
      );
      return 'bilinmeyen atık';
    }

    final label = _labels[bestIndex];
    _logger.i('$label etiketi $bestScore güvenle algılandı');
    return label;
  }

  Future<void> _ensureLoaded() async {
    if (_interpreter != null) {
      return;
    }

    _interpreter = await Interpreter.fromAsset(_modelPath);
    final labelsRaw = await rootBundle.loadString(_labelsPath);
    _labels = labelsRaw
        .split(RegExp(r'\r?\n'))
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);

    if (_labels.isEmpty) {
      throw StateError('labels.txt dosyası boş.');
    }
  }

  Object _buildInput(img.Image source, Tensor inputTensor) {
    final shape = inputTensor.shape;
    if (shape.length != 4) {
      throw StateError('Modelin görsel giriş biçimi desteklenmiyor: $shape.');
    }

    final isNchw = shape[1] == 1 || shape[1] == 3;
    final height = isNchw ? shape[2] : shape[1];
    final width = isNchw ? shape[3] : shape[2];
    final channels = isNchw ? shape[1] : shape[3];
    if (channels != 1 && channels != 3) {
      throw StateError('Model 1 veya 3 görsel kanalı kullanmalı: $channels.');
    }

    final resized = img.copyResize(source, width: width, height: height);
    if (isNchw) {
      return [
        List.generate(
          channels,
          (channel) => List.generate(
            height,
            (y) => List.generate(
              width,
              (x) => _pixelValue(resized.getPixel(x, y), channel, inputTensor),
            ),
          ),
        ),
      ];
    }

    return [
      List.generate(
        height,
        (y) => List.generate(
          width,
          (x) => List.generate(
            channels,
            (channel) =>
                _pixelValue(resized.getPixel(x, y), channel, inputTensor),
          ),
        ),
      ),
    ];
  }

  num _pixelValue(img.Pixel pixel, int channel, Tensor inputTensor) {
    final value = switch (channel) {
      0 => pixel.r,
      1 => pixel.g,
      2 => pixel.b,
      _ => (pixel.r + pixel.g + pixel.b) / 3,
    };

    if (inputTensor.type == TensorType.float32 ||
        inputTensor.type == TensorType.float16 ||
        inputTensor.type == TensorType.float64) {
      return value / 255.0;
    }
    return value.round();
  }

  Object _emptyTensor(List<int> shape, TensorType type) {
    Object build(int dimension) {
      final length = shape[dimension];
      if (dimension == shape.length - 1) {
        return List.filled(length, _zeroFor(type));
      }
      return List.generate(length, (_) => build(dimension + 1));
    }

    return build(0);
  }

  num _zeroFor(TensorType type) {
    return switch (type) {
      TensorType.float16 || TensorType.float32 || TensorType.float64 => 0.0,
      _ => 0,
    };
  }

  List<double> _flattenNumbers(Object value) {
    final scores = <double>[];
    void collect(Object? item) {
      if (item is List) {
        for (final child in item) {
          collect(child);
        }
      } else if (item is num) {
        scores.add(item.toDouble());
      }
    }

    collect(value);
    return scores;
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}
