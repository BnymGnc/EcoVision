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
      throw StateError('Could not decode selected image.');
    }

    final interpreter = _interpreter!;
    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);
    final input = _buildInput(decoded, inputTensor);
    final output = _emptyTensor(outputTensor.shape, outputTensor.type);

    interpreter.run(input, output);

    final scores = _flattenNumbers(output);
    if (scores.isEmpty) {
      throw StateError('The TFLite model returned no scores.');
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
      return 'unknown waste';
    }

    final label = _labels[bestIndex];
    _logger.i('Detected $label with confidence $bestScore');
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
      throw StateError('labels.txt is empty.');
    }
  }

  Object _buildInput(img.Image source, Tensor inputTensor) {
    final shape = inputTensor.shape;
    if (shape.length != 4) {
      throw StateError('Expected a 4D image input tensor, got shape $shape.');
    }

    final isNchw = shape[1] == 1 || shape[1] == 3;
    final height = isNchw ? shape[2] : shape[1];
    final width = isNchw ? shape[3] : shape[2];
    final channels = isNchw ? shape[1] : shape[3];
    if (channels != 1 && channels != 3) {
      throw StateError('Expected 1 or 3 image channels, got $channels.');
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
