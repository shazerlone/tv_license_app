import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';

/// Low-level realtime socket to the Millimore gateway
/// (`wss://<host>/v1/ws?token=<JWT>`, contract §5). Handles the subscribe op,
/// the `{ ch, type, data }` envelope, and auto-reconnect with resubscribe.
class WsClient {
  WsClient(this._token);
  final String _token;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final Set<String> _channels = {};
  Timer? _reconnect;
  bool _closed = false;

  /// Stream of decoded server messages `{ ch, type?, data }`.
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  void connect() {
    if (_closed) return;
    try {
      final url = '$kWsBaseUrl?token=$_token';
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _sub = _channel!.stream.listen(
        _onData,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
      if (_channels.isNotEmpty) _send({'op': 'subscribe', 'channels': _channels.toList()});
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void subscribe(List<String> channels) {
    _channels.addAll(channels);
    _send({'op': 'subscribe', 'channels': channels});
  }

  void unsubscribe(List<String> channels) {
    _channels.removeAll(channels);
    _send({'op': 'unsubscribe', 'channels': channels});
  }

  void _send(Map<String, dynamic> msg) {
    try {
      _channel?.sink.add(jsonEncode(msg));
    } catch (_) {/* not connected yet */}
  }

  void _onData(dynamic raw) {
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is Map<String, dynamic>) _controller.add(decoded);
    } catch (_) {/* ignore malformed frame */}
  }

  void _scheduleReconnect() {
    if (_closed || (_reconnect?.isActive ?? false)) return;
    _sub?.cancel();
    _channel = null;
    _reconnect = Timer(const Duration(seconds: 3), connect);
  }

  void dispose() {
    _closed = true;
    _reconnect?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _controller.close();
  }
}
