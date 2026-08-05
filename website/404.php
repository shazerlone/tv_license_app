<?php
http_response_code(404);
$page  = '';
$title = 'Page not found — LXE Global';
$desc  = 'The page you are looking for could not be found.';
require __DIR__ . '/includes/header.php';
?>
<section class="page-hero">
  <div class="container center">
    <span class="eyebrow">404</span>
    <h1>We couldn't find that page.</h1>
    <p style="margin:14px auto 26px;max-width:46ch">The link may be broken or the page may have moved. Let's get you back on track.</p>
    <a class="btn btn-primary" href="index.php">Back to home →</a>
  </div>
</section>
<?php require __DIR__ . '/includes/footer.php'; ?>
