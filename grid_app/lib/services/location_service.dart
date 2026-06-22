import 'package:geolocator/geolocator.dart';

/// A GPS read: either a coordinate (`ok`) or an error message.
class CoordinateResult {
  final double? lat;
  final double? lon;
  final double? accuracy;
  final String? error;

  const CoordinateResult._({this.lat, this.lon, this.accuracy, this.error});

  factory CoordinateResult.success(double lat, double lon, {double? accuracy}) =>
      CoordinateResult._(lat: lat, lon: lon, accuracy: accuracy);

  factory CoordinateResult.failure(String message) =>
      CoordinateResult._(error: message);

  bool get ok => error == null && lat != null && lon != null;
}

/// Field value format for a coordinate: "lat, lon" at 6 decimal places
/// (matches the old app, so PDFs read identically).
String formatCoordinate(double lat, double lon) =>
    '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';

/// Reads the device's current position. Abstracted so controls can be tested
/// with a fake (the geolocator impl is device-only).
abstract class LocationService {
  Future<CoordinateResult> getCoordinate();
}

/// Real implementation over `geolocator` (ported from the old app's
/// LocationService). Owns its permission flow — no permission_handler.
class GeolocatorLocationService implements LocationService {
  @override
  Future<CoordinateResult> getCoordinate() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return CoordinateResult.failure('Location services are disabled.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return CoordinateResult.failure('Location permission denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        return CoordinateResult.failure(
            'Location permission permanently denied.');
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return CoordinateResult.success(pos.latitude, pos.longitude,
          accuracy: pos.accuracy);
    } catch (e) {
      return CoordinateResult.failure('Failed to get location: $e');
    }
  }
}
