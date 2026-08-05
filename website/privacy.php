<?php
$page  = 'legal';
$title = 'Privacy Policy — LXE Global';
$desc  = 'How LXEGLOBAL LLC collects, uses and protects your information.';
require __DIR__ . '/includes/header.php';
$company = require __DIR__ . '/includes/company.php';
?>
<section class="page-hero">
  <div class="container">
    <span class="eyebrow">Legal</span>
    <h1>Privacy Policy</h1>
    <p>Last updated <?= date('F Y') ?>. This policy explains how <?= htmlspecialchars($company['legal_name']) ?> handles the information you share with us.</p>
  </div>
</section>
<section class="block">
  <div class="container" style="max-width:780px">
    <h3>Who we are</h3>
    <p><?= htmlspecialchars($company['legal_name']) ?> ("we", "us") is a financial technology consultancy registered in the United States, with its registered office at <?= htmlspecialchars($company['address_line']) ?>, <?= htmlspecialchars($company['address_city']) ?>.</p>

    <h3>Information we collect</h3>
    <p>We only collect the information you choose to give us — such as your name, email address and message when you use our contact form. We do not sell your data or share it with third parties for advertising.</p>

    <h3>How we use it</h3>
    <p>We use the details you provide solely to respond to your enquiry and to communicate with you about the services you have asked about. Enquiry records are kept only as long as needed for that purpose.</p>

    <h3>Data security</h3>
    <p>We take reasonable technical and organizational measures to protect the information you share with us against loss, misuse and unauthorized access.</p>

    <h3>Your choices</h3>
    <p>You may ask us to access, correct or delete the personal information you have provided by emailing <a href="mailto:<?= htmlspecialchars($company['email']) ?>"><?= htmlspecialchars($company['email']) ?></a>. We will respond within a reasonable time.</p>

    <h3>Contact</h3>
    <p>Questions about this policy? Email us at <a href="mailto:<?= htmlspecialchars($company['email']) ?>"><?= htmlspecialchars($company['email']) ?></a>.</p>
  </div>
</section>
<?php require __DIR__ . '/includes/footer.php'; ?>
