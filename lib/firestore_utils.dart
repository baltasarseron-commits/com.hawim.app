import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Saves metadata about a photo to a 'photos' collection in Firestore.
///
/// [imageUrl] The public download URL of the photo in Firebase Storage.
/// [fileName] The name of the file as stored in Firebase Storage.
/// [title] A user-provided title for the photo.
Future<String> savePhotoMetadata({
  required String imageUrl,
  required String fileName,
  required String title,
}) async {
  try {
    await FirebaseFirestore.instance.collection('photos').add({
      'imageUrl': imageUrl,
      'fileName': fileName,
      'title': title,
      'createdAt': FieldValue.serverTimestamp(), // Automatically add the current server time
    });
    const successMessage = 'Metadatos guardados en Firestore';
    if (kDebugMode) {
      print(successMessage);
    }
    return successMessage;
  } on FirebaseException catch (e) {
    final errorMessage = 'Error al guardar en Firestore: ${e.message}';
    if (kDebugMode) {
      print(errorMessage);
    }
    return errorMessage;
  }
}
