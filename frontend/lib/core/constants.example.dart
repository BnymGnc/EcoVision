import 'package:latlong2/latlong.dart';

// Copy to constants.dart on a fresh checkout. Never put provider keys here.
class AppConstants {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ecovision-backend-wdr0.onrender.com',
  );
  static const sanliurfaFallback = LatLng(37.1674, 38.7955);
  // An optional public Lottie URL. EcoLottie keeps its icon fallback if empty.
  static const celebrationLottieUrl = '';
}
