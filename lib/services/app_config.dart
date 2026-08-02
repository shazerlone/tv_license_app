import 'api_client.dart';

/// App-wide config from GET /config (milestone 7): leverage cap, withdrawal
/// limits, active deposit methods, and whether KYC is required to withdraw.
/// Loaded once on launch; falls back to sensible defaults if unavailable.
class AppConfig {
  static AppConfig instance = AppConfig._();
  AppConfig._();

  double maxLeverage = 1;
  bool kycRequiredForWithdrawal = false;
  double minWithdrawal = 0;
  double? maxWithdrawal;
  List<String> activeDepositMethods = const [];
  bool loaded = false;

  static double _d(dynamic v, double f) => v is num ? v.toDouble() : f;

  Future<void> load() async {
    try {
      final res = await ApiClient.instance.get('/config');
      if (res is Map) {
        maxLeverage = _d(res['maxLeverage'], 1);
        kycRequiredForWithdrawal = res['kycRequiredForWithdrawal'] == true;
        final limits = (res['limits'] is Map) ? res['limits'] as Map : res;
        minWithdrawal = _d(limits['minWithdrawal'] ?? res['minWithdrawal'], 0);
        final mx = limits['maxWithdrawal'] ?? res['maxWithdrawal'];
        maxWithdrawal = mx is num ? mx.toDouble() : null;
        final methods = res['activeDepositMethods'] ?? res['depositMethods'];
        if (methods is List) activeDepositMethods = methods.map((e) => e.toString()).toList();
        loaded = true;
      }
    } catch (_) {
      // keep defaults
    }
  }
}
