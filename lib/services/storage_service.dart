import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Translate Firebase Storage errors into user-readable messages so the
  /// caller can drop the raw exception into a snackbar without leaking
  /// internal codes.
  Exception _humanize(Object err) {
    if (err is FirebaseException) {
      switch (err.code) {
        case 'unauthorized':
        case 'unauthenticated':
          return Exception(
              'Not allowed to upload. Sign in again and retry.');
        case 'object-not-found':
          return Exception(
              'Upload finished but the file wasn\'t saved. Try again.');
        case 'quota-exceeded':
          return Exception('Storage quota exceeded. Contact support.');
        case 'retry-limit-exceeded':
        case 'canceled':
          return Exception('Upload failed. Check your connection and retry.');
      }
      return Exception('Storage error: ${err.code}');
    }
    if (err is Exception) return err;
    return Exception(err.toString());
  }

  Future<String> uploadFile({
    required String path,
    required File file,
  }) async {
    debugPrint('[storage] uploadFile start: $path');
    try {
      final ref = _storage.ref().child(path);
      final task = ref.putFile(file);
      // Awaiting the task returns the *committed* TaskSnapshot, so the
      // download URL is requested on snapshot.ref instead of the original
      // ref. Mirrors the Firebase docs pattern; fixes the
      // "No object exists at the desired reference" race that hits when
      // putFile resolves before the metadata service has the file.
      final snap = await task;
      if (snap.state != TaskState.success) {
        throw FirebaseException(
          plugin: 'firebase_storage',
          code: 'unknown',
          message: 'Upload finished in state ${snap.state}',
        );
      }
      final url = await snap.ref.getDownloadURL();
      debugPrint('[storage] uploadFile done: ${url.length} chars');
      return url;
    } catch (e) {
      debugPrint('[storage] uploadFile FAIL: $e');
      throw _humanize(e);
    }
  }

  /// Web-safe upload — accepts raw bytes. Works on mobile and web.
  ///
  /// Uses the `UploadTask` snapshot pattern so the download URL is read
  /// from the committed object reference, not the optimistic one. This
  /// is the canonical fix for the "No object exists at the desired
  /// reference" race that hits on flaky networks (and after App Check
  /// auth refreshes mid-upload).
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    debugPrint('[storage] uploadBytes start: $path (${bytes.length} B, $contentType)');
    try {
      final ref = _storage.ref().child(path);
      final task = ref.putData(bytes, SettableMetadata(contentType: contentType));
      final snap = await task;
      if (snap.state != TaskState.success) {
        throw FirebaseException(
          plugin: 'firebase_storage',
          code: 'unknown',
          message: 'Upload finished in state ${snap.state}',
        );
      }
      final url = await snap.ref.getDownloadURL();
      if (url.isEmpty) {
        throw FirebaseException(
          plugin: 'firebase_storage',
          code: 'object-not-found',
          message: 'Empty download URL after upload',
        );
      }
      debugPrint('[storage] uploadBytes done: ${snap.bytesTransferred}/${snap.totalBytes} B');
      return url;
    } catch (e) {
      debugPrint('[storage] uploadBytes FAIL ($path): $e');
      throw _humanize(e);
    }
  }

  Future<void> deleteFile(String url) async {
    if (url.isEmpty) return;
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      // File may already be deleted — log and move on, never throw from
      // delete since it would block a save that otherwise succeeded.
      debugPrint('[storage] deleteFile soft-fail ($url): $e');
    }
  }
}
