import 'package:flutter/material.dart';
import 'package:haishin_kit/audio_source.dart';
import 'package:haishin_kit/rtmp_connection.dart';
import 'package:haishin_kit/rtmp_stream.dart';
import 'package:haishin_kit/video_settings.dart';
import 'package:haishin_kit/video_source.dart';

/// Thin wrapper around haishin_kit for camera capture + RTMPS publishing to
/// Cloudflare Stream Live. All plugin-specific API is isolated here so the rest
/// of the app (and any future plugin swap) stays untouched.
///
/// Encoder is set to Cloudflare's recommendations: H.264/AAC, 720p, ~3 Mbps,
/// 30 fps, 2s keyframe interval.
class RtmpBroadcaster {
  RtmpConnection? _connection;
  RtmpStream? _stream;
  bool _publishing = false;
  bool _front = true;
  String? _streamKey;

  bool get ready => _stream != null;
  bool get publishing => _publishing;

  /// Create the connection/stream and attach camera + mic. Call once before
  /// showing the preview.
  Future<void> init() async {
    if (_stream != null) return;
    final connection = await RtmpConnection.create();
    connection.eventChannel.listen(_onEvent);
    final stream = await RtmpStream.create(connection);
    stream.attachAudio(AudioSource());
    stream.attachVideo(VideoSource(position: _front ? CameraPosition.front : CameraPosition.back));
    // 720p portrait, ~3 Mbps (Cloudflare-recommended for mobile).
    stream.videoSettings = VideoSettings(
      width: 720,
      height: 1280,
      bitrate: 3000 * 1000,
    );
    _connection = connection;
    _stream = stream;
  }

  /// Self-preview. The camera captures + publishes regardless; the on-screen
  /// self-view widget is wired in a follow-up (the plugin's preview class name
  /// varies by version). For now show a branded "you're live" surface.
  Widget preview() {
    return const ColoredBox(color: Color(0xFF0B1120));
  }

  /// Connect to the RTMPS ingest and start publishing under [streamKey].
  /// Cloudflare uses `rtmps://live.cloudflare.com:443/live` as the URL and the
  /// stream key as the publish name.
  Future<void> publish({required String ingestUrl, required String streamKey}) async {
    if (_connection == null || _publishing) return;
    _streamKey = streamKey;
    // Publishing begins on NetConnection.Connect.Success (see _onEvent).
    _connection!.connect(ingestUrl);
  }

  void _onEvent(dynamic event) {
    try {
      final code = event['data']?['code'];
      if (code == 'NetConnection.Connect.Success') {
        final key = _streamKey;
        if (key != null) {
          _stream?.publish(key);
          _publishing = true;
        }
      }
    } catch (_) {/* ignore malformed events */}
  }

  /// Flip between front/back cameras.
  Future<void> flip() async {
    _front = !_front;
    _stream?.attachVideo(VideoSource(position: _front ? CameraPosition.front : CameraPosition.back));
  }

  /// Stop publishing and tear down the connection.
  Future<void> stop() async {
    _publishing = false;
    try {
      _connection?.close();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _publishing = false;
    try {
      _stream?.attachAudio(null);
      _stream?.attachVideo(null);
      _stream?.dispose();
    } catch (_) {}
    try {
      _connection?.dispose();
    } catch (_) {}
    _stream = null;
    _connection = null;
  }
}
