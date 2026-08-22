import 'package:flutter/material.dart';
import '../services/auth_store.dart';

enum UserRole { follower, creator }

/// Whether a creator's verification is still being reviewed.
enum CreatorStatus { none, pending, approved }

UserRole _roleFrom(String? s) => s == 'creator' ? UserRole.creator : UserRole.follower;
CreatorStatus _statusFrom(String? s) {
  switch (s) {
    case 'pending':
      return CreatorStatus.pending;
    case 'approved':
      return CreatorStatus.approved;
    default:
      return CreatorStatus.none;
  }
}

class UserProfile {
  final String? id;
  final String name;
  final String? photoUrl;
  final UserRole role;
  final String? market; // e.g. 'Forex', 'US', 'India'
  final String? platform; // e.g. 'MetaTrader 5'
  final String? residenceIso; // e.g. 'IN'
  final String? residenceCountry; // e.g. 'India'
  final CreatorStatus creatorStatus;
  // Milestone 7 — leverage & compliance
  final double leverage; // 1..maxLeverage
  final String kycStatus; // none|pending|verified|rejected
  final String? addressLine;
  final String? city;
  final String? postalCode;
  final String? email;
  final bool emailVerified;
  final bool emailNotifications;

  const UserProfile({
    this.id,
    required this.name,
    this.photoUrl,
    required this.role,
    this.market,
    this.platform,
    this.residenceIso,
    this.residenceCountry,
    this.creatorStatus = CreatorStatus.none,
    this.leverage = 1,
    this.kycStatus = 'none',
    this.addressLine,
    this.city,
    this.postalCode,
    this.email,
    this.emailVerified = false,
    this.emailNotifications = true,
  });

  bool get kycVerified => kycStatus == 'verified';

  bool get isCreator => role == UserRole.creator;

  static String _roleStr(UserRole r) => r == UserRole.creator ? 'creator' : 'follower';
  static String _statusStr(CreatorStatus s) {
    switch (s) {
      case CreatorStatus.pending:
        return 'pending';
      case CreatorStatus.approved:
        return 'approved';
      case CreatorStatus.none:
        return 'none';
    }
  }

  /// Serialised form for local persistence (remember-me).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'photoUrl': photoUrl,
        'role': _roleStr(role),
        'market': market,
        'platform': platform,
        'residenceIso': residenceIso,
        'residenceCountry': residenceCountry,
        'creatorStatus': _statusStr(creatorStatus),
        'leverage': leverage,
        'kycStatus': kycStatus,
        'addressLine': addressLine,
        'city': city,
        'postalCode': postalCode,
        'email': email,
        'emailVerified': emailVerified,
        'emailNotifications': emailNotifications,
      };

  /// Maps a backend `User` (docs/BACKEND_CONTRACT.md §3) to a UserProfile.
  factory UserProfile.fromJson(Map<String, dynamic> j) {
    return UserProfile(
      id: j['id'] as String?,
      name: (j['name'] ?? '').toString(),
      photoUrl: j['photoUrl'] as String?,
      role: _roleFrom(j['role'] as String?),
      market: j['market'] as String?,
      platform: j['platform'] as String?,
      residenceIso: j['residenceIso'] as String?,
      residenceCountry: j['residenceCountry'] as String?,
      creatorStatus: _statusFrom(j['creatorStatus'] as String?),
      leverage: (j['leverage'] as num?)?.toDouble() ?? 1,
      kycStatus: (j['kycStatus'] ?? 'none').toString(),
      addressLine: j['addressLine'] as String?,
      city: j['city'] as String?,
      postalCode: j['postalCode'] as String?,
      email: j['email'] as String?,
      emailVerified: j['emailVerified'] == true,
      emailNotifications: j['emailNotifications'] == null ? true : j['emailNotifications'] == true,
    );
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? photoUrl,
    UserRole? role,
    String? market,
    String? platform,
    String? residenceIso,
    String? residenceCountry,
    CreatorStatus? creatorStatus,
    double? leverage,
    String? kycStatus,
    String? addressLine,
    String? city,
    String? postalCode,
    String? email,
    bool? emailVerified,
    bool? emailNotifications,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      market: market ?? this.market,
      platform: platform ?? this.platform,
      residenceIso: residenceIso ?? this.residenceIso,
      residenceCountry: residenceCountry ?? this.residenceCountry,
      creatorStatus: creatorStatus ?? this.creatorStatus,
      leverage: leverage ?? this.leverage,
      kycStatus: kycStatus ?? this.kycStatus,
      addressLine: addressLine ?? this.addressLine,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      emailNotifications: emailNotifications ?? this.emailNotifications,
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

  /// Restores a persisted session at launch WITHOUT re-persisting it.
  void restore(UserProfile user) {
    _user = user;
    notifyListeners();
  }

  /// Applies a session returned by the backend ({ token, user }).
  void applyBackendSession(UserProfile user) {
    _user = user;
    AuthStore.save(user: user);
    notifyListeners();
  }

  void signInAsFollower({required String name, String? photoUrl, String? residenceIso, String? residenceCountry}) {
    _user = UserProfile(
      name: name,
      photoUrl: photoUrl,
      role: UserRole.follower,
      residenceIso: residenceIso,
      residenceCountry: residenceCountry,
    );
    AuthStore.save(user: _user!);
    notifyListeners();
  }

  void signInAsCreator({
    required String name,
    String? photoUrl,
    String? market,
    String? platform,
    String? residenceIso,
    String? residenceCountry,
    CreatorStatus status = CreatorStatus.pending,
  }) {
    _user = UserProfile(
      name: name,
      photoUrl: photoUrl,
      role: UserRole.creator,
      market: market,
      platform: platform,
      residenceIso: residenceIso,
      residenceCountry: residenceCountry,
      creatorStatus: status,
    );
    AuthStore.save(user: _user!);
    notifyListeners();
  }

  /// Flip the current creator to approved (demo/dev until backend verification).
  void approveCreator() {
    final u = _user;
    if (u != null && u.isCreator) {
      _user = u.copyWith(creatorStatus: CreatorStatus.approved);
      AuthStore.save(user: _user!);
      notifyListeners();
    }
  }

  void signOut() {
    _user = null;
    AuthStore.clear();
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
