# Local Dev Template

Minimal docker-compose for running Nova OS + LibreChat on a single host with
plain HTTP. Intended for developer laptops and demo boxes where the operator
is the only user and TLS isn't required.

**Don't use this in production.** It runs with default-but-explicit secrets,
no TLS, and exposes the admin SPA to anyone who can reach the host.

## What it brings up

- **nova-os** on port 8900 (HTTP)
- **postgres** internal-only
- **surrealdb** internal-only
- **librechat** on port 3080 (HTTP)

Total ~4 containers, ~700 MB RAM idle.

## Setup

```bash
cp .env.example .env
# edit .env: set OPENAI_API_KEY at minimum
docker compose up -d
./verify.sh
```

`verify.sh` runs end-to-end correctness checks via
`nova-os doctor deployment` inside the container plus a few black-box
HTTP probes from outside. Exit 0 means the deployment is ready; exit 1
prints which check failed and a one-line fix.

## URLs

- LibreChat UI: `http://localhost:3080`
- Nova OS dashboard: `http://localhost:8900/admin/`
- Nova OS API: `http://localhost:8900/v1/`

## Teardown

```bash
docker compose down -v   # -v wipes the Postgres + Surreal volumes too
```

## Troubleshooting

If `verify.sh` reports a FAIL line, the doctor command also prints a
`fix:` hint pointing at the specific env var or container to inspect.

Common issues on first run:

- **OIDC strategy fails to register in LibreChat** — `verify.sh` won't catch
  this directly, but the symptom is "Sign in with Nova OS" returning
  `ERR_CONNECTION_REFUSED`. Cause: `NOVA_OS_PUBLIC_URL` must be reachable
  from the LibreChat container AND from your browser. For this template,
  `host.docker.internal:8900` works from inside Docker but not from a
  browser on a different machine. Browse from the same host that runs
  Docker, or switch to the `single-host-prod` template.
- **Browser auto-upgrades HTTP → HTTPS and refuses** — Chrome's HTTPS-First
  mode kicks in on non-localhost hostnames. Use `http://localhost:3080`
  exactly (not `http://127.0.0.1:3080` or `http://your-hostname:3080`),
  or disable HTTPS-First for the host in `chrome://settings/security`.
