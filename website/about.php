<?php
$page  = 'about';
$title = 'About — LXE Global';
$desc  = 'LXEGLOBAL LLC is a U.S.-registered financial technology consultancy building trading systems across Dubai, India and the United States.';
require __DIR__ . '/includes/header.php';
$company = require __DIR__ . '/includes/company.php';
?>

<section class="page-hero">
  <div class="container">
    <span class="eyebrow">About us</span>
    <h1>A financial technology consultancy, built for traders.</h1>
    <p>LXEGLOBAL LLC exists to close the gap between how markets behave and the software people use to trade them.</p>
  </div>
</section>

<section class="block">
  <div class="container" style="max-width:820px">
    <p class="lead-serif reveal">We are a full-fledged consultancy focused entirely on trading technology. Our teams design analysis platforms, research systems, live streaming software and mobile applications — and we take responsibility for the whole journey, from the first conversation to the app in your users' hands.</p>
    <p class="reveal" style="margin-top:26px">Trading software is unforgiving. A slow feed, an unclear chart or an unreliable app costs real money and real trust. That is why we build with a bias toward speed, clarity and reliability — and why we keep market knowledge and engineering in the same room at every stage. The result is technology that reflects how markets actually work, not just how they look on paper.</p>
    <p class="reveal">Registered in the United States and operating across the United Arab Emirates, India and the U.S., we serve financial firms and independent traders who want a single, accountable technology partner rather than a scattered set of vendors.</p>
  </div>
</section>

<section class="block bg-soft">
  <div class="container">
    <div class="section-head center reveal">
      <span class="eyebrow">What we stand for</span>
      <h2>Principles that shape everything we ship.</h2>
    </div>
    <div class="values">
      <?php
      $vals=[
        ['Speed as a feature','In trading, latency is not a detail — it is the product. We engineer for milliseconds because our clients are judged in them.'],
        ['Clarity over clutter','Good trading software gets out of the way. We design interfaces that make the next decision obvious.'],
        ['Reliability by default','Redundancy, monitoring and testing are built in from day one, not bolted on after the first outage.'],
        ['Security first','Financial data and user trust are handled with the seriousness they deserve, at every layer.'],
        ['One accountable partner','You get a single team that owns the outcome — across strategy, data, back end and app.'],
        ['Honest advice','If you don\'t need something, we\'ll tell you. Long-term trust matters more than a bigger invoice.'],
      ];
      foreach($vals as $v): ?>
      <div class="value reveal"><h3><?= $v[0] ?></h3><p><?= $v[1] ?></p></div>
      <?php endforeach; ?>
    </div>
  </div>
</section>

<section class="block">
  <div class="container">
    <div class="band reveal">
      <div class="stats-row">
        <div><b>3</b><span>Countries — UAE · India · USA</span></div>
        <div><b>6</b><span>Core service lines</span></div>
        <div><b>24/7</b><span>Market data operations</span></div>
        <div><b>1</b><span>Team accountable to you</span></div>
      </div>
    </div>
  </div>
</section>

<section class="block">
  <div class="container">
    <div class="cta reveal">
      <h2>Let's build something the market can't ignore.</h2>
      <p>Whether you're a firm modernizing your stack or a trader with an idea, we'd like to hear about it.</p>
      <a class="btn btn-primary" href="contact.php">Get in touch →</a>
    </div>
  </div>
</section>

<?php require __DIR__ . '/includes/footer.php'; ?>
