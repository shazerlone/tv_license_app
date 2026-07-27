import 'api_client.dart';
import '../models/api_models.dart';
import '../models/app_notification.dart';

/// Typed access to Millimore backend Milestones 2 & 3
/// (brokers, accounts, creator verification, traders, feed, social).
/// Shapes mirror millimore-backend/openapi.json.
class BackendApi {
  static final _api = ApiClient.instance;

  static List<Map<String, dynamic>> _list(dynamic res, [String? key]) {
    final raw = key != null && res is Map ? res[key] : res;
    if (raw is List) return raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
    return const [];
  }

  // ── Brokers (§4.3) ────────────────────────────────────────────────────────
  static Future<List<Broker>> brokers({String? country}) async {
    final res = await _api.get('/brokers${country != null ? '?country=$country' : ''}');
    return _list(res, res is Map ? 'items' : null).map(Broker.fromJson).toList();
  }

  // ── Trading accounts (§4.3) ───────────────────────────────────────────────
  static Future<List<ApiTradingAccount>> accounts() async {
    final res = await _api.get('/accounts');
    return _list(res, res is Map ? 'items' : null).map(ApiTradingAccount.fromJson).toList();
  }

  static Future<ApiTradingAccount> connectAccount({
    required String brokerId,
    required String accountNumber,
    required String server,
    required String password,
    String? currency,
  }) async {
    final res = await _api.post('/accounts', {
      'brokerId': brokerId,
      'accountNumber': accountNumber,
      'server': server,
      'password': password,
      if (currency != null) 'currency': currency,
    });
    final m = (res is Map && res['account'] is Map ? res['account'] : res) as Map;
    return ApiTradingAccount.fromJson(m.cast<String, dynamic>());
  }

  static Future<void> disconnectAccount(String id) => _api.delete('/accounts/$id');

  static Future<void> changeAccountPassword(String id, {required String current, required String next}) =>
      _api.post('/accounts/$id/password', {'current': current, 'next': next});

  // ── Creator verification (§4.2) ───────────────────────────────────────────
  static Future<CreatorStatusResult> creatorStatus() async {
    final res = await _api.get('/creator/status');
    return CreatorStatusResult.fromJson((res as Map).cast<String, dynamic>());
  }

  static Future<CreatorStatusResult> applyCreator({
    required String market,
    required String platform,
    required Map<String, dynamic> verification,
  }) async {
    final res = await _api.post('/creator/apply', {
      'market': market,
      'platform': platform,
      'verification': verification,
    });
    return CreatorStatusResult.fromJson((res as Map).cast<String, dynamic>());
  }

  // ── Traders / discover (§4.4) ─────────────────────────────────────────────
  static Future<TraderPage> traders({String? category, String? q, String? sort, String? cursor}) async {
    final params = <String, String>{
      if (category != null) 'category': category,
      if (q != null && q.isNotEmpty) 'q': q,
      if (sort != null) 'sort': sort,
      if (cursor != null) 'cursor': cursor,
    };
    final qs = params.isEmpty ? '' : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    final res = await _api.get('/traders$qs');
    return TraderPage.fromJson((res as Map).cast<String, dynamic>());
  }

  static Future<ApiTrader> trader(String id) async {
    final res = await _api.get('/traders/$id');
    final m = (res is Map && res['trader'] is Map ? res['trader'] : res) as Map;
    return ApiTrader.fromJson(m.cast<String, dynamic>());
  }

  static Future<List<PublicTrade>> traderTrades(String id, {String status = 'active'}) async {
    final res = await _api.get('/traders/$id/trades?status=$status');
    return _list(res, res is Map ? 'items' : null).map(PublicTrade.fromJson).toList();
  }

  static Future<List<EquityPoint>> traderEquity(String id, {String range = '30d'}) async {
    final res = await _api.get('/traders/$id/equity?range=$range');
    return _list(res, res is Map ? 'items' : null).map(EquityPoint.fromJson).toList();
  }

  static Future<List<ApiPost>> traderPosts(String id) async {
    final res = await _api.get('/traders/$id/posts');
    return _list(res, res is Map ? 'items' : null).map(ApiPost.fromJson).toList();
  }

  static Future<List<Reel>> reels() async {
    final res = await _api.get('/discover/reels');
    return _list(res, res is Map ? 'items' : null).map(Reel.fromJson).toList();
  }

  // ── Feed & social (§4.5, §4.6) ────────────────────────────────────────────
  static Future<List<ApiPost>> feed({String? cursor}) async {
    final res = await _api.get('/feed${cursor != null ? '?cursor=$cursor' : ''}');
    return _list(res, res is Map ? 'items' : null).map(ApiPost.fromJson).toList();
  }

  static Future<List<ApiPost>> saved() async {
    final res = await _api.get('/saved');
    return _list(res, res is Map ? 'items' : null).map(ApiPost.fromJson).toList();
  }

  static Future<int> likePost(String id) async {
    final res = await _api.post('/posts/$id/like');
    return (res is Map && res['likes'] != null) ? _int(res['likes']) : 0;
  }

  static Future<int> unlikePost(String id) async {
    final res = await _api.delete('/posts/$id/like');
    return (res is Map && res['likes'] != null) ? _int(res['likes']) : 0;
  }

  static Future<void> savePost(String id) => _api.post('/posts/$id/save');
  static Future<void> unsavePost(String id) => _api.delete('/posts/$id/save');

  static Future<List<ApiComment>> comments(String postId) async {
    final res = await _api.get('/posts/$postId/comments');
    return _list(res, res is Map ? 'items' : null).map(ApiComment.fromJson).toList();
  }

  static Future<ApiComment> addComment(String postId, String text) async {
    final res = await _api.post('/posts/$postId/comments', {'text': text});
    final m = (res is Map && res['comment'] is Map ? res['comment'] : res) as Map;
    return ApiComment.fromJson(m.cast<String, dynamic>());
  }

  static Future<ApiPost> createPost({
    required String type,
    required String content,
    String? pair,
    String? title,
    List<String>? points,
  }) async {
    final res = await _api.post('/posts', {
      'type': type,
      'content': content,
      if (pair != null) 'pair': pair,
      if (title != null) 'title': title,
      if (points != null) 'points': points,
    });
    final m = (res is Map && res['post'] is Map ? res['post'] : res) as Map;
    return ApiPost.fromJson(m.cast<String, dynamic>());
  }

  // ── Subscriptions (§4.5) ──────────────────────────────────────────────────
  static Future<List<ApiTrader>> subscriptions() async {
    final res = await _api.get('/subscriptions');
    return _list(res, res is Map ? 'items' : null).map(ApiTrader.fromJson).toList();
  }

  static Future<void> subscribe(String traderId) => _api.post('/subscriptions/$traderId');
  static Future<void> unsubscribe(String traderId) => _api.delete('/subscriptions/$traderId');
  static Future<void> setNotify(String traderId, bool on) => _api.post('/subscriptions/$traderId/notify', {'on': on});

  // ── Notifications (§6a — may not be live yet) ─────────────────────────────
  static Future<List<AppNotification>> notifications({String? cursor}) async {
    final res = await _api.get('/notifications${cursor != null ? '?cursor=$cursor' : ''}');
    return _list(res, res is Map ? 'items' : null).map(AppNotification.fromJson).toList();
  }

  static Future<void> markNotificationsRead(List<String> ids) =>
      _api.post('/notifications/read', {'ids': ids});

  /// Register a device push token (§6b — FCM/APNs). Safe to call best-effort.
  static Future<void> registerDevice({required String platform, required String token, String? appVersion}) =>
      _api.post('/devices', {'platform': platform, 'token': token, if (appVersion != null) 'appVersion': appVersion});

  static int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
}
