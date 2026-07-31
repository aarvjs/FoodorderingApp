import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';
import '../services/storage_service.dart';

class AuthRepository {
  final FirebaseAuthService _authService;
  final StorageService _storageService;

  AuthRepository({
    FirebaseAuthService? authService,
    StorageService? storageService,
  })  : _authService = authService ?? FirebaseAuthService(),
        _storageService = storageService ?? StorageService();

  User? get currentUser => _authService.currentUser;

  Future<bool> reloadUser() {
    return _authService.reloadCurrentUser();
  }

  Future<void> sendOtp({
    required String phoneNumber,
    required Function(PhoneAuthCredential credential) onVerificationCompleted,
    required Function(FirebaseAuthException error) onVerificationFailed,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String verificationId) onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) {
    return _authService.sendOtp(
      phoneNumber: phoneNumber,
      onVerificationCompleted: onVerificationCompleted,
      onVerificationFailed: onVerificationFailed,
      onCodeSent: onCodeSent,
      onCodeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
      forceResendingToken: forceResendingToken,
    );
  }

  Future<UserCredential> signInWithCredential(AuthCredential credential) {
    return _authService.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithOtp({
    required String verificationId,
    required String smsCode,
  }) {
    return _authService.signInWithOtp(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  Future<UserModel?> getUserProfile(String uid) {
    return _authService.getUserProfile(uid);
  }

  Future<void> saveUserProfile(UserModel user) {
    return _authService.saveUserProfile(user);
  }

  Future<String> uploadProfilePhoto(String uid, File imageFile) {
    return _storageService.uploadProfilePhoto(uid: uid, imageFile: imageFile);
  }

  Future<void> signOut() {
    return _authService.signOut();
  }
}
