# Nova OS Stack

Reference deployment manifests for [Nova OS](https://github.com/MeganovaAI/nova-os-sdk) — the agentic operating system from MegaNova.

This repo contains:

- A root `docker-compose.yml` that brings up **Nova OS core** (server + Postgres + SurrealDB) from the public Docker image at `ghcr.io/meganovaai/nova-os`.
- An `apps/` directory with optional companion stacks: LibreChat (chat UI), SearXNG (meta-search), crawl4ai (page fetcher), Docling (document parser).
- `docs/` with cross-cutting setup notes (networking, OIDC, upgrades).

You don't need any of the apps under `apps/` to run Nova OS. Pull only what you need.

**Current tested version:** `v0.1.7`. The default in `.env.example` and `docker-compose.yml` is pinned to this tag. Newer tags may have config or behavior changes not yet reflected here.

## Quickstart — core only

```bash
git clone https://github.com/MeganovaAI/nova-os-stack.git
cd nova-os-stack

cp .env.example .env
# Edit .env — set at minimum:
#   NOVA_OS_ADMIN_EMAIL, NOVA_OS_ADMIN_PASSWORD (>= 12 chars),
#   NOVA_OS_JWT_SECRET   (openssl rand -hex 32),
#   POSTGRES_PASSWORD    (openssl rand -hex 32),
#   NOVA_OS_PUBLIC_URL,  and at least one LLM provider key.

docker compose up -d
docker compose logs -f nova-os    # wait for "http server started on :8900"

curl http://localhost:8900/api/health  # expect {"status":"ok",...}
```

Then open:
- `http://localhost:8900/` — main UI
- `http://localhost:8900/admin/apps.html` — apps lifecycle (v0.1.7+)
- `http://localhost:8900/admin/infrastructure.html` — runtime settings (LLM model, backends, etc.)

The full install walkthrough lives at <https://docs.meganova.ai/nova-os/install>.

## Multi-app primitive (v0.1.7+)

Nova OS hosts multiple partner-built **apps** in one process. Each app is a self-contained unit of agents + Postgres tables + a manifest, hot-loaded into the running server without restart.

The compose file mounts a persistent volume at `/var/nova-os/apps` so anything you install via the lifecycle endpoints survives container restarts. Without the mount, installed apps would be wiped on `docker compose down/up`.

### Three ways to manage apps

1. **CLI** (run from inside the container or against a remote host):
   ```bash
   docker compose exec nova-os nova-os apps list --token "$ADMIN_JWT"
   docker compose exec nova-os nova-os apps install <name> --token "$ADMIN_JWT"
   docker compose exec nova-os nova-os apps reload <name> --token "$ADMIN_JWT"
   docker compose exec nova-os nova-os apps uninstall <name> --token "$ADMIN_JWT"
   ```

2. **Admin UI**: `http://localhost:8900/admin/apps.html` — table view, expandable per-row drawer showing agents + migration history, lifecycle buttons.

3. **HTTP API**:
   - `GET  /v1/apps`                       — list installed apps
   - `GET  /v1/apps/:app/agents`           — agents under one app
   - `GET  /v1/apps/:app/migrations`       — migration audit history
   - `POST /v1/apps/:name/install`         — install/reactivate
   - `POST /v1/apps/:name/reload`          — re-run pipeline
   - `POST /v1/apps/:name/uninstall`       — soft-delete

### Staging an app

Apps install from a directory you've staged into the persistent volume. From inside the running container:

```bash
docker compose cp ./my-app nova-os:/var/nova-os/apps/my-app
docker compose exec nova-os nova-os apps install my-app --token "$ADMIN_JWT"
```

The directory must contain a `nova-app.yaml` manifest, an `agents/` subdir of markdown agent definitions, and a `migrations/` subdir of SQL files. Full manifest format + lifecycle docs: see `docs/apps.md` in the [Nova OS SDK reference repo](https://github.com/MeganovaAI/nova-os-sdk).

## Adding a companion app

Each directory under `apps/` is independent. Activate one by running its compose file alongside the root:

```bash
# Example: bring up LibreChat as the chat UI
cp apps/librechat/.env.example apps/librechat/.env
# fill in the required secrets, then:
docker compose -f docker-compose.yml -f apps/librechat/docker-compose.yaml up -d
```

| App | Purpose | Default port | License |
|---|---|---|---|
| [`apps/librechat`](apps/librechat) | Chat UI (LibreChat) wired to Nova OS via OIDC + custom endpoint | 3080 | MIT |
| [`apps/searxng`](apps/searxng) | Self-hosted meta-search aggregator (zero API cost) | 8888 | AGPL-3.0 |
| [`apps/crawl4ai`](apps/crawl4ai) | JS-friendly page fetcher | 11235 | Apache-2.0 |
| [`apps/docling`](apps/docling) | Document-to-Markdown parser (PDF OCR + DOCX) | 5001 | Apache-2.0 |

> **Apps under `apps/`** are companion *services* (separate containers wired to Nova OS over HTTP). They're distinct from **Nova OS apps** described in the previous section — those are partner-authored agent + migration bundles that load into the Nova OS process itself. Both exist; they're different scoping primitives.

### Licensing note

SearXNG is AGPL-3.0. Nova OS communicates with it over its public HTTP API only — it does not bundle or link against it. Customers who prefer to avoid AGPL components entirely can swap in an alternative search backend (Tavily, Brave, Exa, MegaNova gateway) via the documented `Searcher` interface.

## Versioning

Each tag of this repo pins a known-working set of (Nova OS, companion-app) image versions. The default in `.env.example` and `docker-compose.yml` tracks the most recent tested Nova OS release.

| Stack tag | Nova OS image | Notes |
|---|---|---|
| `main` (current) | `v0.1.7` | Multi-app primitive, admin UI for apps, `nova-os apps` CLI |

- Nova OS image versions: <https://github.com/orgs/MeganovaAI/packages/container/package/nova-os>
- Release notes: <https://docs.meganova.ai/nova-os/releases>

## Docs

- [Install guide](https://docs.meganova.ai/nova-os/install) — first-time setup
- [docs/networking.md](docs/networking.md) — how the containers reach each other
- [docs/oidc-setup.md](docs/oidc-setup.md) — how to register companion apps as OIDC clients
- [docs/upgrade.md](docs/upgrade.md) — upgrading between Nova OS versions
- [docs/ag-ui.md](docs/ag-ui.md) — wiring CopilotKit or any AG-UI client to Nova OS

## License

MIT — see [LICENSE](LICENSE). Each `apps/<name>/` retains the upstream image's license; see the per-app README for details.
