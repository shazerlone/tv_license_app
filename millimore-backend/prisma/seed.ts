/**
 * Seed / mock data so the app + admin can integrate immediately.
 * Milestone 1: users (admin, demo trader/creator, followers) + a pending
 * creator application for the admin approval queue (milestone 2).
 *
 * Run: npm run db:seed   (idempotent — upserts by stable ids)
 */
import { PrismaClient, Role, CreatorStatus } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const password = await bcrypt.hash('password', 10);

  // Admin — the only way into the admin dashboard.
  await prisma.user.upsert({
    where: { id: 'u_admin' },
    update: {},
    create: {
      id: 'u_admin',
      name: 'Millimore Admin',
      username: 'admin',
      email: 'admin@millimore.app',
      passwordHash: password,
      role: Role.admin,
      creatorStatus: CreatorStatus.none,
      residenceIso: 'AE',
      residenceCountry: 'United Arab Emirates',
    },
  });

  // Demo trader/creator — matches the app's demo login `trader@millimore.app`.
  await prisma.user.upsert({
    where: { id: 'u_marcus' },
    update: {},
    create: {
      id: 'u_marcus',
      name: 'Marcus Sterling',
      username: 'marcussterling',
      email: 'trader@millimore.app',
      phone: '+971 50 000 0001',
      passwordHash: password,
      role: Role.creator,
      creatorStatus: CreatorStatus.approved,
      residenceIso: 'AE',
      residenceCountry: 'United Arab Emirates',
      market: 'Forex',
      platform: 'MetaTrader 5',
    },
  });

  // A follower.
  await prisma.user.upsert({
    where: { id: 'u_priya' },
    update: {},
    create: {
      id: 'u_priya',
      name: 'Priya Sharma',
      username: 'priyatrades',
      email: 'priya@millimore.app',
      phone: '+91 90000 00001',
      passwordHash: password,
      role: Role.follower,
      creatorStatus: CreatorStatus.none,
      residenceIso: 'IN',
      residenceCountry: 'India',
      experience: 'beginner',
      interests: ['Forex', 'Gold'],
    },
  });

  // A creator awaiting approval — populates the admin verification queue.
  await prisma.user.upsert({
    where: { id: 'u_aisha' },
    update: {},
    create: {
      id: 'u_aisha',
      name: 'Aisha Khan',
      username: 'aishafx',
      phone: '+92 300 0000001',
      role: Role.creator,
      creatorStatus: CreatorStatus.pending,
      residenceIso: 'PK',
      residenceCountry: 'Pakistan',
      market: 'Forex',
      platform: 'MetaTrader 4',
    },
  });
  await prisma.creatorApplication.upsert({
    where: { id: 'capp_aisha' },
    update: {},
    create: {
      id: 'capp_aisha',
      userId: 'u_aisha',
      status: CreatorStatus.pending,
      market: 'Forex',
      platform: 'MetaTrader 4',
      verificationPlatform: 'MetaTrader 4',
      server: 'Exness-Real',
      account: '10023498',
      statementUrl: 'https://storage.millimore.app/statements/aisha.pdf',
    },
  });

  // ── Brokers (country-gated list for GET /brokers?country=) ──────────
  const brokers = [
    {
      id: 'century',
      name: 'Century',
      domain: 'centuryfinancial.ae',
      logoUrl: 'https://logo.clearbit.com/centuryfinancial.ae',
      recommended: true,
      countries: ['AE', 'SA', 'IN'],
      sortOrder: 1,
    },
    {
      id: 'xm',
      name: 'XM',
      domain: 'xm.com',
      logoUrl: 'https://logo.clearbit.com/xm.com',
      recommended: true,
      countries: [], // global
      sortOrder: 2,
    },
    {
      id: 'exness',
      name: 'Exness',
      domain: 'exness.com',
      logoUrl: 'https://logo.clearbit.com/exness.com',
      recommended: false,
      countries: [], // global
      sortOrder: 3,
    },
    {
      id: 'icmarkets',
      name: 'IC Markets',
      domain: 'icmarkets.com',
      logoUrl: 'https://logo.clearbit.com/icmarkets.com',
      recommended: false,
      countries: ['AU', 'IN', 'ZA', 'MY'],
      sortOrder: 4,
    },
    {
      id: 'pepperstone',
      name: 'Pepperstone',
      domain: 'pepperstone.com',
      logoUrl: 'https://logo.clearbit.com/pepperstone.com',
      recommended: false,
      countries: ['AU', 'GB', 'AE'],
      sortOrder: 5,
    },
  ];
  for (const b of brokers) {
    await prisma.broker.upsert({ where: { id: b.id }, update: b, create: b });
  }

  // ── A demo connected trading account for the follower ───────────────
  await prisma.tradingAccount.upsert({
    where: { id: 'acc_demo' },
    update: {},
    create: {
      id: 'acc_demo',
      userId: 'u_priya',
      brokerId: 'xm',
      brokerName: 'XM',
      accountNumber: '50231487',
      server: 'XM-Live3',
      currency: 'USD',
      balance: 5000,
      status: 'connected',
    },
  });

  // ── Traders (public profiles) ──────────────────────────────────────
  const traders = [
    {
      id: 't_marcus',
      userId: 'u_marcus',
      name: 'Marcus Sterling',
      username: 'marcussterling',
      isVerified: true,
      isLive: true,
      returnPercent: 18.45,
      returnDays: 30,
      followers: 12400,
      copiers: 1840,
      aum: 2300000,
      winRate: 72,
      maxDrawdown: 9.2,
      totalTrades: 612,
      category: 'Forex',
      tags: ['Price Action', 'EUR/USD', 'Swing'],
      bio: 'Full-time FX trader. 8 years on the majors. Risk first, always.',
    },
    {
      id: 't_elena',
      name: 'Elena Voss',
      username: 'elenavoss',
      isVerified: true,
      isLive: false,
      returnPercent: 24.1,
      returnDays: 30,
      followers: 8800,
      copiers: 1210,
      aum: 1450000,
      winRate: 68,
      maxDrawdown: 12.4,
      totalTrades: 430,
      category: 'Crypto',
      tags: ['BTC', 'Momentum'],
      bio: 'Crypto momentum & breakout trader. Data over emotion.',
    },
    {
      id: 't_kenji',
      name: 'Kenji Nakamura',
      username: 'kenjifx',
      isVerified: true,
      isLive: true,
      returnPercent: 11.9,
      returnDays: 30,
      followers: 15600,
      copiers: 2600,
      aum: 3900000,
      winRate: 75,
      maxDrawdown: 6.1,
      totalTrades: 980,
      category: 'Gold',
      tags: ['XAU/USD', 'Scalping', 'London'],
      bio: 'Gold scalper. London + NY sessions. Consistency compounds.',
    },
    {
      id: 't_sofia',
      name: 'Sofia Marchetti',
      username: 'sofiam',
      isVerified: false,
      isLive: false,
      returnPercent: 31.7,
      returnDays: 30,
      followers: 4200,
      copiers: 540,
      aum: 620000,
      winRate: 61,
      maxDrawdown: 18.9,
      totalTrades: 210,
      category: 'Indices',
      tags: ['US30', 'NAS100', 'News'],
      bio: 'Index day-trader. High conviction, high volatility.',
    },
  ];
  for (const t of traders) {
    await prisma.trader.upsert({ where: { id: t.id }, update: t, create: t });
  }

  // ── Posts ──────────────────────────────────────────────────────────
  const posts = [
    {
      id: 'p_1',
      traderId: 't_marcus',
      type: 'analysis' as const,
      content:
        'EUR/USD reclaimed 1.0850 and is holding above the London high. I like longs on a retest of 1.0840 with stops under 1.0810.',
      pair: 'EUR/USD',
      title: 'EUR/USD — reclaim and go',
      points: ['Above London high', 'Retest 1.0840 for entry', 'Invalidation < 1.0810'],
    },
    {
      id: 'p_2',
      traderId: 't_marcus',
      type: 'trade' as const,
      content: 'Long EUR/USD filled at 1.0842. SL 1.0808, TP1 1.0910.',
      pair: 'EUR/USD',
      points: [],
    },
    {
      id: 'p_3',
      traderId: 't_kenji',
      type: 'lesson' as const,
      content:
        'Scalping gold is about session timing. 90% of my trades happen in the first two hours of London. Outside that window, spreads eat you alive.',
      pair: 'XAU/USD',
      title: 'Why session timing beats indicators',
      points: ['Trade the London open', 'Respect the spread', 'Fewer, better setups'],
    },
    {
      id: 'p_4',
      traderId: 't_elena',
      type: 'analysis' as const,
      content:
        'BTC is coiling under 68k. A daily close above flips the structure bullish; until then I stay patient.',
      pair: 'BTC/USD',
      title: 'BTC — patience under resistance',
      points: ['Watching 68k daily close', 'No FOMO longs'],
    },
    {
      id: 'p_5',
      traderId: 't_sofia',
      type: 'trade' as const,
      content: 'Short US30 into the news spike. Quick scalp, booked +140 pts.',
      pair: 'US30',
      points: [],
    },
  ];
  for (const p of posts) {
    await prisma.post.upsert({ where: { id: p.id }, update: p, create: p });
  }

  // ── Comments ───────────────────────────────────────────────────────
  const comments = [
    { id: 'c_1', postId: 'p_1', userId: 'u_priya', text: 'Clean setup, thanks Marcus!' },
    { id: 'c_2', postId: 'p_1', userId: 'u_aisha', text: 'What timeframe are you watching?' },
    { id: 'c_3', postId: 'p_3', userId: 'u_priya', text: 'This clicked for me. Session timing it is.' },
  ];
  for (const c of comments) {
    await prisma.comment.upsert({ where: { id: c.id }, update: c, create: c });
  }

  // ── Social graph (priya follows marcus + kenji, likes/saves a post) ──
  for (const traderId of ['t_marcus', 't_kenji']) {
    await prisma.subscription.upsert({
      where: { userId_traderId: { userId: 'u_priya', traderId } },
      update: {},
      create: { userId: 'u_priya', traderId, notify: traderId === 't_marcus' },
    });
  }
  await prisma.postLike.upsert({
    where: { userId_postId: { userId: 'u_priya', postId: 'p_1' } },
    update: {},
    create: { userId: 'u_priya', postId: 'p_1' },
  });
  await prisma.postSave.upsert({
    where: { userId_postId: { userId: 'u_priya', postId: 'p_3' } },
    update: {},
    create: { userId: 'u_priya', postId: 'p_3' },
  });

  // ── Backfill: every approved creator must have a public Trader profile ──
  // (so approved-but-inactive creators show up in GET /traders / search).
  const approvedCreators = await prisma.user.findMany({
    where: { role: 'creator', creatorStatus: 'approved', trader: { is: null } },
  });
  for (const u of approvedCreators) {
    await prisma.trader.create({
      data: {
        id: `t_${u.id.replace(/^u_/, '')}`,
        userId: u.id,
        name: u.name,
        username: u.username,
        photoUrl: u.photoUrl,
        isVerified: true,
        category: u.market ?? 'Forex',
      },
    });
  }

  // ── Wallets: fund demo users so deposit → copy → settle works end-to-end ──
  const walletSeeds = [
    { userId: 'u_priya', balance: 10000 },
    { userId: 'u_marcus', balance: 2000 },
    { userId: 'u_admin', balance: 0 },
    { userId: 'u_aisha', balance: 0 },
  ];
  for (const w of walletSeeds) {
    await prisma.wallet.upsert({
      where: { userId: w.userId },
      update: { balance: w.balance },
      create: {
        id: `w_${w.userId.replace(/^u_/, '')}`,
        userId: w.userId,
        balance: w.balance,
        currency: 'USD',
      },
    });
  }
  // A confirmed deposit + matching ledger row for Priya (populates /deposits
  // and /wallet/ledger with realistic data).
  await prisma.deposit.upsert({
    where: { id: 'dep_seed_priya' },
    update: {},
    create: {
      id: 'dep_seed_priya',
      userId: 'u_priya',
      amount: 10000,
      currency: 'USD',
      method: 'crypto',
      asset: 'USDT',
      status: 'confirmed',
      confirmedAt: new Date(),
    },
  });
  await prisma.ledgerEntry.upsert({
    where: { id: 'led_seed_priya' },
    update: {},
    create: {
      id: 'led_seed_priya',
      userId: 'u_priya',
      type: 'deposit',
      amount: 10000,
      balanceAfter: 10000,
      currency: 'USD',
      refId: 'dep_seed_priya',
      note: 'Seed deposit',
    },
  });

  // eslint-disable-next-line no-console
  console.log('Seed complete:');
  console.log('  admin@millimore.app  / password   (admin)');
  console.log('  trader@millimore.app / password   (creator, approved)');
  console.log('  priya@millimore.app  / password   (follower)');
  console.log('  1 pending creator application (Aisha Khan) for the approval queue');
  console.log(`  ${brokers.length} brokers + 1 demo trading account (XM ••••1487)`);
  console.log(`  ${traders.length} traders, ${posts.length} posts, ${comments.length} comments`);
  console.log('  priya follows Marcus + Kenji, liked p_1, saved p_3');
}

main()
  .catch((e) => {
    // eslint-disable-next-line no-console
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
