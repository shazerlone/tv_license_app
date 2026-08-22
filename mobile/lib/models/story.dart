/// A single story (24h). Mirrors the backend StoryDto.
class Story {
  final String id;
  final String userId;
  final String mediaUrl;
  final String mediaType; // image | video
  final String? caption;
  final String kind; // normal | recap
  final String? broadcastId;
  final bool viewed;
  final DateTime createdAt;

  const Story({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    this.kind = 'normal',
    this.broadcastId,
    this.viewed = false,
    required this.createdAt,
  });

  bool get isVideo => mediaType == 'video';

  factory Story.fromJson(Map<String, dynamic> j) => Story(
        id: (j['id'] ?? '').toString(),
        userId: (j['userId'] ?? '').toString(),
        mediaUrl: (j['mediaUrl'] ?? '').toString(),
        mediaType: (j['mediaType'] ?? 'image').toString(),
        caption: j['caption'] as String?,
        kind: (j['kind'] ?? 'normal').toString(),
        broadcastId: j['broadcastId'] as String?,
        viewed: j['viewed'] == true,
        createdAt: DateTime.tryParse('${j['createdAt']}')?.toLocal() ?? DateTime.now(),
      );
}

/// One author's active stories (a tray item / viewer page).
class StoryGroup {
  final String userId;
  final String name;
  final String username;
  final String? photoUrl;
  final List<Story> stories;
  final bool hasUnseen;

  const StoryGroup({
    required this.userId,
    required this.name,
    required this.username,
    this.photoUrl,
    required this.stories,
    this.hasUnseen = false,
  });

  factory StoryGroup.fromJson(Map<String, dynamic> j) {
    final u = (j['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    return StoryGroup(
      userId: (u['id'] ?? '').toString(),
      name: (u['name'] ?? '').toString(),
      username: (u['username'] ?? '').toString(),
      photoUrl: u['photoUrl'] as String?,
      stories: ((j['stories'] as List?) ?? const [])
          .map((e) => Story.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      hasUnseen: j['hasUnseen'] == true,
    );
  }
}
