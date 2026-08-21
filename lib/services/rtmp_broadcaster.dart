import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Camera capture + self-preview for the go-live screen.
///
/// NOTE ON PUBLISHING: the mature Flutter RTMP publisher (HaishinKit) forces
/// Swift 6 strict concurrency in its SPM manifest and does not compile under the
/// Xcode 26 toolchain Apple now requires, so it was removed. Real phone→viewer
/// broadcasting is being moved to WebRTC WHIP (Cloudflare Stream Live supports
/// it, and flutter_webrtc builds cleanly on Xcode 26) — that lands once the
/// backend exposes the broadcast's WHIP ingest URL. Until then [publish] is a
/// no-op: the creator sees their camera and the broadcast record is created,
/// but no media is pushed yet.
class RtmpBroadcaster {
  CameraController? _cam;
  List<CameraDescription> _cameras = const [];
  int _index = 0;

  bool get ready => _cam?.value.isInitialized ?? false;
  bool get publishing => false;

  Future<void> init() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    // Prefer the front camera for a selfie-style go-live.
    final front = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
    await _start(front >= 0 ? front : 0);
  }

  Future<void> _start(int i) async {
    await _cam?.dispose();
    final c = CameraController(_cameras[i], ResolutionPreset.high, enableAudio: true);
    await c.initialize();
    _cam = c;
    _index = i;
  }

  Widget preview() {
    final c = _cam;
    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: Color(0xFF0B1120));
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: c.value.previewSize?.height ?? 1080,
        height: c.value.previewSize?.width ?? 1920,
        child: CameraPreview(c),
      ),
    );
  }

  /// Real RTMPS/WHIP publish is pending the backend WHIP URL (see class note).
  Future<void> publish({required String ingestUrl, required String streamKey}) async {}

  Future<void> flip() async {
    if (_cameras.length < 2) return;
    await _start((_index + 1) % _cameras.length);
  }

  Future<void> stop() async {}

  Future<void> dispose() async {
    await _cam?.dispose();
    _cam = null;
  }
}
