/// A tradable instrument the app can chart, price, and post trades on.
///
/// [yahoo] is the Yahoo Finance symbol used for live quotes (works unauthenticated
/// from a mobile device). [tv] is the TradingView symbol for the embedded chart.
class TradingPair {
  final String symbol; // display, e.g. "XAU/USD"
  final String name; // e.g. "Gold"
  final String category; // Metals | Forex | Crypto | Indices
  final String yahoo; // Yahoo Finance symbol
  final String tv; // TradingView symbol
  const TradingPair(this.symbol, this.name, this.category, this.yahoo, this.tv);
}

const List<TradingPair> kPairs = [
  // Metals
  TradingPair('XAU/USD', 'Gold', 'Metals', 'XAUUSD=X', 'OANDA:XAUUSD'),
  TradingPair('XAG/USD', 'Silver', 'Metals', 'XAGUSD=X', 'OANDA:XAGUSD'),
  // Forex majors
  TradingPair('EUR/USD', 'Euro / Dollar', 'Forex', 'EURUSD=X', 'FX:EURUSD'),
  TradingPair('GBP/USD', 'Pound / Dollar', 'Forex', 'GBPUSD=X', 'FX:GBPUSD'),
  TradingPair('USD/JPY', 'Dollar / Yen', 'Forex', 'JPY=X', 'FX:USDJPY'),
  TradingPair('USD/CHF', 'Dollar / Franc', 'Forex', 'CHF=X', 'FX:USDCHF'),
  TradingPair('AUD/USD', 'Aussie / Dollar', 'Forex', 'AUDUSD=X', 'FX:AUDUSD'),
  TradingPair('USD/CAD', 'Dollar / Loonie', 'Forex', 'CAD=X', 'FX:USDCAD'),
  TradingPair('NZD/USD', 'Kiwi / Dollar', 'Forex', 'NZDUSD=X', 'FX:NZDUSD'),
  TradingPair('EUR/GBP', 'Euro / Pound', 'Forex', 'EURGBP=X', 'FX:EURGBP'),
  TradingPair('EUR/JPY', 'Euro / Yen', 'Forex', 'EURJPY=X', 'FX:EURJPY'),
  TradingPair('GBP/JPY', 'Pound / Yen', 'Forex', 'GBPJPY=X', 'FX:GBPJPY'),
  // Crypto
  TradingPair('BTC/USD', 'Bitcoin', 'Crypto', 'BTC-USD', 'BINANCE:BTCUSDT'),
  TradingPair('ETH/USD', 'Ethereum', 'Crypto', 'ETH-USD', 'BINANCE:ETHUSDT'),
  TradingPair('SOL/USD', 'Solana', 'Crypto', 'SOL-USD', 'BINANCE:SOLUSDT'),
  TradingPair('XRP/USD', 'XRP', 'Crypto', 'XRP-USD', 'BINANCE:XRPUSDT'),
  TradingPair('BNB/USD', 'BNB', 'Crypto', 'BNB-USD', 'BINANCE:BNBUSDT'),
  TradingPair('DOGE/USD', 'Dogecoin', 'Crypto', 'DOGE-USD', 'BINANCE:DOGEUSDT'),
  TradingPair('ADA/USD', 'Cardano', 'Crypto', 'ADA-USD', 'BINANCE:ADAUSDT'),
  TradingPair('AVAX/USD', 'Avalanche', 'Crypto', 'AVAX-USD', 'BINANCE:AVAXUSDT'),
  TradingPair('LINK/USD', 'Chainlink', 'Crypto', 'LINK-USD', 'BINANCE:LINKUSDT'),
  // Indices
  TradingPair('US30', 'Dow Jones', 'Indices', '^DJI', 'OANDA:US30USD'),
  TradingPair('NAS100', 'Nasdaq 100', 'Indices', '^NDX', 'OANDA:NAS100USD'),
  TradingPair('US500', 'S&P 500', 'Indices', '^GSPC', 'OANDA:SPX500USD'),
  TradingPair('GER40', 'DAX 40', 'Indices', '^GDAXI', 'OANDA:DE30EUR'),
  TradingPair('UK100', 'FTSE 100', 'Indices', '^FTSE', 'OANDA:UK100GBP'),
  TradingPair('JP225', 'Nikkei 225', 'Indices', '^N225', 'OANDA:JP225USD'),
  // Commodities
  TradingPair('WTI', 'Crude Oil (WTI)', 'Commodities', 'CL=F', 'TVC:USOIL'),
  TradingPair('BRENT', 'Brent Crude', 'Commodities', 'BZ=F', 'TVC:UKOIL'),
  TradingPair('NATGAS', 'Natural Gas', 'Commodities', 'NG=F', 'TVC:NATGAS'),
  TradingPair('COPPER', 'Copper', 'Commodities', 'HG=F', 'TVC:COPPER'),
  // Stocks
  TradingPair('AAPL', 'Apple', 'Stocks', 'AAPL', 'NASDAQ:AAPL'),
  TradingPair('TSLA', 'Tesla', 'Stocks', 'TSLA', 'NASDAQ:TSLA'),
  TradingPair('NVDA', 'NVIDIA', 'Stocks', 'NVDA', 'NASDAQ:NVDA'),
  TradingPair('MSFT', 'Microsoft', 'Stocks', 'MSFT', 'NASDAQ:MSFT'),
  TradingPair('AMZN', 'Amazon', 'Stocks', 'AMZN', 'NASDAQ:AMZN'),
  TradingPair('META', 'Meta', 'Stocks', 'META', 'NASDAQ:META'),
];

const List<String> kPairCategories = ['Metals', 'Forex', 'Crypto', 'Indices', 'Commodities', 'Stocks'];

/// Finds a known pair by its display symbol (case-insensitive), or null.
TradingPair? pairBySymbol(String symbol) {
  final s = symbol.trim().toUpperCase();
  for (final p in kPairs) {
    if (p.symbol.toUpperCase() == s) return p;
  }
  return null;
}

/// Builds a best-effort [TradingPair] for a custom user-entered symbol so charts
/// and quotes still work. Assumes a Yahoo FX-style symbol for X/USD forex.
TradingPair customPair(String symbol) {
  final s = symbol.trim().toUpperCase();
  final known = pairBySymbol(s);
  if (known != null) return known;
  // Heuristics: "AAA/BBB" forex → "AAABBB=X"; crypto "XXX/USD" → "XXX-USD".
  final parts = s.split(RegExp(r'[\/\-\s]'));
  String yahoo = s;
  String tv = s.replaceAll('/', '');
  if (parts.length == 2) {
    final a = parts[0], b = parts[1];
    yahoo = '$a$b=X';
    tv = 'FX:$a$b';
  }
  return TradingPair(s, 'Custom', 'Custom', yahoo, tv);
}
