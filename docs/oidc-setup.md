# OIDC client registration

Libra OS ships with a built-in OpenID Connect provider, so any OIDC-aware application — LibreChat, Chatwoot, Outline, Grafana, etc. — can delegate login to Libra OS without standing up a separate identity provider.

This page walks through registering one client (LibreChat in the examples). Repeat the same flow for additional clients.

## 1. Sign in to Libra OS as admin

Use the admin email and password set in the root `.env` (`NOVA_OS_ADMIN_EMAIL` / `NOVA_OS_ADMIN_PASSWORD`).

## 2. Create the client

Navigate to **Settings → OIDC → Add Client**.

| Field | Value |
|---|---|
| Client ID | `librechat` (must match `OPENID_CLIENT_ID` in `apps/librechat/docker-compose.yaml`) |
| Client Name | LibreChat (free-form, shown to end-users on the consent screen) |
| Redirect URI | `${LIBRECHAT_PUBLIC_URL}/oauth/openid/callback` (e.g. `https://chat.your-company.example/oauth/openid/callback`) |
| Allowed Scopes | `openid profile email` |
| Token Endpoint Auth | `client_secret_basic` |

Click **Save**. Libra OS will generate a fresh client secret and show it once.

## 3. Wire the secret into the companion app

Paste the generated secret into `apps/librechat/.env` as `NOVA_OS_OIDC_CLIENT_SECRET`. Restart the companion stack:

```bash
docker compose -f docker-compose.yml -f apps/librechat/docker-compose.yaml up -d
```

## 4. Verify the issuer URL

LibreChat's `OPENID_ISSUER` defaults to `${NOVA_OS_PUBLIC_URL}` (set in the root `.env`). It must match exactly what Libra OS publishes in its discovery document — fetch it to confirm:

```bash
curl -s "${NOVA_OS_PUBLIC_URL}/.well-known/openid-configuration" | head -c 500
```

The `issuer` field in the JSON response must match `NOVA_OS_PUBLIC_URL`. If they differ (typical when running behind a reverse proxy), set `NOVA_OS_OIDC_ISSUER` in `apps/librechat/.env` to the value Libra OS actually publishes.

## 5. Sign in

Open the LibreChat URL and click **Sign in with Libra OS**. The redirect should bounce you to Libra OS's login page, then back to LibreChat as a signed-in user.

## Common pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `iss claim mismatch` | LibreChat's `OPENID_ISSUER` doesn't match Libra OS's published issuer | Set `NOVA_OS_OIDC_ISSUER` to whatever the discovery doc reports |
| `redirect_uri_mismatch` | URI registered in Libra OS doesn't include the full path / scheme | Re-register with the exact URI LibreChat is calling — check the browser address bar after the failed redirect |
| Loop between login and consent | Self-signed TLS cert on Libra OS, LibreChat rejecting it | Set `NODE_TLS_REJECT_UNAUTHORIZED=0` in `apps/librechat/.env` (development only) or install a real cert |
| `id_token_signed_response_alg` mismatch | Client is configured for a non-default signing algorithm | Leave the field empty in Libra OS to use the default RS256 |
