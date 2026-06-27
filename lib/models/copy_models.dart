/// A trading account the user has connected for copy trading.
class TradingAccount {
  final String id;
  final String brokerId;
  final String brokerName;
  final String accountNumber;
  final String server;
  final String currency;
  final double balance;
  final DateTime connectedAt;

  const TradingAccount({
    required this.id,
    required this.brokerId,
    required this.brokerName,
    required this.accountNumber,
    required this.server,
    this.currency = 'USD',
    this.balance = 0,
    required this.connectedAt,
  });

  String get masked {
    if (accountNumber.length <= 4) return accountNumber;
    return '••••${accountNumber.substring(accountNumber.length - 4)}';
  }
}

/// Per-trader copy configuration (an active copy relationship).
class CopyConfig {
  final String traderId;
  final String accountId;
  final double amount;
  final double risk;
  final bool autoCopy;
  final DateTime startedAt;

  const CopyConfig({
    required this.traderId,
    required this.accountId,
    required this.amount,
    required this.risk,
    required this.autoCopy,
    required this.startedAt,
  });
}

enum PositionStatus { active, closed }

/// A single copied position (one trade mirrored from a trader).
class CopyPosition {
  final String id;
  final String traderId;
  final String traderName;
  final String pair;
  final bool isBuy;
  final PositionStatus status;
  final double entryPrice;
  final double? exitPrice;
  final double pnlAmount;
  final double pnlPercent;
  final double lots;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String accountId;

  const CopyPosition({
    required this.id,
    required this.traderId,
    required this.traderName,
    required this.pair,
    required this.isBuy,
    required this.status,
    required this.entryPrice,
    this.exitPrice,
    required this.pnlAmount,
    required this.pnlPercent,
    required this.lots,
    required this.openedAt,
    this.closedAt,
    required this.accountId,
  });

  bool get isProfit => pnlAmount >= 0;
}
