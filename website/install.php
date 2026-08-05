<?php
/**
 * LXE Global — one-click installer / setup wizard.
 *
 * Upload the whole website folder to your Hostinger public_html, then open
 * this file in your browser (e.g. https://yourdomain.com/install.php).
 * It checks the environment, saves your contact details and unlocks the site.
 * Delete this file when you're done.
 */

error_reporting(E_ALL & ~E_DEPRECATED & ~E_NOTICE);

$root     = __DIR__;
$dataDir  = $root . '/data';
$lockFile = $dataDir . '/.installed';
$cfgFile  = $dataDir . '/site-config.json';

$defaults = require $root . '/includes/company.php';

// ---- environment checks ----
if (!is_dir($dataDir)) { @mkdir($dataDir, 0755, true); }

$checks = [
    ['PHP version 7.4 or newer', version_compare(PHP_VERSION, '7.4.0', '>='), 'Detected PHP ' . PHP_VERSION],
    ['"data" folder is writable', is_dir($dataDir) && is_writable($dataDir), 'Needed to store enquiries'],
    ['Mail function available', function_exists('mail'), 'Optional — enables email notifications'],
    ['JSON support', function_exists('json_encode'), 'Required for configuration'],
];
$requiredOk = $checks[0][1] && $checks[1][1] && $checks[3][1];

$installed = is_file($lockFile);
$done = false;
$errors = [];

// ---- handle install submission ----
if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'install') {
    if (!$requiredOk) {
        $errors[] = 'Your server does not meet the minimum requirements yet. Please review the checklist above.';
    } else {
        $email = trim($_POST['email'] ?? '');
        if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $errors[] = 'The support email address is not valid.';
        }

        $usDisplay = trim($_POST['us_phone'] ?? '');
        $usTel = preg_replace('/[^0-9+]/', '', $usDisplay);
        // Validate US number only if provided: must have 10 digits after +1 / 1 / nothing
        $usValid = true;
        if ($usDisplay !== '') {
            $digits = preg_replace('/\D/', '', $usTel);
            if (strlen($digits) === 11 && $digits[0] === '1') { $digits10 = substr($digits, 1); }
            elseif (strlen($digits) === 10) { $digits10 = $digits; }
            else { $usValid = false; }
            if (!$usValid) {
                $errors[] = 'The U.S. phone number must contain a 10-digit number (area code + 7 digits). Example: +1 (847) 555-0123.';
            } else {
                $usTel = '+1' . $digits10;
            }
        }

        if (empty($errors)) {
            $config = [];
            if ($email !== '')                { $config['email'] = $email; }
            if ($usDisplay !== '' && $usValid){ $config['us_phone_display'] = $usDisplay; $config['us_phone_tel'] = $usTel; }
            $config['installed_at'] = date('c');

            @file_put_contents($cfgFile, json_encode($config, JSON_PRETTY_PRINT));
            @file_put_contents($lockFile, 'Installed ' . date('c') . "\n");
            @file_put_contents($dataDir . '/.htaccess', "Deny from all\n"); // hide data dir on Apache
            $done = true;
            $installed = true;
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Install · LXE Global</title>
<link rel="icon" type="image/svg+xml" href="assets/img/favicon.svg">
<link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,400;9..144,500&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
<style>
:root{--green:#16a34a;--ink:#0f172a;--muted:#64748b;--line:#e7ebef;--soft:#f7faf8;--green-ink:#0f241c}
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Inter',system-ui,sans-serif;background:radial-gradient(70% 60% at 80% -10%,#ecfdf5,transparent 60%),#fff;color:#334155;line-height:1.6;min-height:100vh}
.wrap{max-width:720px;margin:0 auto;padding:48px 24px 80px}
.logo{display:flex;align-items:center;gap:10px;margin-bottom:34px}
h1{font-family:'Fraunces',serif;font-weight:500;color:var(--ink);font-size:2rem;line-height:1.15;margin-bottom:8px}
.sub{color:var(--muted);margin-bottom:30px}
.panel{background:#fff;border:1px solid var(--line);border-radius:20px;box-shadow:0 12px 32px rgba(15,23,42,.06);padding:30px;margin-bottom:22px}
h2{font-family:'Fraunces',serif;font-weight:500;color:var(--ink);font-size:1.3rem;margin-bottom:16px}
.check{display:flex;align-items:center;gap:12px;padding:11px 0;border-bottom:1px solid var(--line)}
.check:last-child{border-bottom:0}
.badge{width:24px;height:24px;border-radius:50%;display:grid;place-items:center;flex:none;font-size:14px}
.badge.ok{background:#dcfce7;color:#15803d}
.badge.no{background:#fee2e2;color:#dc2626}
.check .t{font-weight:500;color:var(--ink)}
.check .d{font-size:.85rem;color:var(--muted)}
.field{margin-bottom:18px}
label{display:block;font-size:.85rem;font-weight:600;color:var(--ink);margin-bottom:7px}
input{width:100%;padding:12px 14px;border:1px solid var(--line);border-radius:12px;font-family:inherit;font-size:.97rem;color:var(--ink)}
input:focus{outline:none;border-color:#34d399;box-shadow:0 0 0 4px #ecfdf5}
.hint{font-size:.8rem;color:var(--muted);margin-top:6px}
.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;width:100%;background:var(--green-ink);color:#fff;font-weight:600;font-size:1rem;padding:14px;border:0;border-radius:999px;cursor:pointer;transition:.18s;text-decoration:none}
.btn:hover{background:#173a2c}
.btn.green{background:var(--green)}.btn.green:hover{background:#15803d}
.alert{padding:13px 15px;border-radius:12px;font-size:.92rem;margin-bottom:18px;background:#fef2f2;color:#dc2626;border:1px solid #fecaca}
.ok-box{text-align:center;padding:14px 0}
.ok-ring{width:64px;height:64px;border-radius:50%;background:#dcfce7;color:#15803d;display:grid;place-items:center;margin:0 auto 18px}
.warn{background:#fffbeb;border:1px solid #fde68a;color:#92400e;font-size:.88rem;padding:12px 14px;border-radius:12px;margin-top:16px}
code{background:var(--soft);padding:2px 7px;border-radius:6px;font-size:.86rem;color:var(--green-ink)}
</style>
</head>
<body>
<div class="wrap">
  <div class="logo"><img src="assets/img/logo.svg" alt="LXE Global" height="34"></div>

  <?php if ($done): ?>
    <div class="panel">
      <div class="ok-box">
        <div class="ok-ring"><svg width="30" height="30" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l5 5L20 6"/></svg></div>
        <h1>Your website is installed.</h1>
        <p class="sub">Everything is configured and ready. Your visitors (and Apple's review team) can now see a complete, working site.</p>
        <a class="btn green" href="index.php">Open my website →</a>
      </div>
      <div class="warn"><strong>One last step:</strong> for security, delete <code>install.php</code> from your hosting now that setup is complete.</div>
    </div>
  <?php else: ?>

    <h1>Install your LXE Global website</h1>
    <p class="sub">This quick setup checks your server and saves your contact details. It takes about 30 seconds.</p>

    <?php foreach ($errors as $e): ?><div class="alert"><?= htmlspecialchars($e) ?></div><?php endforeach; ?>

    <div class="panel">
      <h2>1 · Server check</h2>
      <?php foreach ($checks as $c): ?>
      <div class="check">
        <span class="badge <?= $c[1] ? 'ok' : 'no' ?>">
          <?php if ($c[1]): ?>&#10003;<?php else: ?>&#33;<?php endif; ?>
        </span>
        <div><div class="t"><?= htmlspecialchars($c[0]) ?></div><div class="d"><?= htmlspecialchars($c[2]) ?></div></div>
      </div>
      <?php endforeach; ?>
      <?php if (!$requiredOk): ?>
        <div class="warn" style="margin-top:16px">Some required items failed. On Hostinger, set the folder permissions of <code>data</code> to 755 and ensure PHP 7.4+ is selected, then reload this page.</div>
      <?php endif; ?>
    </div>

    <form method="post" action="install.php">
      <input type="hidden" name="action" value="install">
      <div class="panel">
        <h2>2 · Confirm your details</h2>
        <div class="field">
          <label for="email">Support email</label>
          <input type="email" id="email" name="email" value="<?= htmlspecialchars($defaults['email']) ?>">
          <div class="hint">Where website enquiries are sent. Leave as-is to keep the default.</div>
        </div>
        <div class="field">
          <label for="us_phone">U.S. phone number <span style="color:var(--muted);font-weight:400">(optional)</span></label>
          <input type="text" id="us_phone" name="us_phone" placeholder="+1 (847) 555-0123">
          <div class="hint">The number you provided earlier (+1 847724552) was incomplete — a U.S. number needs 10 digits. Enter the correct number to show it, or leave blank to hide the U.S. line for now.</div>
        </div>
      </div>

      <button type="submit" class="btn" <?= $requiredOk ? '' : 'disabled style=opacity:.5;cursor:not-allowed' ?>>Install website →</button>
    </form>
  <?php endif; ?>
</div>
</body>
</html>
