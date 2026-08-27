import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../../features/address/providers/address_provider.dart';

enum AuthStatus {
  initial,
  codeSent,
  authenticating,
  authenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final String phoneNumber;
  final String? verificationId;
  final int? resendToken;
  final int timerSeconds;
  final bool isLoading;
  final String? errorMessage;
  final UserModel? userModel;

  const AuthState({
    this.status = AuthStatus.initial,
    this.phoneNumber = '',
    this.verificationId,
    this.resendToken,
    this.timerSeconds = 30,
    this.isLoading = false,
    this.errorMessage,
    this.userModel,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? phoneNumber,
    String? verificationId,
    int? resendToken,
    int? timerSeconds,
    bool? isLoading,
    String? errorMessage,
    UserModel? userModel,
  }) {
    return AuthState(
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      userModel: userModel ?? this.userModel,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repository;
  Timer? _timer;
  int _activeSessionId = 0;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    ref.onDispose(() {
      _timer?.cancel();
    });
    return const AuthState();
  }

  void _startTimer() {
    _timer?.cancel();
    state = state.copyWith(timerSeconds: 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.timerSeconds > 1) {
        state = state.copyWith(timerSeconds: state.timerSeconds - 1);
      } else {
        _timer?.cancel();
        _timer = null;
        state = state.copyWith(
          timerSeconds: 0,
          errorMessage: state.status != AuthStatus.authenticated
              ? 'This OTP has expired. Please request a new OTP.'
              : state.errorMessage,
        );
      }
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(timerSeconds: 0);
  }

  void setPhoneNumber(String phone) {
    state = state.copyWith(phoneNumber: phone, errorMessage: null);
  }

  String _mapAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Invalid OTP code. Please check and try again.';
      case 'session-expired':
        return 'This OTP has expired. Please request a new OTP.';
      case 'invalid-verification-id':
        return 'Session expired. Please request a new OTP.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'invalid-phone-number':
        return 'Invalid phone number format.';
      default:
        return e.message ?? 'Verification failed. Please try again.';
    }
  }

  /// Request OTP from Firebase Auth
  Future<void> sendOtp(
    String phone, {
    void Function()? onCodeSent,
    void Function(String errorMessage)? onError,
  }) async {
    _activeSessionId++;
    final currentSession = _activeSessionId;

    state = state.copyWith(
      phoneNumber: phone,
      isLoading: true,
      errorMessage: null,
      verificationId: null,
    );

    try {
      await _repository.sendOtp(
        phoneNumber: phone,
        forceResendingToken: state.resendToken,
        onVerificationCompleted: (PhoneAuthCredential credential) async {
          if (currentSession != _activeSessionId) return;
          // Automatic SMS Verification succeeded on Android
          await _signInWithCredential(credential);
        },
        onVerificationFailed: (FirebaseAuthException error) {
          if (currentSession != _activeSessionId) return;
          final errorMsg = _mapAuthException(error);
          state = state.copyWith(
            isLoading: false,
            status: AuthStatus.error,
            errorMessage: errorMsg,
          );
          onError?.call(errorMsg);
        },
        onCodeSent: (String verificationId, int? resendToken) {
          if (currentSession != _activeSessionId) return;
          state = state.copyWith(
            isLoading: false,
            status: AuthStatus.codeSent,
            verificationId: verificationId,
            resendToken: resendToken,
          );
          _startTimer();
          onCodeSent?.call();
        },
        onCodeAutoRetrievalTimeout: (String verificationId) {
          if (currentSession != _activeSessionId) return;
          state = state.copyWith(
            verificationId: verificationId,
          );
        },
      );
    } catch (e) {
      if (currentSession != _activeSessionId) return;
      final errorMsg = e is FirebaseAuthException ? _mapAuthException(e) : e.toString();
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.error,
        errorMessage: errorMsg,
      );
      onError?.call(errorMsg);
    }
  }

  /// Resend OTP
  Future<void> resendOtp() async {
    if (state.phoneNumber.isNotEmpty && !state.isLoading) {
      await sendOtp(state.phoneNumber);
    }
  }

  /// Sign in using 6-digit OTP entered manually
  Future<bool> verifyOtp(String smsCode) async {
    if (state.status == AuthStatus.authenticated) {
      stopTimer();
      return true;
    }

    if (state.isLoading) return false;

    if (state.verificationId == null) {
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.error,
        errorMessage: 'This OTP session has expired. Please request a new OTP.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final credential = await _repository.signInWithOtp(
        verificationId: state.verificationId!,
        smsCode: smsCode,
      );

      final success = await _handlePostSignIn(credential.user);
      if (success) {
        stopTimer();
      }
      return success;
    } on FirebaseAuthException catch (e) {
      // If already authenticated by background SMS auto-fill, ignore failure
      if (state.status == AuthStatus.authenticated || _repository.currentUser != null) {
        stopTimer();
        return true;
      }
      final errorMsg = _mapAuthException(e);
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.error,
        errorMessage: errorMsg,
      );
      return false;
    } catch (e) {
      if (state.status == AuthStatus.authenticated || _repository.currentUser != null) {
        stopTimer();
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.error,
        errorMessage: 'Verification failed. Please try again.',
      );
      return false;
    }
  }

  /// Internal sign-in handling when auto-SMS completes
  Future<bool> _signInWithCredential(PhoneAuthCredential credential) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final userCred = await _repository.signInWithCredential(credential);
      final success = await _handlePostSignIn(userCred.user);
      if (success) {
        stopTimer();
      }
      return success;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.error,
        errorMessage: 'Auto sign-in failed. Please enter OTP manually.',
      );
      return false;
    }
  }

  /// Load user profile from Firestore or initialize new record
  Future<bool> _handlePostSignIn(User? firebaseUser) async {
    if (firebaseUser == null) {
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.error,
        errorMessage: 'Failed to retrieve user session.',
      );
      return false;
    }

    try {
      final verifiedPhone = (firebaseUser.phoneNumber != null && firebaseUser.phoneNumber!.isNotEmpty)
          ? firebaseUser.phoneNumber!
          : state.phoneNumber;

      final existingProfile = await _repository.getUserProfile(firebaseUser.uid);

      if (existingProfile != null) {
        UserModel activeProfile = existingProfile;

        // If existing profile lacks phone number or has empty phone, sync verified phone from session
        if (existingProfile.phone.isEmpty && verifiedPhone.isNotEmpty) {
          activeProfile = existingProfile.copyWith(phone: verifiedPhone);
          try {
            await _repository.saveUserProfile(activeProfile);
          } catch (_) {}
        }

        state = state.copyWith(
          isLoading: false,
          status: AuthStatus.authenticated,
          userModel: activeProfile,
        );

        if (existingProfile.formattedAddress == null ||
            existingProfile.formattedAddress!.isEmpty ||
            existingProfile.latitude == null ||
            existingProfile.latitude == 0.0) {
          await ref.read(addressProvider.notifier).clearAddressCache(firebaseUser.uid);
        }
      } else {
        final newProfile = UserModel(
          uid: firebaseUser.uid,
          phone: verifiedPhone,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _repository.saveUserProfile(newProfile);

        // A brand new user starts with ZERO cached location data
        await ref.read(addressProvider.notifier).clearAddressCache(firebaseUser.uid);

        state = state.copyWith(
          isLoading: false,
          status: AuthStatus.authenticated,
          userModel: newProfile,
        );
      }
      return true;
    } catch (e) {
      final verifiedPhone = (firebaseUser.phoneNumber != null && firebaseUser.phoneNumber!.isNotEmpty)
          ? firebaseUser.phoneNumber!
          : state.phoneNumber;
      final fallbackProfile = UserModel(
        uid: firebaseUser.uid,
        phone: verifiedPhone,
        createdAt: DateTime.now(),
      );
      await ref.read(addressProvider.notifier).clearAddressCache(firebaseUser.uid);
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.authenticated,
        userModel: fallbackProfile,
      );
      return true;
    }
  }

  /// Save location and/or profile data to Firestore
  Future<bool> saveUserData({
    String? fullName,
    File? imageFile,
    String? formattedAddress,
    String? area,
    double? latitude,
    double? longitude,
    String? locationSource,
    String? city,
    String? stateName,
    String? pincode,
  }) async {
    final currentUser = _repository.currentUser;
    final uid = currentUser?.uid ?? state.userModel?.uid;

    if (uid == null) {
      state = state.copyWith(errorMessage: 'No active session found.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      String? photoUrl = state.userModel?.photoUrl;

      if (imageFile != null) {
        photoUrl = await _repository.uploadProfilePhoto(uid, imageFile);
      }

      final updatedUser = (state.userModel ?? UserModel(
        uid: uid,
        phone: currentUser?.phoneNumber ?? state.phoneNumber,
      )).copyWith(
        fullName: fullName ?? state.userModel?.fullName,
        photoUrl: photoUrl ?? state.userModel?.photoUrl,
        formattedAddress: formattedAddress ?? state.userModel?.formattedAddress,
        area: area ?? state.userModel?.area,
        latitude: latitude ?? state.userModel?.latitude,
        longitude: longitude ?? state.userModel?.longitude,
        locationSource: locationSource ?? state.userModel?.locationSource ?? 'gps',
        city: city ?? state.userModel?.city,
        state: stateName ?? state.userModel?.state,
        pincode: pincode ?? state.userModel?.pincode,
        updatedAt: DateTime.now(),
      );

      await _repository.saveUserProfile(updatedUser);
      print('[GPS] Firestore Save Success');

      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.authenticated,
        userModel: updatedUser,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to save profile: ${e.toString()}',
      );
      return false;
    }
  }

  /// Remove location data from Firestore and UserModel state
  Future<bool> deleteLocationData() async {
    final currentUser = _repository.currentUser;
    final uid = currentUser?.uid ?? state.userModel?.uid;

    if (uid == null) return false;

    try {
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
      await userDocRef.update({
        'latitude': FieldValue.delete(),
        'longitude': FieldValue.delete(),
        'locationSource': FieldValue.delete(),
        'formattedAddress': '',
        'area': '',
        'city': '',
        'state': '',
        'pincode': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final updatedUser = (state.userModel ?? UserModel(uid: uid, phone: currentUser?.phoneNumber ?? '')).copyWith(
        latitude: null,
        longitude: null,
        locationSource: null,
        formattedAddress: '',
        area: '',
        city: '',
        state: '',
        pincode: '',
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(
        userModel: updatedUser,
      );

      print('[GPS] Delete Success');
      return true;
    } catch (e) {
      print('[GPS] Firestore Delete Error: $e');
      return false;
    }
  }

  /// Reload Firebase user session on app launch to verify if account was deleted from Console.
  Future<bool> checkAndReloadUser() async {
    final isValid = await _repository.reloadUser();
    if (!isValid || _repository.currentUser == null) {
      await signOut();
      return false;
    }
    await fetchActiveUserProfile();
    return true;
  }

  /// Fetch active profile from Firestore
  Future<void> fetchActiveUserProfile() async {
    final currentUser = _repository.currentUser;
    if (currentUser != null) {
      final profile = await _repository.getUserProfile(currentUser.uid);
      final authPhone = currentUser.phoneNumber ?? state.phoneNumber;

      if (profile != null) {
        UserModel activeProfile = profile;
        if (profile.phone.isEmpty && authPhone.isNotEmpty) {
          activeProfile = profile.copyWith(phone: authPhone);
          try {
            await _repository.saveUserProfile(activeProfile);
          } catch (_) {}
        }
        state = state.copyWith(
          userModel: activeProfile,
          status: AuthStatus.authenticated,
        );
      } else {
        if (authPhone.isNotEmpty) {
          final newProfile = UserModel(
            uid: currentUser.uid,
            phone: authPhone,
            createdAt: DateTime.now(),
          );
          try {
            await _repository.saveUserProfile(newProfile);
          } catch (_) {}
          state = state.copyWith(
            userModel: newProfile,
            status: AuthStatus.authenticated,
          );
        }
      }
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    _timer?.cancel();
    final uid = state.userModel?.uid ?? _repository.currentUser?.uid;
    try {
      await _repository.signOut();
    } catch (e) {
      print('[AuthNotifier] Firebase signOut error: $e');
    }
    try {
      await ref.read(addressProvider.notifier).clearAddressCache(uid);
    } catch (e) {
      print('[AuthNotifier] Address cache clear error: $e');
    }
    state = const AuthState();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
