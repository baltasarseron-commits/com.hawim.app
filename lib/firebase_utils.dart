import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';

// CORRECT: The function now accepts the list of measurements
Future<void> uploadImageAndSaveRecord({
  required String filePath,
  required String engineer,
  required String municipio,
  required String camino,
  required List<Map<String, dynamic>> measurements, // The new parameter
  Position? coordinates,
}) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  // 1. Upload the image to Firebase Storage
  final file = File(filePath);
  final String fileName = filePath.split('/').last; // e.g., 'gps_20231027_103000.jpg'
  final Reference storageRef = storage.ref().child('images/$fileName');

  final UploadTask uploadTask = storageRef.putFile(file);
  final TaskSnapshot snapshot = await uploadTask;
  final String downloadUrl = await snapshot.ref.getDownloadURL();

  // 2. Create a new document in Firestore
  await firestore.collection('image_records').add({ // CORRECTED collection name
    'engineer': engineer,
    'municipio': municipio,
    'camino': camino,
    'imageUrl': downloadUrl,
    'coordinates': coordinates != null ? GeoPoint(coordinates.latitude, coordinates.longitude): null,
    'createdAt': FieldValue.serverTimestamp(), // Use createdAt for consistency
    'measurements': measurements,
  });
}
