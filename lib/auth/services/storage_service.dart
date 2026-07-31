import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads user profile image file to Firebase Storage under profile_photos/{uid}.jpg
  Future<String> uploadProfilePhoto({
    required String uid,
    required File imageFile,
  }) async {
    try {
      final ref = _storage.ref().child('profile_photos').child('$uid.jpg');
      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload profile photo: ${e.toString()}');
    }
  }
}
