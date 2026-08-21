import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

/// Publishes the phone's camera + mic to Cloudflare Stream Live over **WHIP**
/// (WebRTC-HTTP Ingestion Protocol). This replaces RTMP (HaishinKit), which
/// doesn't build on the Xcode 26 SDK Apple requires. flutter_webrtc uses a
/// prebuilt WebRTC framework, so it builds cleanly.
///
/// Flow: getUserMedia (shows self-preview immediately) → createOffer →
/// POST the SDP to the broadcast's WHIP URL → setRemoteDescription(answer).
class RtmpBroadcaster {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  MediaStream? _stream;
  RTCPeerConnection? _pc;
  bool _rendererReady = false;
  bool _publishing = false;
  String? _facing = 'user';

  bool get ready => _rendererReady && _stream != null;
  bool get publishing => _publishing;

  /// Open the camera + mic and start the local preview.
  Future<void> init() async {
    if (_stream != null) return;
    await _renderer.initialize();
    _stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': _facing,
        'width': {'ideal': 720},
        'height': {'ideal': 1280},
        'frameRate': {'ideal': 30},
      },
    });
    _renderer.srcObject = _stream;
    _rendererReady = true;
  }

  /// The live self-preview (mirrored, cover-fit).
  Widget preview() {
    if (!_rendererReady) return const ColoredBox(color: Color(0xFF0B1120));
    return RTCVideoView(
      _renderer,
      mirror: _facing == 'user',
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }

  /// Establish the WebRTC session and publish to the Cloudflare WHIP endpoint.
  Future<void> publish({required String whipUrl}) async {
    if (_stream == null || _publishing) return;
    _publishing = true;
    try {
      final pc = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.cloudflare.com:3478'},
        ],
        'sdpSemantics': 'unified-plan',
      });
      _pc = pc;
      for (final track in _stream!.getTracks()) {
        await pc.addTrack(track, _stream!);
      }

      final offer = await pc.createOffer({});
      await pc.setLocalDescription(offer);
      final localSdp = await _gatheredSdp(pc, offer);

      final res = await http.post(
        Uri.parse(whipUrl),
        headers: {'Content-Type': 'application/sdp', 'Accept': 'application/sdp'},
        body: localSdp,
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw 'WHIP publish failed (${res.statusCode})';
      }
      await pc.setRemoteDescription(RTCSessionDescription(res.body, 'answer'));
    } catch (_) {
      _publishing = false;
      rethrow;
    }
  }

  /// Wait for ICE gathering to complete so the SDP carries all candidates
  /// (Cloudflare WHIP expects a complete offer, not trickle).
  Future<String> _gatheredSdp(RTCPeerConnection pc, RTCSessionDescription offer) async {
    if (pc.iceGatheringState == RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return (await pc.getLocalDescription())?.sdp ?? offer.sdp!;
    }
    final done = Completer<void>();
    Timer? timeout;
    pc.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete && !done.isCompleted) {
        done.complete();
      }
    };
    timeout = Timer(const Duration(seconds: 3), () {
      if (!done.isCompleted) done.complete(); // proceed with what we have
    });
    await done.future;
    timeout.cancel();
    return (await pc.getLocalDescription())?.sdp ?? offer.sdp!;
  }

  /// Flip the camera (front/back).
  Future<void> flip() async {
    final track = _stream?.getVideoTracks().firstOrNull;
    if (track == null) return;
    await Helper.switchCamera(track);
    _facing = _facing == 'user' ? 'environment' : 'user';
  }

  /// Stop publishing (keeps the preview alive).
  Future<void> stop() async {
    _publishing = false;
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
  }

  Future<void> dispose() async {
    _publishing = false;
    try {
      await _pc?.close();
    } catch (_) {}
    try {
      await _stream?.dispose();
    } catch (_) {}
    try {
      await _renderer.dispose();
    } catch (_) {}
    _pc = null;
    _stream = null;
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
