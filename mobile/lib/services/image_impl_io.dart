// Native (iOS/Android) implementation — pick from the gallery via image_picker,
// optionally crop to a square (profile photos), and return a base64 data URL
// matching the web impl's contract.
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

Future<String?> pickImageAsDataUrl({bool cropSquare = false}) async {
  final picker = ImagePicker();
  // Downscale + compress on-device: keeps detail readable while cutting the
  // base64 payload so uploads succeed and are fast.
  final file = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 70,
  );
  if (file == null) return null;

  String path = file.path;
  String mime = _mimeFor(file.name);

  if (cropSquare) {
    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop photo',
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (cropped == null) return null; // user cancelled the crop
    path = cropped.path;
    mime = 'image/jpeg';
  }

  final bytes = await File(path).readAsBytes();
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

String _mimeFor(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}
