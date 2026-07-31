import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';

enum LocationStatusState {
  initial,
  fetching,
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
  timeoutError,
  error,
}

class LocationState {
  final LocationStatusState status;
  final bool isFetching;
  final UserLocation? location;
  final String? errorMessage;

  const LocationState({
    this.status = LocationStatusState.initial,
    this.isFetching = false,
    this.location,
    this.errorMessage,
  });

  // Backward compatibility getters
  bool get isLoading => isFetching;
  bool get permissionGranted => status == LocationStatusState.granted;

  LocationState copyWith({
    LocationStatusState? status,
    bool? isFetching,
    UserLocation? location,
    String? errorMessage,
  }) {
    return LocationState(
      status: status ?? this.status,
      isFetching: isFetching ?? this.isFetching,
      location: location ?? this.location,
      errorMessage: errorMessage,
    );
  }
}

class LocationNotifier extends Notifier<LocationState> {
  late final LocationService _locationService;

  @override
  LocationState build() {
    _locationService = LocationService();
    return const LocationState();
  }

  /// Request runtime location permission and fetch GPS coordinates
  Future<bool> requestAndFetchLocation() async {
    // Disable multiple clicks and set fetching state
    if (state.isFetching) return false;

    state = state.copyWith(
      status: LocationStatusState.fetching,
      isFetching: true,
      errorMessage: null,
    );

    try {
      // 1. Check if GPS is enabled on device
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          status: LocationStatusState.serviceDisabled,
          isFetching: false,
          errorMessage: 'Location Services (GPS) are turned off. Please turn on GPS to see nearby restaurants.',
        );
        return false;
      }

      // 2. Request permission via permission_handler
      final permission = await _locationService.requestPermission();

      if (permission.isPermanentlyDenied) {
        state = state.copyWith(
          status: LocationStatusState.permanentlyDenied,
          isFetching: false,
          errorMessage: 'Location permission is permanently denied. Please enable permission in App Settings.',
        );
        return false;
      }

      if (permission.isDenied) {
        state = state.copyWith(
          status: LocationStatusState.denied,
          isFetching: false,
          errorMessage: 'Location permission denied. Please allow location access to continue.',
        );
        return false;
      }

      // 3. Fetch current location position
      final userLocation = await _locationService.getCurrentLocation();

      state = state.copyWith(
        status: LocationStatusState.granted,
        isFetching: false,
        location: userLocation,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('GPS_DISABLED')) {
        state = state.copyWith(
          status: LocationStatusState.serviceDisabled,
          isFetching: false,
          errorMessage: 'GPS is turned off. Please turn on GPS in settings.',
        );
      } else if (errStr.contains('PERMISSION_PERMANENTLY_DENIED')) {
        state = state.copyWith(
          status: LocationStatusState.permanentlyDenied,
          isFetching: false,
          errorMessage: 'Location permission is permanently denied. Please enable it in settings.',
        );
      } else if (errStr.contains('TimeoutException') || errStr.contains('timeLimit')) {
        state = state.copyWith(
          status: LocationStatusState.timeoutError,
          isFetching: false,
          errorMessage: 'GPS Signal Timeout. Please check if GPS is active and try again.',
        );
      } else {
        state = state.copyWith(
          status: LocationStatusState.error,
          isFetching: false,
          errorMessage: errStr.replaceAll('Exception: ', ''),
        );
      }
      return false;
    }
  }

  /// Open Location Settings screen on device
  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  /// Open App Settings screen for permission modification
  Future<void> openAppSettings() async {
    await _locationService.openAppSettingsScreen();
  }

  /// Manually set or update location details
  void setManualLocation({
    required String formattedAddress,
    String city = '',
    String stateName = '',
    String pincode = '',
    double? latitude,
    double? longitude,
  }) {
    final currentLoc = state.location;
    final updated = UserLocation(
      latitude: latitude ?? currentLoc?.latitude ?? 0.0,
      longitude: longitude ?? currentLoc?.longitude ?? 0.0,
      formattedAddress: formattedAddress,
      city: city,
      state: stateName,
      pincode: pincode,
    );
    state = state.copyWith(
      status: LocationStatusState.granted,
      location: updated,
      errorMessage: null,
    );
  }
}

final locationProvider = NotifierProvider<LocationNotifier, LocationState>(() {
  return LocationNotifier();
});
