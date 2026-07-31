import 'dart:math';

class LocationUtils {
  /// Calculate precise geographic distance between two lat/lng coordinates in kilometers using Haversine formula.
  static double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    // Return 0.0 for invalid/zero coordinates (no fake 999999 values)
    if (startLatitude == 0.0 || startLongitude == 0.0 || endLatitude == 0.0 || endLongitude == 0.0) {
      return 0.0;
    }

    const double earthRadiusKm = 6371.0;

    final double dLat = _degreesToRadians(endLatitude - startLatitude);
    final double dLon = _degreesToRadians(endLongitude - startLongitude);

    final double lat1Rad = _degreesToRadians(startLatitude);
    final double lat2Rad = _degreesToRadians(endLatitude);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1Rad) * cos(lat2Rad);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }

  /// Format numeric distance in KM to user-friendly string (e.g. "2.4 km")
  static String formatDistance(double distanceInKm) {
    if (distanceInKm <= 0.0) return '';
    if (distanceInKm <= 0.1) return '0.1 km';
    if (distanceInKm < 1.0) {
      final meters = (distanceInKm * 1000).round();
      return '$meters m';
    }
    return '${distanceInKm.toStringAsFixed(1)} km';
  }

  /// Check if customer is strictly inside restaurant branch service radius based ONLY on GPS coordinates.
  /// Never uses text comparison, city names, or string addresses.
  static bool isWithinDeliveryRadius({
    required double userLat,
    required double userLng,
    required double branchLat,
    required double branchLng,
    required double radiusKm,
  }) {
    if (userLat == 0.0 || userLng == 0.0 || branchLat == 0.0 || branchLng == 0.0) {
      return false; // Reject missing/zero coordinates
    }

    final double distKm = calculateDistance(userLat, userLng, branchLat, branchLng);
    final double maxServiceRadius = radiusKm > 0 ? radiusKm : 5.0;

    return distKm <= maxServiceRadius;
  }
}
