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
  });

  String get formattedFollowers {
    if (followers >= 1000) return '${(followers / 1000).toStringAsFixed(1)}K';
    return followers.toString();
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
}

final List<Trader> mockTraders = [
  Trader(
    id: '1',
    name: 'Marcus Sterling',
    username: 'marcussterling',
    isVerified: true,
    isLive: true,
    returnPercent: 18.45,
    returnDays: 30,
    followers: 12400,
    aum: 2300000,
    tags: ['Price Action', 'EUR/USD', 'Gold'],
    bio: 'Full-time trader focusing on price action and market structure. Teaching what works.',
  ),
  Trader(
    id: '2',
    name: 'Jade Capital',
    username: 'jadecapital',
    isVerified: true,
    isLive: false,
    returnPercent: 24.32,
    returnDays: 30,
    followers: 9800,
    aum: 1800000,
    tags: ['Scalping', 'Crypto'],
    bio: 'Systematic scalping strategies with consistent results.',
  ),
  Trader(
    id: '3',
    name: 'TradeWithMike',
    username: 'tradewithmike',
    isVerified: true,
    isLive: true,
    returnPercent: 15.23,
    returnDays: 30,
    followers: 7600,
    aum: 950000,
    tags: ['Swing', 'Indices'],
    bio: 'Swing trading indices and forex with clear setups.',
  ),
  Trader(
    id: '4',
    name: 'Luna Markets',
    username: 'lunamarkets',
    isVerified: false,
    isLive: false,
    returnPercent: 11.72,
    returnDays: 30,
    followers: 6100,
    aum: 720000,
    tags: ['Crypto', 'DeFi'],
    bio: 'Crypto and DeFi specialist with a long-term view.',
  ),
  Trader(
    id: '5',
    name: 'ForesNinja',
    username: 'foresninja',
    isVerified: true,
    isLive: false,
    returnPercent: -9.85,
    returnDays: 30,
    followers: 5400,
    aum: 430000,
    tags: ['Forex', 'News Trading'],
    bio: 'High-frequency forex trading around news events.',
  ),
];
