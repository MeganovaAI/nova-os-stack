# Single-Host Prod Template

Production-grade deployment of Libra OS + LibreChat on a single host
behind an nginx reverse proxy with TLS termination. Suitable for
small-to-mid partner tenants where one host serves all traffic and
the operator manages their own certs.

## Topology

```
        ┌─────────── browser ───────────┐
        │                                │
        │  https://nova.partner.com/     │
        │  https://nova.partner.com/chat │
        │                                │
        └────────────────┬───────────────┘
                         │
                         ▼
              ┌────── nginx :443 ──────┐
              │  /        → nova-os    │
              │  /chat/   → librechat  │
              │  /oauth/  → nova-os    │
              │  /.well-known/ → nova-os
              └─────────┬──────────────┘
                        │ (internal HTTP only)
            ┌───────────┴───────────┐
            │                       │
       nova-os:8900           librechat:3080
            │
   ┌────────┴────────┐
   │                 │
postgres        surrealdb
```

## What it brings up

- **nginx** on :80 (HTTP→HTTPS redirect) + :443 (TLS termination)
- **nova-os** on internal :8900 (HTTP)
- **postgres** internal-only
- **surrealdb** internal-only
- **librechat** on internal :3080 (HTTP)
- **mongo** for LibreChat session store

All TLS terminates at nginx. Internal traffic is HTTP. Browser sees
only HTTPS.

## Prerequisites

1. **DNS** — point a hostname (e.g. `nova.partner.com`) at this host's
   public IP.
2. **TLS cert** — obtain a real cert (Let's Encrypt via certbot,
   purchased cert, or internal CA). Place files at:
   - `certs/fullchain.pem`
   - `certs/privkey.pem`
   Or override the paths via the `TLS_CERT_PATH` / `TLS_KEY_PATH` env vars
   in `.env`.

## Setup

```bash
# 1. Obtain certs (example: Let's Encrypt)
sudo certbot certonly --standalone -d nova.partner.com
sudo cp /etc/letsencrypt/live/nova.partner.com/fullchain.pem certs/
sudo cp /etc/letsencrypt/live/nova.partner.com/privkey.pem certs/

# 2. Configure
cp .env.example .env
# edit .env: NOVA_OS_PUBLIC_URL=https://nova.partner.com, OPENAI_API_KEY=..., etc.

# 3. Bring up
docker compose up -d
./verify.sh
```

## URLs after setup

- LibreChat UI: `https://nova.partner.com/chat/`
- Libra OS dashboard: `https://nova.partner.com/admin/`
- Libra OS OIDC discovery: `https://nova.partner.com/.well-known/openid-configuration`
- Libra OS API (partner SDK): `https://nova.partner.com/v1/`

## verify.sh

Runs four layers of checks:

1. **TLS** — cert exists, expiry > 30 days
2. **HTTPS probes** — every public URL above returns 2xx/3xx
3. **OIDC issuer match** — discovery doc's `issuer` field exactly equals
   `NOVA_OS_PUBLIC_URL` (catches the #521 drift class)
4. **`nova-os doctor deployment`** — env vars, DB migrations, gateway
   auth, agent files, LibreChat companion reachability

Exit 0 means the deployment is production-ready.

## Renewing TLS

```bash
sudo certbot renew --quiet
sudo cp /etc/letsencrypt/live/nova.partner.com/*.pem certs/
docker compose exec nginx nginx -s reload
./verify.sh
```

Or set up the auto-renewal hook in `cron-renew.sh` (provided).

## Teardown

```bash
docker compose down            # keep volumes (recoverable)
docker compose down -v         # wipe volumes (full reset)
```
