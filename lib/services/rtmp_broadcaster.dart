import 'package:flutter/material.dart';
import 'package:audio_session/audio_session.dart';
import 'package:haishin_kit/haishin_kit.dart';

/// Wrapper around haishin_kit 0.16.x (HaishinKit.swift 2.x) for camera capture
/// + RTMPS publishing to Cloudflare Stream Live. All plugin API is isolated
/// here. Encoder: H.264/AAC, 720p, ~3 Mbps, 2s keyframe.
///
/// Note: in this plugin version the live preview is bound to the publish
/// session, so the camera self-view appears once publishing starts. The mixer
/// captures from init(); before going live the screen shows a placeholder.
class RtmpBroadcaster {
  MediaMixer? _mixer;
  StreamSession? _session;
  List<VideoSource> _sources = const [];
  CameraPosition _position = CameraPosition.front;
  bool _publishing = false;

  bool get ready => _mixer != null;
  bool get publishing => _publishing;

  /// Configure audio session (iOS), enumerate cameras, and start the mixer.
  Future<void> init() async {
    if (_mixer != null) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
      ));
    } catch (_) {/* android / not needed */}

    _sources = await HaishinKitPlatformInterface.instance.videoSources;
    final mixer = await MediaMixer.create(
      options: MediaMixerOptions(captureSessionMode: CaptureSessionMode.single),
    );
    await mixer.attachAudio(0, AudioSource());
    final cam = _pick(_position);
    if (cam != null) await mixer.attachVideo(0, cam);
    mixer.screen?.size = ScreenObjectSize(width: 720, height: 1280);
    await mixer.startRunning();
    _mixer = mixer;
  }

  VideoSource? _pick(CameraPosition p) {
    for (final s in _sources) {
      if (s.position == p) return s;
    }
    return _sources.isNotEmpty ? _sources.first : null;
  }

  /// Live self-preview (available once publishing has created the session).
  Widget preview() {
    final s = _session;
    if (s == null) return const ColoredBox(color: Color(0xFF0B1120));
    return StreamSessionViewTexture(s);
  }

  /// Create the publish session for the RTMPS ingest and connect. Cloudflare's
  /// publish URL is `{ingestUrl}/{streamKey}`.
  Future<void> publish({required String ingestUrl, required String streamKey}) async {
    if (_mixer == null || _publishing) return;
    final url = '$ingestUrl/$streamKey';
    final session = await StreamSession.create(url, StreamSessionMode.publish);
    session.videoSettings = VideoCodecSettings(
      width: 720,
      height: 1280,
      bitrate: 3000 * 1000,
      frameInterval: 2,
    );
    _session = session;
    _publishing = true;
    await session.connect();
  }

  /// Flip between front/back cameras.
  Future<void> flip() async {
    _position = _position == CameraPosition.front ? CameraPosition.back : CameraPosition.front;
    final cam = _pick(_position);
    if (cam != null) await _mixer?.attachVideo(0, cam);
  }

  /// Stop publishing (keeps the camera/mixer running).
  Future<void> stop() async {
    _publishing = false;
    try {
      await _session?.close();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _publishing = false;
    try {
      await _session?.dispose();
    } catch (_) {}
    try {
      await _mixer?.dispose();
    } catch (_) {}
    _session = null;
    _mixer = null;
  }
}
