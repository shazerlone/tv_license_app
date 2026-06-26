import 'package:flutter/material.dart';

enum UserRole { follower, creator }

/// Whether a creator's verification is still being reviewed.
enum CreatorStatus { none, pending, approved }

class UserProfile {
  final String name;
  final String? photoUrl;
  final UserRole role;
  final String? market; // e.g. 'Forex', 'US', 'India'
  final String? platform; // e.g. 'MetaTrader 5'
  final CreatorStatus creatorStatus;

  const UserProfile({
    required this.name,
    this.photoUrl,
    required this.role,
    this.market,
    this.platform,
    this.creatorStatus = CreatorStatus.none,
  });

  bool get isCreator => role == UserRole.creator;

  UserProfile copyWith({
    String? name,
    String? photoUrl,
    UserRole? role,
    String? market,
    String? platform,
    CreatorStatus? creatorStatus,
  }) {
    return UserProfile(
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      market: market ?? this.market,
      platform: platform ?? this.platform,
      creatorStatus: creatorStatus ?? this.creatorStatus,
    );
  }
}

/// Reactive session holder. Swap the internals for a real backend later;
/// the rest of the app only talks to this controller.
class SessionController extends ChangeNotifier {
  UserProfile? _user;
  UserProfile? get user => _user;

  bool get isSignedIn => _user != null;
  bool get isCreator => _user?.isCreator ?? false;

  void signInAsFollower({required String name, String? photoUrl}) {
    _user = UserProfile(name: name, photoUrl: photoUrl, role: UserRole.follower);
    notifyListeners();
  }

  void signInAsCreator({
    required String name,
    String? photoUrl,
    String? market,
    String? platform,
    CreatorStatus status = CreatorStatus.pending,
  }) {
    _user = UserProfile(
      name: name,
      photoUrl: photoUrl,
      role: UserRole.creator,
      market: market,
      platform: platform,
      creatorStatus: status,
    );
    notifyListeners();
  }

  void signOut() {
    _user = null;
    notifyListeners();
  }
}

/// Makes the [SessionController] available to the whole widget tree and
/// rebuilds dependents when it changes.
class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required super.child,
  }) : super(notifier: controller);

  static SessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope not found in widget tree');
    return scope!.notifier!;
  }
}
