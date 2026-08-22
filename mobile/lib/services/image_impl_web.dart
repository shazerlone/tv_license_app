// Web implementation — HTML file input -> base64 data URL.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String?> pickImageAsDataUrl() async {
  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.click();
  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return null;
  final reader = html.FileReader();
  reader.readAsDataUrl(files.first);
  await reader.onLoad.first;
  return reader.result as String?;
}
