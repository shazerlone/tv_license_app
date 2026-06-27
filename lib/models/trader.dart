class Trader {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final bool isVerified;
  final bool isLive;
  final double returnPercent;
  final int returnDays;
  final int followers;
  final double aum;
  final List<String> tags;
  final String? bio;
  final double winRate; // 0..100
  final double maxDrawdown; // percent, positive number
  final int copiers;
  final int totalTrades;
  final String category; // Forex, Crypto, Indices, Stocks

  const Trader({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.isVerified = false,
    this.isLive = false,
    required this.returnPercent,
    this.returnDays = 30,
    required this.followers,
    this.aum = 0,
    this.tags = const [],
    this.bio,
    this.winRate = 0,
    this.maxDrawdown = 0,
    this.copiers = 0,
    this.totalTrades = 0,
    this.category = 'Forex',
  });

  String get formattedFollowers {
    if (followers >= 1000) return '${(followers / 1000).toStringAsFixed(1)}K';
    return followers.toString();
  }

  String get formattedCopiers {
    if (copiers >= 1000) return '${(copiers / 1000).toStringAsFixed(1)}K';
    return copiers.toString();
  }

  String get formattedAum {
    if (aum >= 1000000) return '\$${(aum / 1000000).toStringAsFixed(1)}M';
    if (aum >= 1000) return '\$${(aum / 1000).toStringAsFixed(0)}K';
    return '\$${aum.toStringAsFixed(0)}';
  }

  String get formattedReturn {
    final sign = returnPercent >= 0 ? '+' : '';
    return '$sign${returnPercent.toStringAsFixed(2)}%';
  }

  String get riskLabel {
    if (maxDrawdown <= 8) return 'Low';
    if (maxDrawdown <= 18) return 'Medium';
    return 'High';
  }
}

final List<Trader> mockTraders = [
  Trader(
    id: '1', name: 'Marcus Sterling', username: 'marcussterling',
    isVerified: true, isLive: true, returnPercent: 18.45, followers: 12400, aum: 2300000,
    tags: ['Price Action', 'EUR/USD', 'XAU/USD'], bio: 'Full-time trader focusing on price action and market structure. Teaching what works.',
    winRate: 72, maxDrawdown: 9.2, copiers: 1840, totalTrades: 612, category: 'Forex',
  ),
  Trader(
    id: '2', name: 'Jade Capital', username: 'jadecapital',
    isVerified: true, isLive: false, returnPercent: 24.32, followers: 9800, aum: 1800000,
    tags: ['Scalping', 'BTC/USD'], bio: 'Systematic scalping strategies with consistent results.',
    winRate: 68, maxDrawdown: 14.0, copiers: 1320, totalTrades: 2100, category: 'Crypto',
  ),
  Trader(
    id: '3', name: 'TradeWithMike', username: 'tradewithmike',
    isVerified: true, isLive: true, returnPercent: 15.23, followers: 7600, aum: 950000,
    tags: ['Swing', 'US500'], bio: 'Swing trading indices and forex with clear setups.',
    winRate: 64, maxDrawdown: 11.5, copiers: 880, totalTrades: 410, category: 'Indices',
  ),
  Trader(
    id: '4', name: 'Luna Markets', username: 'lunamarkets',
    isVerified: false, isLive: false, returnPercent: 11.72, followers: 6100, aum: 720000,
    tags: ['Crypto', 'ETH/USD'], bio: 'Crypto and DeFi specialist with a long-term view.',
    winRate: 59, maxDrawdown: 22.0, copiers: 540, totalTrades: 330, category: 'Crypto',
  ),
  Trader(
    id: '5', name: 'Forex Ninja', username: 'forexninja',
    isVerified: true, isLive: false, returnPercent: -9.85, followers: 5400, aum: 430000,
    tags: ['Forex', 'News Trading'], bio: 'High-frequency forex trading around news events.',
    winRate: 51, maxDrawdown: 28.0, copiers: 210, totalTrades: 1500, category: 'Forex',
  ),
  Trader(
    id: '6', name: 'Aria Chen', username: 'ariachen',
    isVerified: true, isLive: true, returnPercent: 31.08, followers: 21300, aum: 4100000,
    tags: ['Indices', 'NAS100', 'Gold'], bio: 'Macro-driven swing trader. Risk first, profit second.',
    winRate: 70, maxDrawdown: 12.4, copiers: 3120, totalTrades: 520, category: 'Indices',
  ),
  Trader(
    id: '7', name: 'Diego Alvarez', username: 'diegofx',
    isVerified: true, isLive: false, returnPercent: 19.62, followers: 8700, aum: 1250000,
    tags: ['GBP/JPY', 'Breakouts'], bio: 'Breakout trader, London session specialist.',
    winRate: 66, maxDrawdown: 10.1, copiers: 990, totalTrades: 740, category: 'Forex',
  ),
  Trader(
    id: '8', name: 'Sophie Bauer', username: 'sophietrades',
    isVerified: false, isLive: false, returnPercent: 8.94, followers: 3200, aum: 280000,
    tags: ['Stocks', 'Tech'], bio: 'US equities and options. Patient, data-driven entries.',
    winRate: 61, maxDrawdown: 9.8, copiers: 180, totalTrades: 260, category: 'Stocks',
  ),
  Trader(
    id: '9', name: 'Kenji Watanabe', username: 'kenjiw',
    isVerified: true, isLive: true, returnPercent: 27.41, followers: 14900, aum: 2900000,
    tags: ['USD/JPY', 'Scalping'], bio: 'Asian session scalper. Tight risk, high frequency.',
    winRate: 69, maxDrawdown: 13.7, copiers: 2010, totalTrades: 3400, category: 'Forex',
  ),
  Trader(
    id: '10', name: 'Nova Quant', username: 'novaquant',
    isVerified: true, isLive: false, returnPercent: 22.15, followers: 11200, aum: 3300000,
    tags: ['Algo', 'BTC/USD', 'ETH/USD'], bio: 'Quantitative crypto strategies, fully systematic.',
    winRate: 74, maxDrawdown: 16.2, copiers: 1670, totalTrades: 8900, category: 'Crypto',
  ),
];
