// Native (iOS/Android) implementation — pick from the gallery via image_picker
// and return a base64 data URL matching the web impl's contract.
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

Future<String?> pickImageAsDataUrl() async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 82,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final name = file.name.toLowerCase();
  final mime = name.endsWith('.png')
      ? 'image/png'
      : (name.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
  return 'data:$mime;base64,${base64Encode(bytes)}';
}
