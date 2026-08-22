import 'package:flutter/material.dart';

class TradingMarket {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  const TradingMarket(this.id, this.name, this.subtitle, this.icon);
}

class TradingPlatform {
  final String name;
  final String market; // market id
  final bool usesInvestorPassword; // true => server + account + read-only pw
  const TradingPlatform(this.name, this.market, this.usesInvestorPassword);
}

/// Forex is our primary focus, so it's listed first.
const List<TradingMarket> kMarkets = [
  TradingMarket('forex', 'Forex & CFDs', 'Currencies, gold, indices · our focus', Icons.public_rounded),
  TradingMarket('us', 'US Market', 'Stocks & options', Icons.attach_money_rounded),
  TradingMarket('india', 'Indian Market', 'Equity & F&O', Icons.currency_rupee_rounded),
  TradingMarket('crypto', 'Crypto', 'Spot & futures', Icons.currency_bitcoin_rounded),
];

const List<TradingPlatform> kPlatforms = [
  // Forex — mostly MetaTrader-style with investor password
  TradingPlatform('MetaTrader 5', 'forex', true),
  TradingPlatform('MetaTrader 4', 'forex', true),
  TradingPlatform('cTrader', 'forex', true),
  TradingPlatform('DXtrade', 'forex', true),
  TradingPlatform('TradingView', 'forex', false),

  // US — broker accounts, verified via statement upload
  TradingPlatform('Interactive Brokers', 'us', false),
  TradingPlatform('Webull', 'us', false),
  TradingPlatform('Tastytrade', 'us', false),
  TradingPlatform('TradingView', 'us', false),

  // India — broker accounts, verified via P&L / tradebook
  TradingPlatform('Zerodha', 'india', false),
  TradingPlatform('Upstox', 'india', false),
  TradingPlatform('Angel One', 'india', false),
  TradingPlatform('Dhan', 'india', false),

  // Crypto — exchange accounts, verified via statement / read-only API export
  TradingPlatform('Binance', 'crypto', false),
  TradingPlatform('Bybit', 'crypto', false),
  TradingPlatform('OKX', 'crypto', false),
  TradingPlatform('Coinbase', 'crypto', false),
];

List<TradingPlatform> platformsFor(String marketId) =>
    kPlatforms.where((p) => p.market == marketId).toList();
