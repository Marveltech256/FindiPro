import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../models/user_model.dart';

class LocationService {
  Future<Position?> getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return Geolocator.getLastKnownPosition();
      }
      if (permission == LocationPermission.denied) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Calculates geographic distance in kilometers using the Haversine formula.
  static double calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Formats distance into a human-friendly string (e.g. "500 m away" or "2.4 km away").
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m away';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km away';
    }
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  /// Sorts providers adhering to Phase 34 ranking priority:
  /// 1. Premium providers (Priority Ranking)
  /// 2. Verified providers (Trust Presentation)
  /// 3. Basic providers
  /// Within each tier:
  /// - Distance (when GPS position is available)
  /// - Availability
  /// - Rating
  static List<UserModel> sortProvidersByDistance(
    List<UserModel> providers,
    Position? userPosition,
  ) {
    final list = List<UserModel>.from(providers);

    int getTierScore(UserModel u) {
      if (u.isPremiumBadge) return 2;
      if (u.isVerifiedBadge) return 1;
      return 0;
    }

    list.sort((a, b) {
      final tierA = getTierScore(a);
      final tierB = getTierScore(b);

      // Higher tier outranks lower tier
      if (tierA != tierB) {
        return tierB.compareTo(tierA);
      }

      // Within same plan tier:
      if (userPosition != null) {
        final aHasCoord = a.latitude != null && a.longitude != null && (a.latitude != 0 || a.longitude != 0);
        final bHasCoord = b.latitude != null && b.longitude != null && (b.latitude != 0 || b.longitude != 0);

        if (aHasCoord && bHasCoord) {
          final da = calculateDistanceKm(
            userPosition.latitude,
            userPosition.longitude,
            a.latitude!,
            a.longitude!,
          );
          final db = calculateDistanceKm(
            userPosition.latitude,
            userPosition.longitude,
            b.latitude!,
            b.longitude!,
          );
          return da.compareTo(db);
        } else if (aHasCoord) {
          return -1;
        } else if (bHasCoord) {
          return 1;
        }
      }

      // Fallback within tier: availability then rating
      final aAvail = a.available ? 1 : 0;
      final bAvail = b.available ? 1 : 0;
      if (aAvail != bAvail) {
        return bAvail.compareTo(aAvail);
      }

      return b.rating.compareTo(a.rating);
    });

    return list;
  }

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}
