import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';

class LocationService {
  Future<LatLng> getCurrentOrFallbackLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return AppConstants.sanliurfaFallback;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return AppConstants.sanliurfaFallback;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 7),
        ),
      );

      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return AppConstants.sanliurfaFallback;
    }
  }
}
