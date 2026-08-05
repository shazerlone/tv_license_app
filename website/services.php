<?php
$page  = 'services';
$title = 'Services — LXE Global';
$desc  = 'Analysis systems, research engines, live streaming software, mobile apps and data infrastructure for trading, delivered end to end by LXEGLOBAL LLC.';
require __DIR__ . '/includes/header.php';
?>

<section class="page-hero">
  <div class="container">
    <span class="eyebrow">Services</span>
    <h1>Everything your trading operation needs to run on.</h1>
    <p>We are a full-fledged financial technology consultancy. Engage us for a single system or your entire stack — the accountability stays with one team.</p>
  </div>
</section>

<section class="block">
  <div class="container">
    <?php
    $blocks = [
      [
        'Analysis systems',
        'Turn market data into insight in real time.',
        'We build analysis platforms that traders actually keep open all day — fast charts, custom indicators, signal engines and alerting that surface what matters the moment it happens.',
        ['Real-time & historical charting','Custom indicators and signal logic','Configurable alerting and watchlists','Dashboards tuned for decision speed'],
      ],
      [
        'Research systems',
        'Test ideas before you risk capital on them.',
        'Backtesting, screening and quantitative research tooling that lets your team validate strategies against clean, normalized data — with results you can reproduce and defend.',
        ['Strategy backtesting engines','Market and instrument screeners','Quantitative research notebooks','Reproducible, auditable results'],
      ],
      [
        'Live streaming software',
        'Broadcast prices, sessions and commentary with near-zero delay.',
        'Low-latency streaming infrastructure for market data and live video alike — so your traders, subscribers or audience see the market as it moves, not seconds behind it.',
        ['Low-latency market data streams','Live video & session broadcasting','Scalable multi-viewer delivery','Recording and replay pipelines'],
      ],
      [
        'Mobile & web applications',
        'Store-ready apps your users trust with real money.',
        'Native and cross-platform applications built for the demands of trading — secure onboarding, live order flow, notifications and a polished interface ready for the App Store and Google Play.',
        ['iOS, Android & web from one codebase','Secure authentication & KYC-ready flows','Real-time quotes and order handling','App Store & Play Store submission support'],
      ],
      [
        'Data infrastructure',
        'The reliable backbone under everything above.',
        'We ingest, normalize and deliver market feeds at scale, with the monitoring and redundancy that trading operations require — so the data your systems depend on is always there.',
        ['Multi-source feed ingestion','Normalization & symbol mapping','High-availability delivery','Monitoring, redundancy & failover'],
      ],
      [
        'Advisory & consultancy',
        'Strategy and architecture from a partner who has built it.',
        'Beyond building, we advise. Architecture reviews, technology strategy and compliance-aware design for financial firms and independent traders who need a second, expert set of eyes.',
        ['Technology & architecture strategy','System and code reviews','Compliance-aware design guidance','Team mentoring and enablement'],
      ],
    ];
    $i=0;
    foreach ($blocks as $b): $rev = ($i%2===1)?' rev':''; $i++; ?>
    <div class="split<?= $rev ?> reveal" style="margin-bottom:72px">
      <div>
        <span class="eyebrow"><?= $b[0] ?></span>
        <h2><?= $b[1] ?></h2>
        <p><?= $b[2] ?></p>
        <ul class="checklist">
          <?php foreach ($b[3] as $c): ?>
          <li><span class="tick"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l5 5L20 6"/></svg></span><span><?= $c ?></span></li>
          <?php endforeach; ?>
        </ul>
      </div>
      <div class="split-media">
        <div style="display:grid;gap:12px">
          <?php foreach ($b[3] as $k=>$c): ?>
          <div class="gc-row" style="background:#fff"><span><?= $c ?></span><span class="up">✓</span></div>
          <?php endforeach; ?>
        </div>
      </div>
    </div>
    <?php endforeach; ?>

    <div class="cta reveal">
      <h2>Not sure where to start?</h2>
      <p>Tell us about your market and your goal. We'll recommend the right first step — and be honest if you don't need everything at once.</p>
      <a class="btn btn-primary" href="contact.php">Talk to us →</a>
    </div>
  </div>
</section>

<?php require __DIR__ . '/includes/footer.php'; ?>
