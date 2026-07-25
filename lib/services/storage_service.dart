// Cross-platform facade. Uses browser localStorage on web; a no-op on native.
import 'storage_impl_stub.dart'
    if (dart.library.html) 'storage_impl_web.dart' as impl;

class StorageService {
  static bool hasSeenOnboarding() => impl.hasSeenOnboarding();
  static void markOnboardingSeen() => impl.markOnboardingSeen();
}
