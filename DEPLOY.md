# Deploy the Sitegap dashboard online (free)

This gets you a **public link** to the dashboard that you can open from any
browser or phone. Your API key is stored as a secret in the host — it never
goes into the code or GitHub.

We'll use **Render** (free tier, connects directly to your GitHub repo).

---

## Before you start

⚠️ **Regenerate your Google API key first** if you haven't. The old one was
exposed in git history and must be replaced (Google Cloud Console → APIs &
Services → Credentials → delete the old key → create a new one → restrict it
to "Places API (New)").

---

## Steps

1. **Create a Render account** — go to <https://render.com> and sign up with
   your GitHub account (free).

2. **New Blueprint** — in Render, click **New +** (top right) →
   **Blueprint**.

3. **Connect this repo** — pick `shazerlone/tv_license_app`. Render reads the
   `render.yaml` in the repo and shows a service called **sitegap**. Click
   **Apply**.

4. **Add your key as a secret** — once the service is created, open it →
   **Environment** (left menu) → find **GOOGLE_PLACES_API_KEY** →
   **Edit** → paste your **new** key → **Save Changes**. Render redeploys
   automatically. *(This is the safe place for your key — it is hidden and
   never committed.)*

5. **Open your live link** — at the top of the service page Render shows a URL
   like `https://sitegap.onrender.com`. Click it. That's your live dashboard.

6. **Use it** — the page opens with demo leads so it isn't empty. To pull real
   businesses, click **① Search grid**, then **② Audit**, **③ Score**. Every
   lead becomes a full pitch pack with a site mock-up.

---

## Good to know

- **First load is slow.** On the free tier the app "sleeps" after 15 minutes
  of no traffic and takes ~30 seconds to wake up. Normal — just wait.
- **Free tier storage is temporary.** If Render restarts the app, the leads
  database resets (you'd re-run search). For a permanent store, add a Render
  persistent disk (paid) or move to Supabase later — the code is ready for it.
- **Cost control still applies.** Set a daily quota cap on your key in Google
  Cloud Console (Places API (New) → Quotas) so a hosted app can never run up a
  surprise bill. Use the **Max queries** box on the dashboard to stay small.
- **Want to remove the demo leads?** In Render → Environment, delete the
  `SITEGAP_AUTOSEED` variable (or set it to `0`) and redeploy.

---

## Alternative: run it on your own computer

If you'd rather not host it:

```bash
pip install -r sitegap/requirements.txt
cp .env.example .env          # then paste your key into .env
python run.py                 # opens http://127.0.0.1:5001 in your browser
```
