<?php
$company = require __DIR__ . '/company.php';
$page    = $page ?? 'home';
$title   = $title ?? $company['brand_name'];
$desc    = $desc ?? $company['intro'];

function nav_active($current, $name) {
    return $current === $name ? ' aria-current="page"' : '';
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title><?= htmlspecialchars($title) ?></title>
<meta name="description" content="<?= htmlspecialchars($desc) ?>">
<meta name="theme-color" content="#ffffff">
<meta property="og:title" content="<?= htmlspecialchars($title) ?>">
<meta property="og:description" content="<?= htmlspecialchars($desc) ?>">
<meta property="og:type" content="website">
<link rel="icon" type="image/svg+xml" href="assets/img/favicon.svg">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,400;9..144,500;9..144,600&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="assets/css/style.css">
</head>
<body>
<header class="site-header" id="top">
  <div class="container header-inner">
    <a class="brand" href="index.php" aria-label="<?= htmlspecialchars($company['brand_name']) ?> home">
      <img src="assets/img/logo.svg" alt="<?= htmlspecialchars($company['brand_name']) ?>" height="34">
    </a>
    <nav class="main-nav" aria-label="Primary">
      <button class="nav-toggle" aria-expanded="false" aria-controls="nav-links" aria-label="Toggle menu">
        <span></span><span></span><span></span>
      </button>
      <ul id="nav-links" class="nav-links">
        <li><a href="index.php"<?= nav_active($page,'home') ?>>Home</a></li>
        <li><a href="services.php"<?= nav_active($page,'services') ?>>Services</a></li>
        <li><a href="about.php"<?= nav_active($page,'about') ?>>About</a></li>
        <li><a href="contact.php"<?= nav_active($page,'contact') ?>>Contact</a></li>
        <li><a class="btn btn-nav" href="contact.php">Get in touch</a></li>
      </ul>
    </nav>
  </div>
</header>
<main>
