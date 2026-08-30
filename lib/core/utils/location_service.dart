import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Default map centre when the device location is unavailable (Mogadishu).
const LatLng kDefaultMapCenter = LatLng(2.0469, 45.3182);

class LocationService {
  const LocationService();

  /// Returns the device position, or null when the service is off or the user
  /// declined. Never throws — callers fall back to manual address entry.
  Future<LatLng?> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 12));
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  double distanceKm(LatLng a, LatLng b) =>
      Geolocator.distanceBetween(
          a.latitude, a.longitude, b.latitude, b.longitude) /
      1000;
}

final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());

/// Cached device position, shared by provider search and the address picker.
final deviceLocationProvider = FutureProvider<LatLng?>(
  (ref) => ref.watch(locationServiceProvider).currentPosition(),
);
