import 'api_client.dart';
import 'auth_store.dart';
import '../state/session.dart';

/// Result of an OTP request. In dev/console OTP mode the backend also returns
/// [devCode] so the app can be tested without a real SMS gateway.
class OtpRequest {
  final String requestId;
  final String? devCode;
  const OtpRequest(this.requestId, this.devCode);
}

/// Auth endpoints (docs/BACKEND_CONTRACT.md §4.1, backend openapi.json). Milestone 1.
///
/// Register/login/verify all return AuthResponseDto `{ token, user }` — an
/// immediate authenticated session. Only the phone-login path uses OTP.
class AuthApi {
  static final _api = ApiClient.instance;

  /// Applies { token, user } from a response: stores token, returns profile.
  static UserProfile _session(Map res) {
    final token = res['token'] as String?;
    if (token != null) {
      _api.setToken(token);
      AuthStore.saveToken(token);
    }
    final user = (res['user'] as Map).cast<String, dynamic>();
    return UserProfile.fromJson(user);
  }

  /// Signs in with email + password. If the account has 2FA enabled, the first
  /// call throws `ApiException(code: 'twofa_required')`; resubmit with
  /// [twofaCode] (a TOTP code or a one-time backup code). A wrong code throws
  /// `twofa_invalid`.
  static Future<UserProfile> login({required String email, required String password, String? twofaCode}) async {
    final res = await _api.post('/auth/login', {
      'email': email,
      'password': password,
      if (twofaCode != null && twofaCode.isNotEmpty) 'twofaCode': twofaCode,
    });
    return _session(res as Map);
  }

  /// Creates a follower account and signs in immediately (backend returns
  /// { token, user }). No OTP step.
  static Future<UserProfile> registerFollower({
    required String name,
    required String phone,
    String? residenceIso,
    String? experience,
    List<String>? interests,
    String? photoUrl,
    String? email,
    String? password,
  }) async {
    final res = await _api.post('/auth/register/follower', {
      'name': name,
      'phone': phone,
      if (residenceIso != null) 'residenceIso': residenceIso,
      if (experience != null) 'experience': experience,
      if (interests != null) 'interests': interests,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (email != null && email.isNotEmpty) 'email': email,
      if (password != null && password.isNotEmpty) 'password': password,
    });
    return _session(res as Map);
  }

  /// Creates a creator application and signs in immediately with a pending
  /// creatorStatus (backend returns { token, user }).
  static Future<UserProfile> registerCreator({
    required String name,
    required String phone,
    required String residenceIso,
    required String market,
    required String platform,
    required Map<String, dynamic> verification,
    String? email,
    String? password,
  }) async {
    final res = await _api.post('/auth/register/creator', {
      'name': name,
      'phone': phone,
      'residenceIso': residenceIso,
      'market': market,
      'platform': platform,
      'verification': verification,
      if (email != null && email.isNotEmpty) 'email': email,
      if (password != null && password.isNotEmpty) 'password': password,
    });
    return _session(res as Map);
  }

  /// Requests an OTP for a phone number. Returns the requestId (+ devCode in
  /// console OTP mode).
  static Future<OtpRequest> requestOtp(String phone) async {
    final res = await _api.post('/auth/otp/request', {'phone': phone}) as Map;
    return OtpRequest(res['requestId'].toString(), res['devCode']?.toString());
  }

  static Future<UserProfile> verifyOtp({required String requestId, required String code}) async {
    final res = await _api.post('/auth/otp/verify', {'requestId': requestId, 'code': code});
    return _session(res as Map);
  }

  static Future<UserProfile> me() async {
    final res = await _api.get('/me');
    return UserProfile.fromJson(((res as Map)['user'] as Map).cast<String, dynamic>());
  }

  static Future<UserProfile> updateMe(Map<String, dynamic> fields) async {
    final res = await _api.patch('/me', fields);
    return UserProfile.fromJson(((res as Map)['user'] as Map).cast<String, dynamic>());
  }

  /// Send/resend the 6-digit email verification code. Returns devCode in dev.
  static Future<String?> sendEmailCode() async {
    final res = await _api.post('/me/email/send-code');
    return (res is Map ? res['devCode'] : null)?.toString();
  }

  /// Verify the emailed code. Throws ApiException on code_mismatch/expired/etc.
  static Future<bool> verifyEmail(String code) async {
    final res = await _api.post('/me/email/verify', {'code': code});
    return (res is Map ? res['emailVerified'] == true : false);
  }

  /// Permanently delete the account (frees email/phone), then clears the token.
  static Future<void> deleteAccount() async {
    await _api.delete('/me');
    _api.clear();
  }

  static void logout() {
    // Best-effort server logout (stateless JWT — client discards regardless).
    _api.post('/auth/logout').catchError((_) => null);
    _api.clear();
  }
}
