// Cross-platform facade. Uses an HTML file input on web; returns null on native
// for now (native image picking can be added later with the image_picker pkg).
import 'image_impl_stub.dart'
    if (dart.library.html) 'image_impl_web.dart' as impl;

class ImagePickerService {
  /// Returns the selected image as a base64 data URL, or null.
  static Future<String?> pickImageAsDataUrl() => impl.pickImageAsDataUrl();
}
