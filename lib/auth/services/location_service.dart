import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/location_model.dart';

class LocationService {
  /// Request location runtime permission via permission_handler
  Future<PermissionStatus> requestPermission() async {
    return await Permission.location.request();
  }

  /// Check current permission status
  Future<PermissionStatus> checkPermissionStatus() async {
    return await Permission.location.status;
  }

  /// Check if location service (GPS) is enabled on device
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Open Android Location Settings screen for the user
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open App Settings screen for permission modification
  Future<bool> openAppSettingsScreen() async {
    return await openAppSettings();
  }

  /// Fetch fresh GPS Position using LocationAccuracy.best with automatic fallback to LocationAccuracy.medium.
  /// Logs status, permission, latitude, and longitude clearly.
  Future<Position> fetchFreshGpsPosition() async {
    print('[GPS] Location Service Status: Checking...');
    var serviceEnabled = await isLocationServiceEnabled();
    print('[GPS] Location Service Status: ${serviceEnabled ? "ENABLED" : "DISABLED"}');

    if (!serviceEnabled) {
      print('[GPS] Location Service is OFF. Opening device location settings...');
      await openLocationSettings();

      final startTime = DateTime.now();
      while (!serviceEnabled && DateTime.now().difference(startTime).inSeconds < 8) {
        await Future.delayed(const Duration(milliseconds: 800));
        serviceEnabled = await isLocationServiceEnabled();
      }
      if (!serviceEnabled) {
        print('[GPS] Location Service Status: STILL DISABLED. Aborting.');
        throw Exception('LOCATION_DISABLED');
      }
    }

    print('[GPS] Permission Status: Checking...');
    var permission = await Geolocator.checkPermission();
    print('[GPS] Permission Status: $permission');

    if (permission == LocationPermission.denied) {
      print('[GPS] Requesting location permission...');
      permission = await Geolocator.requestPermission();
      print('[GPS] Permission Status after request: $permission');
      if (permission == LocationPermission.denied) {
        throw Exception('PERMISSION_DENIED');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('[GPS] Permission Status: PERMANENTLY DENIED');
      throw Exception('PERMISSION_PERMANENTLY_DENIED');
    }

    // Try LocationAccuracy.best first
    try {
      print('[GPS] Fetching coordinates with LocationAccuracy.best...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );
      print('[GPS] Latitude: ${position.latitude}');
      print('[GPS] Longitude: ${position.longitude}');
      return position;
    } catch (bestErr) {
      print('[GPS] LocationAccuracy.best failed ($bestErr). Retrying with LocationAccuracy.medium...');
      try {
        final positionMedium = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
        print('[GPS] Latitude: ${positionMedium.latitude}');
        print('[GPS] Longitude: ${positionMedium.longitude}');
        return positionMedium;
      } catch (retryErr) {
        print('[GPS] LocationAccuracy.medium failed: $retryErr');
        throw Exception('GPS_FETCH_FAILED');
      }
    }
  }

  /// Fetch fresh GPS position with LocationAccuracy.bestForNavigation (NO cached position).
  /// Automatically prompts location settings if GPS is OFF and polls up to 10s for activation.
  Future<UserLocation> getCurrentLocation() async {
    final position = await fetchFreshGpsPosition();

    print('[Geocoding] Converting fresh coordinates into Address...');
    try {
      return await getLocationFromCoordinates(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      print('[Geocoding] Reverse geocoding failed ($e). Returning location with raw coordinates.');
      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        formattedAddress: 'Current Location',
        area: '',
        city: '',
        state: '',
        pincode: '',
      );
    }
  }

  /// Dual-Layer Reverse Geocoding Architecture (100% FREE):
  /// Layer 1: Native System Geocoder (placemarkFromCoordinates).
  /// Layer 2: If native Android geocoder throws PlatformException (IO_ERROR / UNAVAILABLE), automatically falls back to OpenStreetMap Nominatim REST API over HTTP.
  /// Never saves fake addresses or hardcoded fallbacks.
  Future<UserLocation> getLocationFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    // ----------------------------------------------------
    // LAYER 1: Native System Geocoder
    // ----------------------------------------------------
    try {
      print('[LocationService] Layer 1: Attempting Native System Geocoder for ($latitude, $longitude)...');
      final placemarks = await placemarkFromCoordinates(latitude, longitude).timeout(const Duration(seconds: 5));
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        final house = (place.subThoroughfare?.trim().isNotEmpty == true)
            ? place.subThoroughfare!.trim()
            : ((place.name?.trim().isNotEmpty == true && !place.name!.contains(RegExp(r'^\d+$')))
                ? place.name!.trim()
                : '');

        final street = (place.thoroughfare?.trim().isNotEmpty == true)
            ? place.thoroughfare!.trim()
            : (place.street?.trim() ?? '');

        final subLocality = place.subLocality?.trim() ?? '';
        final locality = (place.locality?.trim().isNotEmpty == true)
            ? place.locality!.trim()
            : (place.subAdministrativeArea?.trim() ?? '');

        final city = locality.isNotEmpty ? locality : (place.subAdministrativeArea?.trim() ?? '');
        final state = place.administrativeArea?.trim() ?? '';
        final pincode = place.postalCode?.trim() ?? '';

        final addressParts = <String>[];
        if (house.isNotEmpty) addressParts.add(house);
        if (street.isNotEmpty && street != house) addressParts.add(street);
        if (subLocality.isNotEmpty && subLocality != street) addressParts.add(subLocality);
        if (locality.isNotEmpty && locality != subLocality) addressParts.add(locality);
        if (state.isNotEmpty) addressParts.add(state);
        if (pincode.isNotEmpty) addressParts.add(pincode);

        final formattedAddress = addressParts.isNotEmpty
            ? addressParts.join(', ')
            : '$locality, $state';

        print('[LocationService] Layer 1 SUCCESS (Native System Geocoder): $formattedAddress');

        return UserLocation(
          latitude: latitude,
          longitude: longitude,
          formattedAddress: formattedAddress,
          area: subLocality.isNotEmpty ? subLocality : locality,
          city: city,
          state: state,
          pincode: pincode,
        );
      }
    } catch (e) {
      print('[LocationService] Layer 1 FAILED (Native Geocoder Exception: $e). Switching to Layer 2 Fallback...');
    }

    // ----------------------------------------------------
    // LAYER 2: OpenStreetMap Nominatim REST API (100% FREE)
    // ----------------------------------------------------
    try {
      print('[LocationService] Layer 2: Calling OpenStreetMap Nominatim Reverse Geocoding API for ($latitude, $longitude)...');
      final userLoc = await _fetchNominatimReverseGeocoding(latitude, longitude);
      if (userLoc != null) {
        print('[LocationService] Layer 2 SUCCESS (OpenStreetMap Nominatim): ${userLoc.formattedAddress}');
        return userLoc;
      }
    } catch (e) {
      print('[LocationService] Layer 2 FAILED (Nominatim Exception: $e).');
      if (e is SocketException) {
        throw Exception('No internet connection. Please check your network.');
      }
    }

    throw Exception('Unable to fetch address. Please check your network connection and try again.');
  }

  /// Perform HTTP reverse geocoding via OpenStreetMap Nominatim API (100% FREE)
  Future<UserLocation?> _fetchNominatimReverseGeocoding(double lat, double lng) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1',
      );
      final request = await client.getUrl(url);
      request.headers.set('User-Agent', 'FoodOrderingApp/1.0 (Flutter App)');
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String? ?? '';
        final addr = data['address'] as Map<String, dynamic>? ?? {};

        if (displayName.isNotEmpty) {
          final sublocality = (addr['suburb'] ?? addr['neighbourhood'] ?? addr['residential'] ?? addr['road'] ?? '').toString().trim();
          final locality = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? '').toString().trim();
          final state = (addr['state'] ?? '').toString().trim();
          final postalCode = (addr['postcode'] ?? '').toString().trim();

          final areaName = sublocality.isNotEmpty ? sublocality : locality;
          final cityName = locality.isNotEmpty ? locality : sublocality;

          return UserLocation(
            latitude: lat,
            longitude: lng,
            formattedAddress: displayName,
            area: areaName,
            city: cityName,
            state: state,
            pincode: postalCode,
          );
        }
      }
    } catch (e) {
      print('[Nominatim REST] Exception: $e');
      if (e is SocketException) rethrow;
    } finally {
      client.close();
    }
    return null;
  }

  /// Search places by text query (Layer 1: Native locationFromAddress; Layer 2: Nominatim Search API)
  Future<List<UserLocation>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    // Layer 1: Try Native locationFromAddress
    try {
      final locations = await locationFromAddress(query).timeout(const Duration(seconds: 4));
      final results = <UserLocation>[];
      for (var loc in locations.take(5)) {
        try {
          final userLoc = await getLocationFromCoordinates(loc.latitude, loc.longitude);
          results.add(userLoc);
        } catch (_) {
          results.add(UserLocation(
            latitude: loc.latitude,
            longitude: loc.longitude,
            formattedAddress: query,
            city: query,
            state: '',
            pincode: '',
          ));
        }
      }
      if (results.isNotEmpty) return results;
    } catch (_) {}

    // Layer 2 Fallback: Nominatim Search REST API
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final encoded = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&addressdetails=1&limit=5',
      );
      final request = await client.getUrl(url);
      request.headers.set('User-Agent', 'FoodOrderingApp/1.0 (Flutter App)');
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final list = jsonDecode(body) as List? ?? [];
        final results = <UserLocation>[];

        for (var item in list) {
          final map = item as Map<String, dynamic>;
          final lat = double.tryParse(map['lat'].toString()) ?? 0.0;
          final lng = double.tryParse(map['lon'].toString()) ?? 0.0;
          final displayName = map['display_name'] as String? ?? '';
          final addr = map['address'] as Map<String, dynamic>? ?? {};

          if (lat != 0.0 && lng != 0.0 && displayName.isNotEmpty) {
            final sublocality = (addr['suburb'] ?? addr['neighbourhood'] ?? addr['road'] ?? '').toString().trim();
            final locality = (addr['city'] ?? addr['town'] ?? addr['village'] ?? '').toString().trim();
            final state = (addr['state'] ?? '').toString().trim();
            final postcode = (addr['postcode'] ?? '').toString().trim();

            results.add(UserLocation(
              latitude: lat,
              longitude: lng,
              formattedAddress: displayName,
              area: sublocality.isNotEmpty ? sublocality : locality,
              city: locality.isNotEmpty ? locality : sublocality,
              state: state,
              pincode: postcode,
            ));
          }
        }
        return results;
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return [];
  }
}
