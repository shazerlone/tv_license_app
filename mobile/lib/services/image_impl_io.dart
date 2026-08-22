// Native (iOS/Android) implementation — pick from the gallery via image_picker
// and return a base64 data URL matching the web impl's contract.
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

Future<String?> pickImageAsDataUrl() async {
  final picker = ImagePicker();
  // Downscale + compress on-device: keeps chart detail readable while cutting
  // the base64 payload so uploads succeed and are fast.
  final file = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 70,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final name = file.name.toLowerCase();
  final mime = name.endsWith('.png')
      ? 'image/png'
      : (name.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
  return 'data:$mime;base64,${base64Encode(bytes)}';
}
