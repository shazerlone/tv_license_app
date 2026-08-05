</main>
<footer class="site-footer">
  <div class="container footer-grid">
    <div class="footer-brand">
      <img src="assets/img/logo.svg" alt="<?= htmlspecialchars($company['brand_name']) ?>" height="32">
      <p><?= htmlspecialchars($company['intro']) ?></p>
    </div>
    <div class="footer-col">
      <h4>Company</h4>
      <ul>
        <li><a href="index.php">Home</a></li>
        <li><a href="services.php">Services</a></li>
        <li><a href="about.php">About</a></li>
        <li><a href="contact.php">Contact</a></li>
      </ul>
    </div>
    <div class="footer-col">
      <h4>Contact</h4>
      <ul>
        <li><a href="mailto:<?= htmlspecialchars($company['email']) ?>"><?= htmlspecialchars($company['email']) ?></a></li>
        <?php foreach ($company['phones'] as $p): if (!empty($p['show'])): ?>
        <li><a href="tel:<?= htmlspecialchars($p['tel']) ?>"><?= htmlspecialchars($p['display']) ?></a> <span class="muted">· <?= htmlspecialchars($p['label']) ?></span></li>
        <?php endif; endforeach; ?>
      </ul>
    </div>
    <div class="footer-col">
      <h4>Registered office</h4>
      <address>
        <?= htmlspecialchars($company['legal_name']) ?><br>
        <?= htmlspecialchars($company['address_line']) ?><br>
        <?= htmlspecialchars($company['address_city']) ?><br>
        <span class="muted"><?= htmlspecialchars($company['address_meta']) ?></span>
      </address>
    </div>
  </div>
  <div class="container footer-bottom">
    <p>&copy; <?= date('Y') ?> <?= htmlspecialchars($company['copyright']) ?>. All rights reserved.</p>
    <p class="muted"><a href="privacy.php">Privacy</a> · <a href="terms.php">Terms</a> · Registered in the United States</p>
  </div>
</footer>
<script src="assets/js/main.js"></script>
</body>
</html>
