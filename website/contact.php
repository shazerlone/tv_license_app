<?php
$company = require __DIR__ . '/includes/company.php';

$sent = false;
$error = '';
$old = ['name'=>'','email'=>'','subject'=>'','message'=>''];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Honeypot (spam bots fill hidden fields)
    if (!empty($_POST['website'])) {
        $sent = true; // silently accept, ignore
    } else {
        $old['name']    = trim($_POST['name'] ?? '');
        $old['email']   = trim($_POST['email'] ?? '');
        $old['subject'] = trim($_POST['subject'] ?? '');
        $old['message'] = trim($_POST['message'] ?? '');

        if ($old['name'] === '' || $old['email'] === '' || $old['message'] === '') {
            $error = 'Please fill in your name, email and message.';
        } elseif (!filter_var($old['email'], FILTER_VALIDATE_EMAIL)) {
            $error = 'Please enter a valid email address.';
        } else {
            // 1) Store the enquiry locally (always works, even without mail server)
            $dir = __DIR__ . '/data';
            if (!is_dir($dir)) { @mkdir($dir, 0755, true); }
            $line = sprintf(
                "[%s] %s <%s> | %s | %s\n",
                date('Y-m-d H:i:s'),
                str_replace(["\r","\n"], ' ', $old['name']),
                $old['email'],
                str_replace(["\r","\n"], ' ', $old['subject'] ?: '(no subject)'),
                str_replace(["\r","\n"], ' ', $old['message'])
            );
            @file_put_contents($dir . '/enquiries.log', $line, FILE_APPEND | LOCK_EX);

            // 2) Try to email it to the company inbox (best effort)
            $to      = $company['email'];
            $subject = 'Website enquiry: ' . ($old['subject'] ?: 'New message');
            $body    = "New enquiry from the LXE Global website\n\n"
                     . "Name:    {$old['name']}\n"
                     . "Email:   {$old['email']}\n"
                     . "Subject: " . ($old['subject'] ?: '(none)') . "\n\n"
                     . "Message:\n{$old['message']}\n";
            $headers = "From: LXE Global Website <no-reply@" . ($_SERVER['HTTP_HOST'] ?? 'lxeglobal.local') . ">\r\n"
                     . "Reply-To: {$old['name']} <{$old['email']}>\r\n"
                     . "Content-Type: text/plain; charset=UTF-8\r\n";
            @mail($to, $subject, $body, $headers);

            $sent = true;
            $old = ['name'=>'','email'=>'','subject'=>'','message'=>''];
        }
    }
}

$page  = 'contact';
$title = 'Contact — LXE Global';
$desc  = 'Get in touch with LXEGLOBAL LLC. Offices reachable in Dubai, India and the United States.';
require __DIR__ . '/includes/header.php';
?>

<section class="page-hero">
  <div class="container">
    <span class="eyebrow">Contact</span>
    <h1>Let's talk about what you're building.</h1>
    <p>Send us a note and a member of our team will get back to you. We reply to every serious enquiry.</p>
  </div>
</section>

<section class="block">
  <div class="container contact-grid">
    <!-- INFO -->
    <div class="reveal">
      <h2 style="margin-bottom:8px">Reach us directly</h2>
      <p class="muted" style="margin-bottom:24px">Prefer a call or email? Here's how to find us.</p>
      <div class="info-list">
        <div class="info-item">
          <span class="ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="M2 7l10 6 10-6"/></svg></span>
          <div><h4>Email</h4><a href="mailto:<?= htmlspecialchars($company['email']) ?>"><?= htmlspecialchars($company['email']) ?></a></div>
        </div>
        <?php foreach ($company['phones'] as $p): if (!empty($p['show'])): ?>
        <div class="info-item">
          <span class="ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6 19.8 19.8 0 0 1-3.1-8.7A2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1 1 .4 1.9.7 2.8a2 2 0 0 1-.5 2.1L8.1 9.9a16 16 0 0 0 6 6l1.3-1.2a2 2 0 0 1 2.1-.5c.9.3 1.8.6 2.8.7a2 2 0 0 1 1.7 2z"/></svg></span>
          <div><h4>Call · <?= htmlspecialchars($p['label']) ?></h4><a href="tel:<?= htmlspecialchars($p['tel']) ?>"><?= htmlspecialchars($p['display']) ?></a></div>
        </div>
        <?php endif; endforeach; ?>
        <div class="info-item">
          <span class="ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 12-9 12s-9-5-9-12a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg></span>
          <div>
            <h4>Registered office</h4>
            <p style="line-height:1.6">
              <?= htmlspecialchars($company['legal_name']) ?><br>
              <?= htmlspecialchars($company['address_line']) ?><br>
              <?= htmlspecialchars($company['address_city']) ?><br>
              <span class="muted"><?= htmlspecialchars($company['address_meta']) ?></span>
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- FORM -->
    <div class="reveal">
      <div class="form-card">
        <?php if ($sent): ?>
          <div class="alert ok">Thank you — your message has been received. We'll be in touch shortly.</div>
        <?php elseif ($error): ?>
          <div class="alert err"><?= htmlspecialchars($error) ?></div>
        <?php endif; ?>
        <form method="post" action="contact.php#form" id="form" novalidate>
          <div class="field">
            <label for="name">Full name</label>
            <input type="text" id="name" name="name" value="<?= htmlspecialchars($old['name']) ?>" required autocomplete="name">
          </div>
          <div class="field">
            <label for="email">Email address</label>
            <input type="email" id="email" name="email" value="<?= htmlspecialchars($old['email']) ?>" required autocomplete="email">
          </div>
          <div class="field">
            <label for="subject">Subject</label>
            <input type="text" id="subject" name="subject" value="<?= htmlspecialchars($old['subject']) ?>" placeholder="e.g. Building an analysis platform">
          </div>
          <div class="field">
            <label for="message">How can we help?</label>
            <textarea id="message" name="message" required placeholder="Tell us about your project, market and goals."><?= htmlspecialchars($old['message']) ?></textarea>
          </div>
          <!-- honeypot: hidden from humans -->
          <div style="position:absolute;left:-9999px" aria-hidden="true">
            <label>Website<input type="text" name="website" tabindex="-1" autocomplete="off"></label>
          </div>
          <button type="submit" class="btn btn-primary" style="width:100%;justify-content:center">Send message</button>
          <p class="form-note">By sending this message you agree to be contacted by <?= htmlspecialchars($company['legal_name']) ?> regarding your enquiry.</p>
        </form>
      </div>
    </div>
  </div>
</section>

<?php require __DIR__ . '/includes/footer.php'; ?>
