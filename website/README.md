# LXE Global — Company Website (PHP)

A modern, minimal PHP website for **LXEGLOBAL LLC**, a financial technology
consultancy. White canvas with a light-green accent, editorial typography,
fully responsive, and self-installing on shared hosting (built for Hostinger).

No database required. No demo/placeholder content — everything is real company
information pulled from a single config file.

---

## What's inside

| File / folder | Purpose |
|---|---|
| `index.php` | Home page |
| `services.php` | Detailed services |
| `about.php` | About the company |
| `contact.php` | Contact page + working enquiry form |
| `privacy.php`, `terms.php` | Legal pages (recommended for App Store / Apple review) |
| `404.php` | Friendly error page |
| `install.php` | One-click setup wizard — **run this once, then delete it** |
| `includes/company.php` | **All company info lives here** (name, address, email, phones) |
| `includes/header.php`, `footer.php` | Shared layout |
| `assets/` | CSS, JS, logo & favicon (all self-contained) |
| `data/` | Stores enquiries; protected from the public |

---

## How to deploy on Hostinger (2 minutes)

1. **Zip the contents** of this `website/` folder (not the folder itself —
   the files should sit at the top level of the zip).
2. In hPanel open **Files → File Manager** and go to `public_html`.
3. **Upload** the zip into `public_html` and use **Extract** so the files land
   directly inside `public_html`.
4. Make sure PHP is set to **7.4 or newer** (hPanel → Advanced → PHP Configuration).
5. Open **`https://yourdomain.com/install.php`** in your browser.
6. The installer checks your server, lets you confirm your support email and
   (optionally) add a valid U.S. phone number, then unlocks the site.
7. When it says "installed", click **Open my website**, then **delete
   `install.php`** from the File Manager for security.

That's it — your site is live.

---

## Editing your content later

Open `includes/company.php` and edit the values at the top (name, address,
email, phone numbers). Every page updates automatically. You can also re-run
`install.php` if you re-upload it.

### ⚠️ About the U.S. phone number

The U.S. number provided (`+1 847724552`) is **only 9 digits and is not valid** —
a U.S. number needs a 3-digit area code plus a 7-digit number (10 total),
e.g. `+1 (847) 555-0123`. Until you supply a correct number, the U.S. phone
line is **hidden** so the site never shows a broken number. Add the real number
in the installer or in `includes/company.php` (`'show' => true`).

---

## Contact form

Submissions are saved to `data/enquiries.log` (always) and emailed to your
support address via PHP `mail()` when the hosting supports it. Hostinger
supports `mail()` on most plans; for guaranteed delivery you can later connect
SMTP, but nothing extra is required for the site to work.
