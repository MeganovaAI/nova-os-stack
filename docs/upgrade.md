# Upgrading

Upgrading Libra OS is a Docker image swap. Postgres + SurrealDB persistence is preserved across upgrades — schema migrations run automatically on first boot of the new version.

## Pin a version

In production, pin the exact image tag in your root `.env`:

```
NOVA_OS_VERSION=v0.1.4
```

Avoid `latest` in production — it makes upgrade timing nondeterministic across hosts. Watch the [GitHub releases page](https://github.com/MeganovaAI/nova-os-sdk/releases) or subscribe to the `:latest` Docker tag in your deploy automation only.

## Standard upgrade flow

```bash
# 1. Read the release notes for the target version.
#    https://docs.meganova.ai/nova-os/releases — covers migration notes,
#    breaking changes, and operational follow-ups.

# 2. Snapshot the database (production hosts always do this first).
docker compose exec postgres pg_dump -U nova nova_os > backup-$(date +%Y%m%d).sql

# 3. Bump the pin in .env.
sed -i 's/^NOVA_OS_VERSION=.*/NOVA_OS_VERSION=v0.1.4/' .env

# 4. Pull and restart.
docker compose pull nova-os
docker compose up -d nova-os

# 5. Watch the boot log.
docker compose logs -f nova-os
# Expected lines: "applied N migrations", then "ready on :8900".

# 6. Smoke test.
curl -s "${NOVA_OS_PUBLIC_URL}/health"  # expect {"status":"ok"}
```

## Rolling back

If the new version fails to boot or breaks behaviour, revert the image tag:

```bash
sed -i 's/^NOVA_OS_VERSION=.*/NOVA_OS_VERSION=v0.1.3/' .env
docker compose up -d nova-os
```

Rollback is safe **as long as the new version did not run a non-reversible migration** — release notes call out any one-way migrations explicitly. If you've crossed one, restore from the dump:

```bash
docker compose down nova-os postgres
docker volume rm nova-os-stack_pg-data    # destroys current state
docker compose up -d postgres
docker compose exec -T postgres psql -U nova -d nova_os < backup-YYYYMMDD.sql
docker compose up -d nova-os
```

## Companion-app upgrades

Each companion app uses its upstream image's `:latest` tag by default. Pin them to specific tags in your fork of `apps/<name>/docker-compose.yaml` if you need bit-for-bit reproducibility — most teams do this for LibreChat (since it's user-facing) and leave the parsers / fetchers floating.

## Where to subscribe

| Channel | Cadence | Setup |
|---|---|---|
| GitHub Releases watch | Every tag | Watch [`MeganovaAI/nova-os-sdk`](https://github.com/MeganovaAI/nova-os-sdk) → Custom → Releases |
| `:latest` Docker tag | Every stable release (skips RCs) | `docker pull ghcr.io/libraos/libraos:latest` |
| RSS feed | Every release | <https://github.com/MeganovaAI/nova-os-sdk/releases.atom> |
