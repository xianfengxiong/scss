import 'package:geolocator/geolocator.dart';

import '../models/gps_data.dart';

class LocationResult {
  final GpsData? gps;
  final String? error;
  const LocationResult({this.gps, this.error});
  bool get ok => gps != null;
}

/// Thin wrapper around geolocator: permission handling + a single fix with
/// accuracy, mapped to our [GpsData] model.
class LocationService {
  Future<LocationResult> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(error: 'Location services are disabled.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(error: 'Location permission denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
            error: 'Location permission permanently denied. Enable it in Settings.');
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return LocationResult(
        gps: GpsData(
          lat: pos.latitude,
          lon: pos.longitude,
          accuracy: pos.accuracy,
          source: GpsSource.auto,
          status: GpsData.statusFromAccuracy(pos.accuracy),
        ),
      );
    } catch (e) {
      return LocationResult(error: 'Failed to get location: $e');
    }
  }
}
