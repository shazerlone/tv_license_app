// Cross-platform facade. Uses an HTML file input on web; returns null on native
// for now (native image picking can be added later with the image_picker pkg).
import 'image_impl_stub.dart'
    if (dart.library.io) 'image_impl_io.dart'
    if (dart.library.html) 'image_impl_web.dart' as impl;

class ImagePickerService {
  /// Returns the selected image as a base64 data URL, or null. When
  /// [cropSquare] is true (native only), the user crops to a square first —
  /// used for profile photos so avatars are consistent (Instagram-style).
  static Future<String?> pickImageAsDataUrl({bool cropSquare = false}) =>
      impl.pickImageAsDataUrl(cropSquare: cropSquare);
}
