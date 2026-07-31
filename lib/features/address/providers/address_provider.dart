import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/address.dart';
import '../../../auth/services/location_service.dart';
import '../../../auth/providers/auth_provider.dart';

class AddressState {
  final List<Address> addresses;
  final Address? selectedAddress;
  final String searchQuery;
  final bool isFetchingGps;
  final String? errorMessage;

  const AddressState({
    required this.addresses,
    this.selectedAddress,
    this.searchQuery = '',
    this.isFetchingGps = false,
    this.errorMessage,
  });

  List<Address> get filteredAddresses {
    if (searchQuery.trim().isEmpty) return addresses;
    final q = searchQuery.toLowerCase().trim();
    return addresses.where((a) {
      return a.label.toLowerCase().contains(q) ||
          a.fullAddress.toLowerCase().contains(q) ||
          a.city.toLowerCase().contains(q) ||
          a.area.toLowerCase().contains(q) ||
          a.building.toLowerCase().contains(q) ||
          a.landmark.toLowerCase().contains(q);
    }).toList();
  }

  AddressState copyWith({
    List<Address>? addresses,
    Address? selectedAddress,
    String? searchQuery,
    bool? isFetchingGps,
    String? errorMessage,
  }) {
    return AddressState(
      addresses: addresses ?? this.addresses,
      selectedAddress: selectedAddress ?? this.selectedAddress,
      searchQuery: searchQuery ?? this.searchQuery,
      isFetchingGps: isFetchingGps ?? this.isFetchingGps,
      errorMessage: errorMessage,
    );
  }
}

class AddressNotifier extends Notifier<AddressState> {
  late final LocationService _locationService;
  static const String _persistentAddressKey = 'persistent_user_address';
  static const String _savedAddressesListKey = 'saved_user_addresses_list';

  @override
  AddressState build() {
    _locationService = LocationService();

    // Listen to changes in authProvider to reactively handle session switches
    ref.listen<AuthState>(authProvider, (previous, next) {
      final prevUid = previous?.userModel?.uid;
      final nextUid = next.userModel?.uid;

      if (prevUid != nextUid) {
        if (nextUid == null) {
          clearAddressCache(prevUid);
        } else {
          _loadSavedAddress();
        }
      }
    });

    // Load persisted address and saved address list asynchronously on initialization
    _loadSavedAddress();

    return const AddressState(
      addresses: [],
      selectedAddress: null,
    );
  }

  /// Clear all address states and local caches (called during new user login / logout)
  Future<void> clearAddressCache([String? targetUid]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authUser = ref.read(authProvider).userModel;
      final uid = targetUid ?? authUser?.uid;

      if (uid != null && uid.isNotEmpty) {
        await prefs.remove('${_persistentAddressKey}_$uid');
        await prefs.remove('${_savedAddressesListKey}_$uid');
        await prefs.remove('address_$uid');
      }

      // Purge all legacy un-namespaced keys
      await prefs.remove(_persistentAddressKey);
      await prefs.remove(_savedAddressesListKey);
      await prefs.remove('selectedAddress');
      await prefs.remove('latitude');
      await prefs.remove('longitude');
      await prefs.remove('address');

      state = const AddressState(addresses: [], selectedAddress: null);
      print('[AddressNotifier] Address cache completely cleared for session (uid: $uid).');
    } catch (e) {
      print('[AddressNotifier] Error clearing address cache: $e');
    }
  }

  /// Load persisted delivery address and saved address list from SharedPreferences (Keyed strictly by Auth User UID)
  Future<void> _loadSavedAddress() async {
    try {
      final authUser = ref.read(authProvider).userModel;
      if (authUser == null || authUser.uid.isEmpty) {
        state = const AddressState(addresses: [], selectedAddress: null);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userKey = authUser.uid;

      List<Address> loadedList = [];
      final listJson = prefs.getString('${_savedAddressesListKey}_$userKey');
      if (listJson != null && listJson.isNotEmpty) {
        final decoded = jsonDecode(listJson) as List;
        loadedList = decoded.map((e) => Address.fromMap(e as Map<String, dynamic>, e['id'] ?? '')).toList();
      }

      Address? selectedAddr;
      final savedJson = prefs.getString('${_persistentAddressKey}_$userKey');
      if (savedJson != null && savedJson.isNotEmpty) {
        final map = jsonDecode(savedJson) as Map<String, dynamic>;
        selectedAddr = Address.fromMap(map, map['id'] ?? '');
      }

      // Sync with active Auth user model ONLY if explicit non-zero profile address exists
      if (selectedAddr == null &&
          authUser.formattedAddress != null &&
          authUser.formattedAddress!.isNotEmpty &&
          authUser.latitude != null &&
          authUser.latitude != 0.0) {
        selectedAddr = Address(
          id: 'addr_profile_${authUser.uid}',
          label: 'Saved Address',
          formattedAddress: authUser.formattedAddress!,
          locality: authUser.area ?? '',
          subLocality: authUser.area ?? '',
          city: authUser.city ?? '',
          state: authUser.state ?? '',
          postalCode: authUser.pincode ?? '',
          latitude: authUser.latitude!,
          longitude: authUser.longitude ?? 0.0,
          isDefault: true,
        );
      }

      if (selectedAddr != null) {
        final exists = loadedList.any((a) => a.id == selectedAddr!.id);
        if (!exists) {
          loadedList = [selectedAddr, ...loadedList];
        }
      }

      state = state.copyWith(
        addresses: loadedList,
        selectedAddress: selectedAddr ?? (loadedList.isNotEmpty ? loadedList.first : null),
      );
    } catch (_) {}
  }

  /// Persist current active address and address list into SharedPreferences & Firestore keyed strictly by Auth User UID
  Future<void> _persistAddress(Address address, [List<Address>? list]) async {
    try {
      final authUser = ref.read(authProvider).userModel;
      if (authUser == null) return;

      final prefs = await SharedPreferences.getInstance();
      final userKey = authUser.uid;

      await prefs.setString('${_persistentAddressKey}_$userKey', jsonEncode(address.toMap()));

      final currentList = list ?? state.addresses;
      final jsonList = currentList.map((a) => a.toMap()).toList();
      await prefs.setString('${_savedAddressesListKey}_$userKey', jsonEncode(jsonList));

      // Also persist directly into Firestore subcollection users/{uid}/addresses
      try {
        final addressDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userKey)
            .collection('addresses')
            .doc(address.id);

        final firestoreMap = {
          ...address.toMap(),
          'title': address.label,
          'fullAddress': address.formattedAddress,
          'district': address.city,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await addressDocRef.set(firestoreMap, SetOptions(merge: true));
      } catch (fe) {
        print('[AddressNotifier] Firestore address sync error: $fe');
      }
    } catch (_) {}
  }

  /// Select active delivery address and persist locally & sync with AuthProvider / Firestore
  void selectAddress(Address address, [WidgetRef? ref]) {
    final updatedList = state.addresses.map((a) {
      return a.copyWith(isDefault: a.id == address.id);
    }).toList();

    final selected = address.copyWith(isDefault: true);

    state = state.copyWith(
      addresses: updatedList,
      selectedAddress: selected,
    );

    _persistAddress(selected, updatedList);

    final targetRef = ref;
    if (targetRef != null) {
      targetRef.read(authProvider.notifier).saveUserData(
        formattedAddress: selected.fullAddress,
        area: selected.area,
        latitude: selected.latitude,
        longitude: selected.longitude,
        city: selected.city,
        stateName: selected.state,
        pincode: selected.pincode,
      );
    }
  }

  /// Add new address to saved list and select it
  void addAddress(Address newAddress, [WidgetRef? ref]) {
    final updatedList = state.addresses.map((a) => a.copyWith(isDefault: false)).toList();
    final addressToAdd = newAddress.copyWith(isDefault: true);

    final newList = [...updatedList, addressToAdd];
    state = state.copyWith(
      addresses: newList,
      selectedAddress: addressToAdd,
    );

    _persistAddress(addressToAdd, newList);

    if (ref != null) {
      selectAddress(addressToAdd, ref);
    }
  }

  /// Edit existing address
  void editAddress(Address updatedAddress, [WidgetRef? ref]) {
    final newList = state.addresses.map((a) {
      if (a.id == updatedAddress.id) {
        return updatedAddress;
      }
      return a;
    }).toList();

    Address? newSelected = state.selectedAddress;
    if (state.selectedAddress?.id == updatedAddress.id) {
      newSelected = updatedAddress;
    }

    state = state.copyWith(
      addresses: newList,
      selectedAddress: newSelected,
    );

    if (newSelected != null) {
      _persistAddress(newSelected, newList);
      if (ref != null && newSelected.id == updatedAddress.id) {
        selectAddress(updatedAddress, ref);
      }
    }
  }

  /// Delete address by ID
  void deleteAddress(String id, [WidgetRef? ref]) {
    final newList = state.addresses.where((a) => a.id != id).toList();
    Address? newSelected = state.selectedAddress;

    if (state.selectedAddress?.id == id) {
      newSelected = newList.isNotEmpty ? newList.first : null;
    }

    state = state.copyWith(
      addresses: newList,
      selectedAddress: newSelected,
    );

    // Remove from Firestore subcollection
    try {
      final authUser = ref?.read(authProvider).userModel ?? this.ref.read(authProvider).userModel;
      if (authUser != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(authUser.uid)
            .collection('addresses')
            .doc(id)
            .delete();
      }
    } catch (_) {}

    if (newSelected != null) {
      _persistAddress(newSelected, newList);
      if (ref != null) {
        selectAddress(newSelected, ref);
      }
    } else {
      // Clear persistent location cache completely
      clearAddressCache();
      if (ref != null) {
        ref.read(authProvider.notifier).deleteLocationData();
      }
    }

    print('[GPS] Delete Success');
  }

  /// Set default address by ID
  void setDefaultAddress(String id, [WidgetRef? ref]) {
    final target = state.addresses.firstWhere(
      (a) => a.id == id,
      orElse: () => state.addresses.first,
    );
    selectAddress(target, ref);
  }

  /// Update search query string
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Search places by text query via LocationService
  Future<List<Address>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return <Address>[];
    try {
      final locs = await _locationService.searchPlaces(query);
      return locs.map<Address>((loc) {
        final String titleLabel = loc.area.trim().isNotEmpty ? loc.area.trim() : 'Custom Location';
        return Address(
          id: 'addr_search_${DateTime.now().millisecondsSinceEpoch}_${loc.latitude}',
          label: titleLabel,
          formattedAddress: loc.formattedAddress,
          locality: loc.area,
          subLocality: loc.area,
          city: loc.city,
          state: loc.state,
          postalCode: loc.pincode,
          latitude: loc.latitude,
          longitude: loc.longitude,
          isCurrent: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();
    } catch (_) {
      return <Address>[];
    }
  }

  /// Fetch fresh GPS coordinates, save to SharedPreferences & Firestore, and select immediately.
  /// Logs status, permission, latitude, longitude, and save success.
  Future<bool> fetchGpsLocationAndSelect(WidgetRef ref) async {
    state = state.copyWith(isFetchingGps: true, errorMessage: null);

    try {
      final position = await _locationService.fetchFreshGpsPosition();

      if (position.latitude == 0.0 && position.longitude == 0.0) {
        throw Exception('INVALID_COORDINATES');
      }

      final String coordStr = 'Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';

      final gpsAddress = Address(
        id: 'addr_gps_${DateTime.now().millisecondsSinceEpoch}',
        label: 'Current Location',
        formattedAddress: coordStr,
        locality: '',
        subLocality: '',
        city: '',
        state: '',
        postalCode: '',
        latitude: position.latitude,
        longitude: position.longitude,
        isDefault: true,
        isCurrent: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cleanList = state.addresses.where((a) => !a.isCurrent && a.label != 'Current Location').toList();
      final newList = [gpsAddress, ...cleanList];

      state = state.copyWith(
        addresses: newList,
        selectedAddress: gpsAddress,
        isFetchingGps: false,
        errorMessage: null,
      );

      // Save locally to SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final authUser = ref.read(authProvider).userModel;
        final userKey = authUser?.uid ?? 'guest';
        await prefs.setDouble('latitude', position.latitude);
        await prefs.setDouble('longitude', position.longitude);
        await prefs.setString('locationSource', 'gps');
        await prefs.setString('${_persistentAddressKey}_$userKey', jsonEncode(gpsAddress.toMap()));
        print('[GPS] SharedPreferences Save Success');
      } catch (pe) {
        print('[GPS] SharedPreferences Save Error: $pe');
      }

      // Save to Firestore
      await ref.read(authProvider.notifier).saveUserData(
        latitude: position.latitude,
        longitude: position.longitude,
        locationSource: 'gps',
        formattedAddress: coordStr,
      );

      return true;
    } catch (e) {
      print('[GPS] Location Error: $e');
      final String msg = 'Unable to fetch your current location. Please try again.';
      state = state.copyWith(
        isFetchingGps: false,
        errorMessage: msg,
      );
      return false;
    }
  }
}

final addressProvider = NotifierProvider<AddressNotifier, AddressState>(() {
  return AddressNotifier();
});
