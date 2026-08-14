import 'trader.dart';
import 'api_models.dart';

enum PostType { analysis, trade, live, update }

PostType _postTypeFromApi(String t) {
  switch (t) {
    case 'trade':
      return PostType.trade;
    case 'update':
      return PostType.update;
    case 'lesson':
    case 'analysis':
    default:
      return PostType.analysis;
  }
}

class Post {
  final String id;
  final Trader trader;
  final PostType type;
  final String content;
  final String? pair;
  final String? chartImageUrl;
  final int likes;
  final int comments;
  final DateTime createdAt;
  final bool isLiked;
  // Trade posts: direction + levels so the feed can render a proper trade card.
  final String? side; // buy|sell
  final double? entryPrice;
  final double? sl;
  final double? tp;

  const Post({
    required this.id,
    required this.trader,
    required this.type,
    required this.content,
    this.pair,
    this.chartImageUrl,
    this.likes = 0,
    this.comments = 0,
    required this.createdAt,
    this.isLiked = false,
    this.side,
    this.entryPrice,
    this.sl,
    this.tp,
  });

  /// Maps a backend ApiPost (openapi.json §4.5) onto the UI model.
  factory Post.fromApi(ApiPost a) {
    final t = a.trade;
    double? num(k) => (t?[k] as num?)?.toDouble();
    return Post(
      id: a.id,
      trader: Trader.fromApi(a.trader),
      type: _postTypeFromApi(a.type),
      content: a.content,
      pair: a.pair,
      chartImageUrl: a.imageUrl,
      likes: a.likes,
      comments: a.comments,
      createdAt: DateTime.tryParse(a.createdAt)?.toLocal() ?? DateTime.now(),
      isLiked: a.isLiked,
      side: t?['side']?.toString(),
      entryPrice: num('entryPrice'),
      sl: num('sl'),
      tp: num('tp'),
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

List<Post> mockPosts(List<Trader> traders) => [
  Post(
    id: 'p1',
    trader: traders[0],
    type: PostType.analysis,
    content: 'EUR/USD is holding above the key 1.0870 support. Looking for a breakout above 1.0920 before adding to my long. SL tight at 1.0850.',
    pair: 'EUR/USD',
    likes: 284,
    comments: 47,
    createdAt: DateTime.now().subtract(const Duration(minutes: 23)),
  ),
  Post(
    id: 'p2',
    trader: traders[1],
    type: PostType.trade,
    content: 'Closed BTC long for +186 pips. Market structure is shifting — I expect a brief pullback before the next leg up. Will re-enter on confirmation.',
    pair: 'BTC/USD',
    likes: 512,
    comments: 89,
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    isLiked: true,
  ),
  Post(
    id: 'p3',
    trader: traders[2],
    type: PostType.update,
    content: 'Going live in 10 minutes. I will be breaking down the US500 setup and sharing my exact entry criteria. See you there.',
    likes: 143,
    comments: 31,
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
];
