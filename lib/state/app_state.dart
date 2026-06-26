import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/comment.dart';

/// The app's reactive data store: subscriptions, saved posts, likes and
/// comments. Swap the in-memory maps for a backend later — the UI only talks
/// to this controller, so nothing else changes.
class AppState extends ChangeNotifier {
  // traderId -> subscribed
  final Set<String> _subscribed = {'1', '2', '3'};
  // traderId -> notifications on
  final Set<String> _notify = {'1'};
  // postId -> saved
  final Set<String> _saved = {};
  // postId -> liked
  final Map<String, bool> _liked = {};
  final Map<String, int> _likeCount = {};
  // postId -> comments
  final Map<String, List<Comment>> _comments = {};

  // ── Subscriptions ──────────────────────────────────────────────────────────
  bool isSubscribed(String traderId) => _subscribed.contains(traderId);
  int get subscriptionCount => _subscribed.length;
  Set<String> get subscribedTraderIds => _subscribed;

  void subscribe(String traderId) {
    _subscribed.add(traderId);
    _notify.add(traderId);
    notifyListeners();
  }

  void unsubscribe(String traderId) {
    _subscribed.remove(traderId);
    _notify.remove(traderId);
    notifyListeners();
  }

  void toggleSubscribe(String traderId) =>
      isSubscribed(traderId) ? unsubscribe(traderId) : subscribe(traderId);

  bool isNotifying(String traderId) => _notify.contains(traderId);
  void toggleNotify(String traderId) {
    _notify.contains(traderId) ? _notify.remove(traderId) : _notify.add(traderId);
    notifyListeners();
  }

  // ── Saved posts ────────────────────────────────────────────────────────────
  bool isSaved(String postId) => _saved.contains(postId);
  int get savedCount => _saved.length;
  Set<String> get savedPostIds => _saved;

  void toggleSave(String postId) {
    _saved.contains(postId) ? _saved.remove(postId) : _saved.add(postId);
    notifyListeners();
  }

  // ── Likes ──────────────────────────────────────────────────────────────────
  bool isLiked(Post post) {
    return _liked.putIfAbsent(post.id, () => post.isLiked);
  }

  int likeCount(Post post) {
    return _likeCount.putIfAbsent(post.id, () => post.likes);
  }

  void toggleLike(Post post) {
    final liked = isLiked(post);
    _liked[post.id] = !liked;
    _likeCount[post.id] = likeCount(post) + (!liked ? 1 : -1);
    notifyListeners();
  }

  // ── Comments ──────────────────────────────────────────────────────────────
  List<Comment> commentsFor(Post post) {
    return _comments.putIfAbsent(post.id, () => _seedComments(post));
  }

  int commentCount(Post post) => commentsFor(post).length;

  void addComment(Post post, String text) {
    final list = commentsFor(post);
    list.insert(
      0,
      Comment(
        author: 'You',
        username: 'you',
        text: text,
        createdAt: DateTime.now(),
        byMe: true,
      ),
    );
    notifyListeners();
  }

  List<Comment> _seedComments(Post post) {
    // A little realistic seed so the thread isn't empty.
    return [
      Comment(author: 'Priya Nair', username: 'priyatrades', text: 'Great breakdown, thanks for sharing 🙏', createdAt: DateTime.now().subtract(const Duration(minutes: 12))),
      Comment(author: 'Daniel Kim', username: 'dkfx', text: 'Watching this level too. Patient entry is key.', createdAt: DateTime.now().subtract(const Duration(minutes: 40))),
      Comment(author: 'Sofia Rossi', username: 'sofiafx', text: 'Copied 👀 let\'s see how it plays out', createdAt: DateTime.now().subtract(const Duration(hours: 1))),
    ];
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState controller,
    required super.child,
  }) : super(notifier: controller);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in widget tree');
    return scope!.notifier!;
  }
}
