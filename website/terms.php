<?php
$page  = 'legal';
$title = 'Terms of Service — LXE Global';
$desc  = 'The terms that govern use of the LXEGLOBAL LLC website and services.';
require __DIR__ . '/includes/header.php';
$company = require __DIR__ . '/includes/company.php';
?>
<section class="page-hero">
  <div class="container">
    <span class="eyebrow">Legal</span>
    <h1>Terms of Service</h1>
    <p>Last updated <?= date('F Y') ?>. These terms govern your use of this website, operated by <?= htmlspecialchars($company['legal_name']) ?>.</p>
  </div>
</section>
<section class="block">
  <div class="container" style="max-width:780px">
    <h3>Use of this website</h3>
    <p>This website is provided for general information about <?= htmlspecialchars($company['legal_name']) ?> and its services. By using it, you agree to use it lawfully and not to misuse or attempt to disrupt it.</p>

    <h3>No financial advice</h3>
    <p>We build technology for trading and financial analysis. Nothing on this website constitutes financial, investment or trading advice, and no content here should be relied upon as a recommendation to buy, sell or hold any instrument. Trading involves risk.</p>

    <h3>Services</h3>
    <p>Any consultancy or development work we perform for you is governed by a separate written agreement. The information on this website does not itself create a contract or engagement.</p>

    <h3>Intellectual property</h3>
    <p>The content, branding and design of this website are owned by <?= htmlspecialchars($company['legal_name']) ?> unless otherwise stated, and may not be copied or reused without permission.</p>

    <h3>Limitation of liability</h3>
    <p>This website is provided "as is". To the fullest extent permitted by law, we are not liable for any loss arising from your reliance on information presented here.</p>

    <h3>Contact</h3>
    <p>Questions about these terms? Email <a href="mailto:<?= htmlspecialchars($company['email']) ?>"><?= htmlspecialchars($company['email']) ?></a>.</p>
  </div>
</section>
<?php require __DIR__ . '/includes/footer.php'; ?>
