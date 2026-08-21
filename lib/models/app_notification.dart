import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppNotificationType { live, tradeOpened, tradeClosed, copier, subscribe, like, comment, system }

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? traderId;
  bool read;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.traderId,
    this.read = false,
  });

  /// Maps a backend notification (docs/APP_REQUIREMENTS.md §6a) if/when live.
  factory AppNotification.fromJson(Map<String, dynamic> j) {
    AppNotificationType t;
    switch (j['type']) {
      case 'trader.live.started':
        t = AppNotificationType.live;
        break;
      case 'trade.opened':
        t = AppNotificationType.tradeOpened;
        break;
      case 'trade.closed':
        t = AppNotificationType.tradeClosed;
        break;
      case 'copier':
        t = AppNotificationType.copier;
        break;
      case 'social.subscribe':
        t = AppNotificationType.subscribe;
        break;
      case 'social.like':
        t = AppNotificationType.like;
        break;
      case 'social.comment':
        t = AppNotificationType.comment;
        break;
      default:
        t = AppNotificationType.system;
    }
    final data = (j['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AppNotification(
      id: (j['id'] ?? '${DateTime.now().microsecondsSinceEpoch}').toString(),
      type: t,
      title: (j['title'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      createdAt: DateTime.tryParse('${j['createdAt']}')?.toLocal() ?? DateTime.now(),
      traderId: data['traderId']?.toString(),
      read: j['read'] == true,
    );
  }

  IconData get icon {
    switch (type) {
      case AppNotificationType.live:
        return Icons.podcasts_rounded;
      case AppNotificationType.tradeOpened:
        return Icons.trending_up_rounded;
      case AppNotificationType.tradeClosed:
        return Icons.flag_rounded;
      case AppNotificationType.copier:
        return Icons.person_add_rounded;
      case AppNotificationType.subscribe:
        return Icons.person_add_alt_1_rounded;
      case AppNotificationType.like:
        return Icons.favorite_rounded;
      case AppNotificationType.comment:
        return Icons.mode_comment_rounded;
      case AppNotificationType.system:
        return Icons.campaign_rounded;
    }
  }

  Color get color {
    switch (type) {
      case AppNotificationType.live:
        return AppColors.red;
      case AppNotificationType.tradeOpened:
        return AppColors.green;
      case AppNotificationType.tradeClosed:
        return AppColors.primary;
      case AppNotificationType.copier:
        return AppColors.primary;
      case AppNotificationType.subscribe:
        return AppColors.primary;
      case AppNotificationType.like:
        return AppColors.red;
      case AppNotificationType.comment:
        return AppColors.primary;
      case AppNotificationType.system:
        return AppColors.purple;
    }
  }

  String get timeAgo {
    final d = DateTime.now().difference(createdAt);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}
