import 'package:geocoding/geocoding.dart';
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

  Future<ResolvedLocation> getCurrentEventLocation() async {
    final point = await getCurrentOrFallbackLocation();
    try {
      final geocoding = Geocoding();
      final placemarks = await geocoding.placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      final place = placemarks.isEmpty ? null : placemarks.first;
      if (place != null) {
        final parts = [
          place.street,
          place.subLocality,
          place.subAdministrativeArea,
          place.administrativeArea,
        ].where((part) => part != null && part.trim().isNotEmpty).toList();
        return ResolvedLocation(
          point: point,
          city: place.administrativeArea ?? '',
          district: place.subAdministrativeArea ?? place.locality ?? '',
          address: parts.join(', '),
        );
      }
    } catch (_) {
      // Coordinates still provide a reliable fallback when geocoding is absent.
    }
    return ResolvedLocation(
      point: point,
      city: '',
      district: '',
      address:
          '${point.latitude.toStringAsFixed(6)}, '
          '${point.longitude.toStringAsFixed(6)}',
    );
  }
}

class ResolvedLocation {
  const ResolvedLocation({
    required this.point,
    required this.city,
    required this.district,
    required this.address,
  });

  final LatLng point;
  final String city;
  final String district;
  final String address;
}
