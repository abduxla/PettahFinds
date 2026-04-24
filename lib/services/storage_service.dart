import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadFile({
    required String path,
    required File file,
  }) async {
    final ref = _storage.ref().child(path);
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  /// Web-safe upload — accepts raw bytes. Works on mobile and web.
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final ref = _storage.ref().child(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  Future<void> deleteFile(String url) async {
    if (url.isEmpty) return;
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // File may already be deleted
    }
  }
}
