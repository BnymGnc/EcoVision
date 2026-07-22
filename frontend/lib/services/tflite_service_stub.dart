class TfliteService {
  Future<String> runModelOnImage(String imagePath) {
    throw UnsupportedError(
      'Cihaz içi TFLite taraması bu platformda kullanılamıyor. Tarama için Android uygulamasını kullanın.',
    );
  }

  void close() {}
}
