enum TradeDirection { buy, sell }
enum TradeStatus { open, closed, pending }

class Trade {
  final String id;
  final String traderId;
  final String pair;
  final TradeDirection direction;
  final TradeStatus status;
  final double entryPrice;
  final double? currentPrice;
  final double? stopLoss;
  final double? takeProfit;
  final double pnlPercent;
  final DateTime openedAt;
  final DateTime? closedAt;

  const Trade({
    required this.id,
    required this.traderId,
    required this.pair,
    required this.direction,
    required this.status,
    required this.entryPrice,
    this.currentPrice,
    this.stopLoss,
    this.takeProfit,
    this.pnlPercent = 0,
    required this.openedAt,
    this.closedAt,
  });

  bool get isProfit => pnlPercent >= 0;

  String get formattedPnl {
    final sign = pnlPercent >= 0 ? '+' : '';
    return '$sign${pnlPercent.toStringAsFixed(2)}%';
  }

  String get directionLabel => direction == TradeDirection.buy ? 'BUY' : 'SELL';
}

final List<Trade> mockTrades = [
  Trade(
    id: 't1',
    traderId: '1',
    pair: 'EUR/USD',
    direction: TradeDirection.buy,
    status: TradeStatus.open,
    entryPrice: 1.08760,
    currentPrice: 1.08764,
    stopLoss: 1.08610,
    takeProfit: 1.09220,
    pnlPercent: 0.47,
    openedAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  Trade(
    id: 't2',
    traderId: '1',
    pair: 'XAU/USD',
    direction: TradeDirection.sell,
    status: TradeStatus.closed,
    entryPrice: 2342.50,
    currentPrice: 2318.30,
    pnlPercent: 1.03,
    openedAt: DateTime.now().subtract(const Duration(days: 1)),
    closedAt: DateTime.now().subtract(const Duration(hours: 6)),
  ),
  Trade(
    id: 't3',
    traderId: '2',
    pair: 'BTC/USD',
    direction: TradeDirection.buy,
    status: TradeStatus.open,
    entryPrice: 67200.0,
    currentPrice: 68450.0,
    stopLoss: 65000.0,
    takeProfit: 72000.0,
    pnlPercent: 1.86,
    openedAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
];
