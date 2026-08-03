# How to Get Google OAuth Credentials for HoneyDue Calendar Sync

This is a one-time setup. It takes about 5 minutes and is completely free.

---

## Step 1 — Create a Google Cloud Project

1. Go to [https://console.cloud.google.com](https://console.cloud.google.com)
2. Sign in with your **personal** Google account (the one that owns the calendar you want to sync to)
3. Click the project dropdown at the top → **New Project**
4. Name it anything (e.g. `HoneyDue Cal Sync`) → **Create**

---

## Step 2 — Enable the Google Calendar API

1. In the left sidebar → **APIs & Services** → **Library**
2. Search for **Google Calendar API**
3. Click it → **Enable**

---

## Step 3 — Create OAuth 2.0 Credentials

1. In the left sidebar → **APIs & Services** → **Credentials**
2. Click **+ Create Credentials** → **OAuth client ID**
3. If prompted to configure the consent screen first:
   - Click **Configure Consent Screen**
   - Choose **External** → **Create**
   - App name: `HoneyDue Calendar Sync`
   - User support email: your email
   - Developer contact email: your email
   - Click **Save and Continue** through the remaining steps
   - Back on the Credentials page, click **+ Create Credentials** → **OAuth client ID** again
4. Application type: **Desktop app**
5. Name: `HoneyDue Cal Sync` (or anything)
6. Click **Create**
7. Click **Download JSON** on the confirmation dialog

---

## Step 4 — Place the File

Move the downloaded file to this folder and rename it:

```
credentials.json
```

Example — if downloaded as `client_secret_123456-abc.apps.googleusercontent.com.json`:

```bash
mv ~/Downloads/client_secret_*.json /path/to/honeydue-cal-sync/credentials.json
```

Or just use the **Browse…** button in the app to point to it wherever you saved it.

---

## Step 5 — First Run (One-Time Browser Consent)

The first time you click **Run Now**, a browser window will open asking you to:

1. Choose your Google account
2. Click **Allow** to grant HoneyDue Calendar Sync access to your calendar

This saves a `token.json` file locally. **All future runs are fully automatic** — no browser needed.

> **Note:** Google may show a warning screen saying "This app isn't verified." This is normal
> for personal OAuth apps that haven't been submitted for review. Click **Advanced** →
> **Go to HoneyDue Calendar Sync (unsafe)** to proceed. The app only accesses your own calendar.

---

## What the App Can Access

The OAuth scope requested is `https://www.googleapis.com/auth/calendar` — full calendar access
on your personal Google account. The app only reads from Outlook and writes sanitised
(IBM-confidential-free) events to one Google Calendar of your choosing.

---

## Security Notes

- `credentials.json` and `token.json` are stored locally on your Mac only
- Neither file should ever be committed to source control (both are in `.gitignore`)
- The app never sends any data to Microsoft — it reads Outlook locally via AppleScript
- The only data written to Google is: event title + start time + end time + the text `IBM - BLOCK`

---

*For more details see [Google Calendar API documentation](https://developers.google.com/calendar/api/quickstart/python)*
