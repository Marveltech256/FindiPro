import 'package:geolocator/geolocator.dart';

class DistanceService {
  static double distanceKm({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    final meters = Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );

    return meters / 1000;
  }
}