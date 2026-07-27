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

  factory CopyConfig.fromJson(Map<String, dynamic> j) => CopyConfig(
        traderId: j['traderId'].toString(),
        accountId: j['accountId'].toString(),
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        risk: (j['risk'] as num?)?.toDouble() ?? 1,
        autoCopy: j['autoCopy'] == true,
        startedAt: DateTime.tryParse('${j['startedAt']}')?.toLocal() ?? DateTime.now(),
      );
}

/// Aggregated copy-trading portfolio numbers (GET /portfolio/summary).
class PortfolioSummary {
  final double netPnl, openPnl, bookedProfit, bookedLoss, invested;
  final int copyingCount, activeCount, closedCount;
  const PortfolioSummary({
    required this.netPnl,
    required this.openPnl,
    required this.bookedProfit,
    required this.bookedLoss,
    required this.invested,
    required this.copyingCount,
    required this.activeCount,
    required this.closedCount,
  });
  factory PortfolioSummary.fromJson(Map<String, dynamic> j) {
    double d(k) => (j[k] as num?)?.toDouble() ?? 0;
    int i(k) => (j[k] as num?)?.toInt() ?? 0;
    return PortfolioSummary(
      netPnl: d('netPnl'),
      openPnl: d('openPnl'),
      bookedProfit: d('bookedProfit'),
      bookedLoss: d('bookedLoss'),
      invested: d('invested'),
      copyingCount: i('copyingCount'),
      activeCount: i('activeCount'),
      closedCount: i('closedCount'),
    );
  }
}

enum ChatSource { millimore, youtube, facebook }

/// A live-chat message, aggregated from Millimore + connected platforms
/// (YouTube/Facebook chat via their APIs on the backend later).
class LiveChatMessage {
  final String author;
  final String text;
  final ChatSource source;
  final bool byHost;

  const LiveChatMessage({
    required this.author,
    required this.text,
    this.source = ChatSource.millimore,
    this.byHost = false,
  });
}

enum LiveOrderType { market, limit }

/// A trade the broadcasting trader places live on-stream (mirrors to their
/// connected MT account via backend later). Shown as the live overlay.
class LiveTrade {
  final String id;
  final String symbol;
  final bool isBuy;
  final LiveOrderType orderType;
  final double entryPrice;
  final double lots;
  final double? sl;
  final double? tp;
  final double? limitPrice;
  final DateTime openedAt;

  const LiveTrade({
    required this.id,
    required this.symbol,
    required this.isBuy,
    required this.orderType,
    required this.entryPrice,
    this.lots = 0.10,
    this.sl,
    this.tp,
    this.limitPrice,
    required this.openedAt,
  });

  String get directionLabel => isBuy ? 'BUY' : 'SELL';
  bool get isPending => orderType == LiveOrderType.limit && limitPrice != null;
}

/// A closed live trade for the history log.
class ClosedTrade {
  final String symbol;
  final bool isBuy;
  final double pnl;
  final double lots;
  final DateTime openedAt;
  final DateTime closedAt;

  const ClosedTrade({
    required this.symbol,
    required this.isBuy,
    required this.pnl,
    required this.lots,
    required this.openedAt,
    required this.closedAt,
  });

  String get directionLabel => isBuy ? 'BUY' : 'SELL';
  bool get isProfit => pnl >= 0;
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

  factory CopyPosition.fromJson(Map<String, dynamic> j) => CopyPosition(
        id: j['id'].toString(),
        traderId: j['traderId'].toString(),
        traderName: j['traderName'].toString(),
        pair: j['pair'].toString(),
        isBuy: j['isBuy'] == true,
        status: j['status'] == 'closed' ? PositionStatus.closed : PositionStatus.active,
        entryPrice: (j['entryPrice'] as num?)?.toDouble() ?? 0,
        exitPrice: (j['exitPrice'] as num?)?.toDouble(),
        pnlAmount: (j['pnlAmount'] as num?)?.toDouble() ?? 0,
        pnlPercent: (j['pnlPercent'] as num?)?.toDouble() ?? 0,
        lots: (j['lots'] as num?)?.toDouble() ?? 0,
        openedAt: DateTime.tryParse('${j['openedAt']}')?.toLocal() ?? DateTime.now(),
        closedAt: j['closedAt'] != null ? DateTime.tryParse('${j['closedAt']}')?.toLocal() : null,
        accountId: j['accountId']?.toString() ?? '',
      );
}
