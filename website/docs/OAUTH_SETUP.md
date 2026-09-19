# OAuth sign-in for Nest

Nest uses **OAuth only** (no passwords): GitHub and/or Google via [Auth.js](https://authjs.dev).

## 1. Generate `AUTH_SECRET`

```bash
openssl rand -base64 32
```

Add to Vercel → Project → Settings → Environment Variables (Production + Preview):

| Variable | Value |
|----------|--------|
| `AUTH_SECRET` | output from above |
| `AUTH_URL` | `https://getnestapp.vercel.app` |
| `NEXT_PUBLIC_SITE_URL` | `https://getnestapp.vercel.app` |

## 2. GitHub OAuth App

1. GitHub → **Settings** → **Developer settings** → **OAuth Apps** → **New OAuth App**
2. **Homepage URL:** `https://getnestapp.vercel.app`
3. **Authorization callback URL:**  
   `https://getnestapp.vercel.app/api/auth/callback/github`
4. Copy **Client ID** and generate **Client secret** → Vercel:
   - `AUTH_GITHUB_ID`
   - `AUTH_GITHUB_SECRET`

## 3. Google OAuth (optional)

1. [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials → **OAuth client ID** (Web)
2. **Authorized redirect URI:**  
   `https://getnestapp.vercel.app/api/auth/callback/google`
3. Vercel:
   - `AUTH_GOOGLE_ID`
   - `AUTH_GOOGLE_SECRET`

## 4. Redeploy

Redeploy the `website` project on Vercel after env vars are set.

## URLs

| Page | URL |
|------|-----|
| Sign in (web) | `/login` |
| Sign up | `/signup` (redirects to login) |
| Account | `/account` |
| Mac app handoff | `/login?client=mac` → `nest://auth/callback?token=…` |

## Mac app

Settings → **Account** → **Sign In with OAuth** opens the same flow and returns to Nest via the `nest://` URL scheme.
