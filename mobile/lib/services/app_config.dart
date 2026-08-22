import 'api_client.dart';

/// App-wide config from GET /config (milestone 7, PublicConfigDto). Loaded once
/// on launch; falls back to sensible defaults if unavailable.
class AppConfig {
  static AppConfig instance = AppConfig._();
  AppConfig._();

  double maxLeverage = 1;
  double defaultLeverage = 1;
  double minDeposit = 0;
  double minWithdrawal = 0;
  double maxWithdrawalPerTx = 0; // 0 = no cap known
  double maxWithdrawalPerDay = 0;
  bool kycRequiredForWithdrawal = false;
  bool maintenanceMode = false;
  // [{id,label,active,comingSoon?}]
  List<Map<String, dynamic>> depositMethods = const [];
  bool loaded = false;

  static double _d(dynamic v, double f) => v is num ? v.toDouble() : f;

  Future<void> load() async {
    try {
      final res = await ApiClient.instance.get('/config');
      if (res is Map) {
        maxLeverage = _d(res['maxLeverage'], 1);
        defaultLeverage = _d(res['defaultLeverage'], 1);
        minDeposit = _d(res['minDeposit'], 0);
        minWithdrawal = _d(res['minWithdrawal'], 0);
        maxWithdrawalPerTx = _d(res['maxWithdrawalPerTx'], 0);
        maxWithdrawalPerDay = _d(res['maxWithdrawalPerDay'], 0);
        kycRequiredForWithdrawal = res['kycRequiredForWithdrawal'] == true;
        maintenanceMode = res['maintenanceMode'] == true;
        final methods = res['depositMethods'];
        if (methods is List) {
          depositMethods = methods.map((e) => (e as Map).cast<String, dynamic>()).toList();
        }
        loaded = true;
      }
    } catch (_) {
      // keep defaults
    }
  }
}
