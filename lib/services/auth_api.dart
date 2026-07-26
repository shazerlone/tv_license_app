import 'api_client.dart';
import '../state/session.dart';

/// Auth endpoints (docs/BACKEND_CONTRACT.md §4.1). Milestone 1.
class AuthApi {
  static final _api = ApiClient.instance;

  /// Applies { token, user } from a response: stores token, returns profile.
  static UserProfile _session(Map res) {
    final token = res['token'] as String?;
    if (token != null) _api.setToken(token);
    final user = (res['user'] as Map).cast<String, dynamic>();
    return UserProfile.fromJson(user);
  }

  static Future<UserProfile> login({required String email, required String password}) async {
    final res = await _api.post('/auth/login', {'email': email, 'password': password});
    return _session(res as Map);
  }

  /// Creates a follower account, then requests an OTP. Returns requestId.
  static Future<String> registerFollower({
    required String name,
    required String phone,
    String? residenceIso,
    String? experience,
    List<String>? interests,
    String? photoUrl,
  }) async {
    await _api.post('/auth/register/follower', {
      'name': name,
      'phone': phone,
      'residenceIso': residenceIso,
      'experience': experience,
      'interests': interests,
      'photoUrl': photoUrl,
    });
    return requestOtp(phone);
  }

  /// Creates a creator application, then requests an OTP. Returns requestId.
  static Future<String> registerCreator({
    required String name,
    required String phone,
    String? residenceIso,
    String? market,
    String? platform,
    Map<String, dynamic>? verification,
  }) async {
    await _api.post('/auth/register/creator', {
      'name': name,
      'phone': phone,
      'residenceIso': residenceIso,
      'market': market,
      'platform': platform,
      'verification': verification,
    });
    return requestOtp(phone);
  }

  static Future<String> requestOtp(String phone) async {
    final res = await _api.post('/auth/otp/request', {'phone': phone});
    return (res as Map)['requestId'].toString();
  }

  static Future<UserProfile> verifyOtp({required String requestId, required String code}) async {
    final res = await _api.post('/auth/otp/verify', {'requestId': requestId, 'code': code});
    return _session(res as Map);
  }

  static Future<UserProfile> me() async {
    final res = await _api.get('/me');
    return UserProfile.fromJson(((res as Map)['user'] as Map).cast<String, dynamic>());
  }

  static void logout() => _api.clear();
}
