import 'package:flutter/material.dart';
import 'package:haishin_kit/audio_source.dart';
import 'package:haishin_kit/rtmp_connection.dart';
import 'package:haishin_kit/rtmp_stream.dart';
import 'package:haishin_kit/stream_view_texture.dart';
import 'package:haishin_kit/video_settings.dart';
import 'package:haishin_kit/video_source.dart';

/// Thin wrapper around haishin_kit (v0.14.x API) for camera capture + RTMPS
/// publishing to Cloudflare Stream Live. All plugin-specific API is isolated
/// here. Encoder: H.264/AAC, 720p, ~3 Mbps, 2s keyframe.
class RtmpBroadcaster {
  RtmpConnection? _connection;
  RtmpStream? _stream;
  bool _publishing = false;
  CameraPosition _position = CameraPosition.front;
  String? _streamKey;

  bool get ready => _stream != null;
  bool get publishing => _publishing;

  /// Create the connection/stream and attach camera + mic. Publishing starts
  /// when the RTMP connection reports success (see the event listener).
  Future<void> init() async {
    if (_stream != null) return;
    final connection = await RtmpConnection.create();
    connection.eventChannel.receiveBroadcastStream().listen((event) {
      if (event["data"]?["code"] == 'NetConnection.Connect.Success') {
        final key = _streamKey;
        if (key != null) {
          _stream?.publish(key);
          _publishing = true;
        }
      }
    });
    final stream = await RtmpStream.create(connection);
    stream.attachAudio(AudioSource());
    stream.attachVideo(VideoSource(position: _position));
    // 720p portrait, ~3 Mbps, 2s keyframe (Cloudflare-recommended for mobile).
    stream.videoSettings = VideoSettings(
      width: 720,
      height: 1280,
      bitrate: 3000 * 1000,
      frameInterval: 2,
      profileLevel: ProfileLevel.h264Main41,
    );
    _connection = connection;
    _stream = stream;
  }

  /// Live self-preview widget.
  Widget preview() {
    final s = _stream;
    if (s == null) return const ColoredBox(color: Color(0xFF0B1120));
    return StreamViewTexture(s);
  }

  /// Connect to the RTMPS ingest and start publishing under [streamKey].
  /// Cloudflare uses `rtmps://live.cloudflare.com:443/live` as the URL and the
  /// stream key as the publish name.
  Future<void> publish({required String ingestUrl, required String streamKey}) async {
    if (_connection == null || _publishing) return;
    _streamKey = streamKey;
    _connection!.connect(ingestUrl); // publish fires on Connect.Success
  }

  /// Flip between front/back cameras.
  Future<void> flip() async {
    _position = _position == CameraPosition.front ? CameraPosition.back : CameraPosition.front;
    await _stream?.attachVideo(VideoSource(position: _position));
  }

  /// Stop publishing and close the connection.
  Future<void> stop() async {
    _publishing = false;
    try {
      _connection?.close();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _publishing = false;
    try {
      _connection?.dispose();
    } catch (_) {}
    try {
      _stream?.dispose();
    } catch (_) {}
    _stream = null;
    _connection = null;
  }
}
