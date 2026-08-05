<?php
$page  = 'home';
$title = 'LXE Global — Trading technology & financial consultancy';
$desc  = 'LXEGLOBAL LLC builds analysis platforms, research systems, live market streaming and trading apps for financial firms and independent traders.';
require __DIR__ . '/includes/header.php';
?>

<!-- HERO -->
<section class="hero">
  <div class="container hero-grid">
    <div class="reveal in">
      <span class="eyebrow">Financial technology consultancy</span>
      <h1>Technology that moves at the speed of the <span class="accent">market.</span></h1>
      <p class="hero-lead">We design and engineer the systems behind modern trading — analysis platforms, research engines, live market streaming and mobile apps — end to end.</p>
      <div class="hero-cta">
        <a class="btn btn-primary" href="contact.php">Start a project →</a>
        <a class="btn btn-ghost" href="services.php">Explore services</a>
      </div>
      <div class="hero-stats">
        <div class="stat"><b>24/7</b><span>Live market data pipelines</span></div>
        <div class="stat"><b>3</b><span>Continents supported</span></div>
        <div class="stat"><b>End&#8209;to&#8209;end</b><span>Strategy to shipped app</span></div>
      </div>
    </div>

    <div class="hero-visual reveal in">
      <div class="glass-card">
        <div class="gc-head">
          <div style="display:flex;align-items:center;gap:9px">
            <span class="dot"></span><span class="gc-title">Market Analysis Console</span>
          </div>
          <span class="gc-badge">Live</span>
        </div>
        <div class="chart">
          <svg viewBox="0 0 320 120" preserveAspectRatio="none" aria-hidden="true">
            <defs>
              <linearGradient id="g" x1="0" x2="0" y1="0" y2="1">
                <stop offset="0" stop-color="#34d399" stop-opacity=".28"/>
                <stop offset="1" stop-color="#34d399" stop-opacity="0"/>
              </linearGradient>
            </defs>
            <path d="M0,92 L36,80 L72,86 L108,60 L144,68 L180,40 L216,52 L252,26 L288,34 L320,14"
                  fill="none" stroke="#16a34a" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
            <path d="M0,92 L36,80 L72,86 L108,60 L144,68 L180,40 L216,52 L252,26 L288,34 L320,14 L320,120 L0,120 Z" fill="url(#g)"/>
          </svg>
        </div>
        <div class="gc-rows">
          <div class="gc-row"><span>Signal accuracy · 30d</span><span class="up">▲ 4.2%</span></div>
          <div class="gc-row"><span>Data latency</span><span class="up">18 ms</span></div>
          <div class="gc-row"><span>Streams monitored</span><span>1,240</span></div>
        </div>
      </div>
    </div>
  </div>
</section>

<!-- STRIP -->
<div class="strip">
  <div class="container strip-inner">
    <span><b>What we build</b></span>
    <span>Analysis systems</span><span>·</span>
    <span>Research engines</span><span>·</span>
    <span>Live streaming software</span><span>·</span>
    <span>Mobile &amp; web apps</span><span>·</span>
    <span>Data infrastructure</span>
  </div>
</div>

<!-- SERVICES -->
<section class="block">
  <div class="container">
    <div class="section-head reveal">
      <span class="eyebrow">Services</span>
      <h2>A full-fledged consultancy for trading technology.</h2>
      <p>From the first line of a strategy to a polished app in your traders' hands, we handle the entire stack.</p>
    </div>
    <div class="cards">
      <?php
      $svc = [
        ['Analysis systems','Real-time and historical market analysis platforms — indicators, signal engines and dashboards built for speed and clarity.','<path d="M3 3v18h18"/><path d="M7 14l4-4 3 3 5-6"/>'],
        ['Research systems','Backtesting, screening and quantitative research tooling that turns raw market data into decisions you can trust.','<path d="M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14z"/><path d="M21 21l-4.3-4.3"/>'],
        ['Live streaming software','Low-latency market and video streaming infrastructure to broadcast prices, sessions and commentary in real time.','<rect x="2" y="7" width="15" height="10" rx="2"/><path d="M22 8l-5 4 5 4V8z"/>'],
        ['Mobile applications','Native and cross-platform trading apps — fast, secure and store-ready, from onboarding to live order flow.','<rect x="7" y="2" width="10" height="20" rx="2"/><path d="M11 18h2"/>'],
        ['Data infrastructure','Ingestion, normalization and delivery of market feeds at scale, with the reliability trading operations demand.','<ellipse cx="12" cy="5" rx="8" ry="3"/><path d="M4 5v6c0 1.7 3.6 3 8 3s8-1.3 8-3V5"/><path d="M4 11v6c0 1.7 3.6 3 8 3s8-1.3 8-3v-6"/>'],
        ['Advisory & consultancy','Architecture reviews, compliance-aware design and technology strategy for financial firms and independent traders.','<path d="M12 2l3 7h7l-5.5 4.5L18 21l-6-4-6 4 1.5-7.5L2 9h7z"/>'],
      ];
      foreach ($svc as $s): ?>
      <div class="card reveal">
        <div class="ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><?= $s[2] ?></svg></div>
        <h3><?= $s[0] ?></h3>
        <p><?= $s[1] ?></p>
      </div>
      <?php endforeach; ?>
    </div>
  </div>
</section>

<!-- FEATURE SPLIT -->
<section class="block bg-soft">
  <div class="container split">
    <div class="reveal">
      <span class="eyebrow">Why LXE Global</span>
      <h2>Built by people who understand both markets and code.</h2>
      <p>Trading technology fails when engineering and market knowledge live in separate rooms. We keep them together — so what we ship reflects how markets actually behave.</p>
      <ul class="checklist">
        <?php foreach ([
          'End-to-end delivery — strategy, data, back end, and the app your users touch.',
          'Latency-first engineering for systems where milliseconds matter.',
          'Security and reliability treated as requirements, not afterthoughts.',
          'A single accountable partner across Dubai, India and the United States.',
        ] as $c): ?>
        <li><span class="tick"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l5 5L20 6"/></svg></span><span><?= $c ?></span></li>
        <?php endforeach; ?>
      </ul>
    </div>
    <div class="split-media reveal">
      <div class="band" style="margin:0;padding:40px 34px">
        <div class="stats-row">
          <div><b>18ms</b><span>Median feed latency</span></div>
          <div><b>99.9%</b><span>Pipeline uptime target</span></div>
          <div><b>10+</b><span>Market data sources</span></div>
          <div><b>1</b><span>Accountable partner</span></div>
        </div>
      </div>
    </div>
  </div>
</section>

<!-- PROCESS -->
<section class="block">
  <div class="container">
    <div class="section-head center reveal">
      <span class="eyebrow">How we work</span>
      <h2>From idea to production, in four clear stages.</h2>
    </div>
    <div class="steps">
      <?php
      $steps=[
        ['01','Discover','We map your goals, markets and data — and define what success looks like.'],
        ['02','Design','Architecture, data flow and interface designed for speed, security and scale.'],
        ['03','Build','Iterative engineering with working software you can review at every step.'],
        ['04','Launch','Deployment, monitoring and support — plus a roadmap for what comes next.'],
      ];
      foreach($steps as $st): ?>
      <div class="step reveal"><span class="n"><?= $st[0] ?></span><h3><?= $st[1] ?></h3><p><?= $st[2] ?></p></div>
      <?php endforeach; ?>
    </div>
  </div>
</section>

<!-- CTA -->
<section class="block">
  <div class="container">
    <div class="cta reveal">
      <span class="eyebrow">Let's build</span>
      <h2>Have a trading platform in mind?</h2>
      <p>Tell us what you're building. We'll help you turn a market idea into technology your traders rely on.</p>
      <a class="btn btn-primary" href="contact.php">Contact our team →</a>
    </div>
  </div>
</section>

<?php require __DIR__ . '/includes/footer.php'; ?>
