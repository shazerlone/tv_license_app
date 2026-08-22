class Comment {
  final String author;
  final String username;
  final String text;
  final DateTime createdAt;
  final bool byMe;

  const Comment({
    required this.author,
    required this.username,
    required this.text,
    required this.createdAt,
    this.byMe = false,
  });

  String get timeAgo {
    final d = DateTime.now().difference(createdAt);
    if (d.inSeconds < 60) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}
