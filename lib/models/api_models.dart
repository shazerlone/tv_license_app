/// DTOs mirroring the Millimore backend (millimore-backend/openapi.json,
/// Milestones 2 & 3). Kept separate from the demo models so screens can migrate
/// from mock data to the live API incrementally.

int _asInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
double _asDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

// ── Brokers (§4.3) ──────────────────────────────────────────────────────────
class Broker {
  final String id;
  final String name;
  final String domain;
  final String? logoUrl;
  final bool recommended;
  const Broker({required this.id, required this.name, required this.domain, this.logoUrl, this.recommended = false});
  factory Broker.fromJson(Map<String, dynamic> j) => Broker(
        id: j['id'].toString(),
        name: j['name'].toString(),
        domain: j['domain'].toString(),
        logoUrl: j['logoUrl'] as String?,
        recommended: j['recommended'] == true,
      );
}

// ── Trading accounts (§4.3) ─────────────────────────────────────────────────
enum ApiAccountStatus { connected, pending, disconnected, error }

ApiAccountStatus _accountStatus(String? s) {
  switch (s) {
    case 'connected':
      return ApiAccountStatus.connected;
    case 'pending':
      return ApiAccountStatus.pending;
    case 'error':
      return ApiAccountStatus.error;
    default:
      return ApiAccountStatus.disconnected;
  }
}

class ApiTradingAccount {
  final String id;
  final String brokerId;
  final String brokerName;
  final String accountNumber;
  final String masked;
  final String server;
  final String currency;
  final double balance;
  final ApiAccountStatus status;
  final String connectedAt;
  const ApiTradingAccount({
    required this.id,
    required this.brokerId,
    required this.brokerName,
    required this.accountNumber,
    required this.masked,
    required this.server,
    required this.currency,
    required this.balance,
    required this.status,
    required this.connectedAt,
  });
  factory ApiTradingAccount.fromJson(Map<String, dynamic> j) => ApiTradingAccount(
        id: j['id'].toString(),
        brokerId: j['brokerId'].toString(),
        brokerName: j['brokerName'].toString(),
        accountNumber: j['accountNumber'].toString(),
        masked: j['masked'].toString(),
        server: j['server'].toString(),
        currency: j['currency']?.toString() ?? 'USD',
        balance: _asDouble(j['balance']),
        status: _accountStatus(j['status'] as String?),
        connectedAt: j['connectedAt']?.toString() ?? '',
      );
}

// ── Creator status (§4.2) ───────────────────────────────────────────────────
class CreatorStatusResult {
  final String creatorStatus; // none|pending|approved|rejected|suspended
  final String? reason;
  const CreatorStatusResult(this.creatorStatus, this.reason);
  factory CreatorStatusResult.fromJson(Map<String, dynamic> j) =>
      CreatorStatusResult(j['creatorStatus'].toString(), j['reason'] as String?);
}

// ── Traders / discover (§4.4) ───────────────────────────────────────────────
class ApiTrader {
  final String id;
  final String name;
  final String username;
  final String? photoUrl;
  final bool isVerified;
  final bool isLive;
  final double returnPercent;
  final int returnDays;
  final int followers;
  final int copiers;
  final double aum;
  final double winRate;
  final double maxDrawdown;
  final int totalTrades;
  final String category;
  final List<String> tags;
  final String? bio;
  const ApiTrader({
    required this.id,
    required this.name,
    required this.username,
    this.photoUrl,
    required this.isVerified,
    required this.isLive,
    required this.returnPercent,
    required this.returnDays,
    required this.followers,
    required this.copiers,
    required this.aum,
    required this.winRate,
    required this.maxDrawdown,
    required this.totalTrades,
    required this.category,
    required this.tags,
    this.bio,
  });
  factory ApiTrader.fromJson(Map<String, dynamic> j) => ApiTrader(
        id: j['id'].toString(),
        name: j['name'].toString(),
        username: j['username'].toString(),
        photoUrl: j['photoUrl'] as String?,
        isVerified: j['isVerified'] == true,
        isLive: j['isLive'] == true,
        returnPercent: _asDouble(j['returnPercent']),
        returnDays: _asInt(j['returnDays']),
        followers: _asInt(j['followers']),
        copiers: _asInt(j['copiers']),
        aum: _asDouble(j['aum']),
        winRate: _asDouble(j['winRate']),
        maxDrawdown: _asDouble(j['maxDrawdown']),
        totalTrades: _asInt(j['totalTrades']),
        category: j['category']?.toString() ?? 'Forex',
        tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        bio: j['bio'] as String?,
      );
}

class TraderPage {
  final List<ApiTrader> items;
  final String? nextCursor;
  const TraderPage(this.items, this.nextCursor);
  factory TraderPage.fromJson(Map<String, dynamic> j) => TraderPage(
        (j['items'] as List? ?? const []).map((e) => ApiTrader.fromJson((e as Map).cast<String, dynamic>())).toList(),
        j['nextCursor'] as String?,
      );
}

class PublicTrade {
  final String id;
  final String traderId;
  final String traderName;
  final String pair;
  final bool isBuy;
  final String status; // active|closed
  final double entryPrice;
  final double? exitPrice;
  final double pnlAmount;
  final double pnlPercent;
  final double lots;
  final String openedAt;
  final String? closedAt;
  const PublicTrade({
    required this.id,
    required this.traderId,
    required this.traderName,
    required this.pair,
    required this.isBuy,
    required this.status,
    required this.entryPrice,
    this.exitPrice,
    required this.pnlAmount,
    required this.pnlPercent,
    required this.lots,
    required this.openedAt,
    this.closedAt,
  });
  factory PublicTrade.fromJson(Map<String, dynamic> j) => PublicTrade(
        id: j['id'].toString(),
        traderId: j['traderId'].toString(),
        traderName: j['traderName'].toString(),
        pair: j['pair'].toString(),
        isBuy: j['isBuy'] == true,
        status: j['status']?.toString() ?? 'active',
        entryPrice: _asDouble(j['entryPrice']),
        exitPrice: j['exitPrice'] == null ? null : _asDouble(j['exitPrice']),
        pnlAmount: _asDouble(j['pnlAmount']),
        pnlPercent: _asDouble(j['pnlPercent']),
        lots: _asDouble(j['lots']),
        openedAt: j['openedAt']?.toString() ?? '',
        closedAt: j['closedAt'] as String?,
      );
}

class EquityPoint {
  final String t;
  final double value;
  const EquityPoint(this.t, this.value);
  factory EquityPoint.fromJson(Map<String, dynamic> j) => EquityPoint(j['t'].toString(), _asDouble(j['value']));
}

// ── Feed / social (§4.5, §4.6) ──────────────────────────────────────────────
class ApiPost {
  final String id;
  final ApiTrader trader;
  final String type; // analysis|trade|lesson|update
  final String content;
  final String? pair;
  final String? title;
  final List<String> points;
  final int likes;
  final int comments;
  final String createdAt;
  final bool isLiked;
  final bool saved;
  const ApiPost({
    required this.id,
    required this.trader,
    required this.type,
    required this.content,
    this.pair,
    this.title,
    required this.points,
    required this.likes,
    required this.comments,
    required this.createdAt,
    required this.isLiked,
    required this.saved,
  });
  factory ApiPost.fromJson(Map<String, dynamic> j) => ApiPost(
        id: j['id'].toString(),
        trader: ApiTrader.fromJson((j['trader'] as Map).cast<String, dynamic>()),
        type: j['type']?.toString() ?? 'update',
        content: j['content']?.toString() ?? '',
        pair: j['pair'] as String?,
        title: j['title'] as String?,
        points: (j['points'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        likes: _asInt(j['likes']),
        comments: _asInt(j['comments']),
        createdAt: j['createdAt']?.toString() ?? '',
        isLiked: j['isLiked'] == true,
        saved: j['saved'] == true,
      );
}

class ApiComment {
  final String id;
  final String author;
  final String username;
  final String text;
  final String createdAt;
  final bool byMe;
  const ApiComment({
    required this.id,
    required this.author,
    required this.username,
    required this.text,
    required this.createdAt,
    required this.byMe,
  });
  factory ApiComment.fromJson(Map<String, dynamic> j) => ApiComment(
        id: j['id'].toString(),
        author: j['author'].toString(),
        username: j['username'].toString(),
        text: j['text'].toString(),
        createdAt: j['createdAt']?.toString() ?? '',
        byMe: j['byMe'] == true,
      );
}

class Reel {
  final String kind; // live|trade|lesson
  final ApiTrader trader;
  final ApiPost? post;
  final String? title;
  final List<String> points;
  final int? viewers;
  const Reel({required this.kind, required this.trader, this.post, this.title, required this.points, this.viewers});
  factory Reel.fromJson(Map<String, dynamic> j) => Reel(
        kind: j['kind']?.toString() ?? 'trade',
        trader: ApiTrader.fromJson((j['trader'] as Map).cast<String, dynamic>()),
        post: j['post'] == null ? null : ApiPost.fromJson((j['post'] as Map).cast<String, dynamic>()),
        title: j['title'] as String?,
        points: (j['points'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        viewers: j['viewers'] == null ? null : _asInt(j['viewers']),
      );
}
