import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:native_exif/native_exif.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'dart:developer' as developer;

Future<Position> getCurrentLocation() async {
  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}

String getTimestamp() {
  final now = DateTime.now();
  return "${now.year}"
      "${now.month.toString().padLeft(2, '0')}"
      "${now.day.toString().padLeft(2, '0')}_"
      "${now.hour.toString().padLeft(2, '0')}"
      "${now.minute.toString().padLeft(2, '0')}"
      "${now.second.toString().padLeft(2, '0')}";
}

Future<File> addCoordinatesToImage({
  required File imageFile,
  required Position position,
  required String engineer,
  required String municipio,
  required String camino,
  required DateTime captureTime,
}) async {
  developer.log("Starting EXIF data injection...", name: 'ImageUtils');

  final directory = await getTemporaryDirectory();
  final safeEngineer = engineer.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
  final safeCamino = camino.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
  final timestamp = getTimestamp();
  final path = "${directory.path}/gps_${timestamp}_${safeEngineer}_$safeCamino.jpg";

  final File newFile = await imageFile.copy(path);

  try {
    final exif = await Exif.fromPath(newFile.path);

    final exifDateFormatter = DateFormat('yyyy:MM:dd HH:mm:ss');
    final formattedDate = exifDateFormatter.format(captureTime);
    final imageDescription = 'Municipio: $municipio, Camino: $camino';

    await exif.writeAttributes({
      'GPSLatitude': position.latitude.toString(),
      'GPSLongitude': position.longitude.toString(),
      'GPSLatitudeRef': position.latitude >= 0 ? 'N' : 'S',
      'GPSLongitudeRef': position.longitude >= 0 ? 'E' : 'W',
      'DateTimeOriginal': formattedDate,
      'DateTime': formattedDate,
      'Artist': engineer,
      'ImageDescription': imageDescription,
    });
    await exif.close();
    developer.log("SUCCESS: All EXIF data written.", name: 'ImageUtils');

  } catch (e, s) {
    developer.log(
      "Error writing EXIF data.",
      error: e,
      stackTrace: s,
      name: 'ImageUtils',
      level: 1000,
    );
    // Return the original file if EXIF writing fails
    return imageFile;
  }

  developer.log("Finished EXIF processing.", name: 'ImageUtils');
  return newFile;
}
