class TfliteService {
  Future<String> runModelOnImage(String imagePath) {
    throw UnsupportedError(
      'On-device TFLite scanning is not available on this platform.',
    );
  }

  void close() {}
}
