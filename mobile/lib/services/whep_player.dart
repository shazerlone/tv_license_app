import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

/// Plays a Cloudflare Stream Live broadcast over **WHEP** (WebRTC-HTTP Egress
/// Protocol) — sub-second, low-latency playback, the same WebRTC stack we
/// publish with. This is far more reliable than HLS for a just-started stream:
/// HLS can 404 or lag 20–30s while Cloudflare packages segments, whereas WHEP
/// connects the moment the input is live.
///
/// Flow: createPeerConnection (recvonly) → createOffer → POST SDP to the WHEP
/// URL → setRemoteDescription(answer) → the remote track lands in [renderer].
class WhepPlayer {
  final RTCVideoRenderer renderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  bool _rendererReady = false;
  bool _connected = false;
  bool _disposed = false;

  bool get connected => _connected;
  bool get rendererReady => _rendererReady;

  /// Callbacks so the UI can react without polling.
  VoidCallback? onConnected;
  VoidCallback? onFailed;

  Future<void> _ensureRenderer() async {
    if (_rendererReady) return;
    await renderer.initialize();
    _rendererReady = true;
  }

  /// Connect to [whepUrl] and start receiving audio+video.
  Future<void> play(String whepUrl) async {
    if (_disposed) return;
    await _ensureRenderer();
    try {
      final pc = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.cloudflare.com:3478'},
        ],
        'sdpSemantics': 'unified-plan',
      });
      _pc = pc;

      // We only receive — declare recvonly audio + video transceivers.
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      pc.onTrack = (RTCTrackEvent e) {
        if (e.streams.isNotEmpty) {
          renderer.srcObject = e.streams.first;
          if (!_connected && !_disposed) {
            _connected = true;
            onConnected?.call();
          }
        }
      };
      pc.onConnectionState = (state) {
        if (_disposed) return;
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          onFailed?.call();
        }
      };

      final offer = await pc.createOffer({});
      await pc.setLocalDescription(offer);
      final localSdp = await _gatheredSdp(pc, offer);

      final res = await http.post(
        Uri.parse(whepUrl),
        headers: {'Content-Type': 'application/sdp', 'Accept': 'application/sdp'},
        body: localSdp,
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw 'WHEP play failed (${res.statusCode})';
      }
      if (_disposed) return;
      await pc.setRemoteDescription(RTCSessionDescription(res.body, 'answer'));
    } catch (_) {
      onFailed?.call();
      rethrow;
    }
  }

  /// The remote video surface (contain-fit, no mirror).
  Widget view() {
    if (!_rendererReady) return const ColoredBox(color: Color(0xFF0B1120));
    return RTCVideoView(
      renderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    );
  }

  /// Wait for ICE gathering so the SDP carries all candidates (Cloudflare
  /// expects a complete offer, not trickle). Caps the wait at 3s.
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
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    timeout.cancel();
    return (await pc.getLocalDescription())?.sdp ?? offer.sdp!;
  }

  Future<void> dispose() async {
    _disposed = true;
    _connected = false;
    try {
      await _pc?.close();
    } catch (_) {}
    try {
      await renderer.dispose();
    } catch (_) {}
    _pc = null;
  }
}
