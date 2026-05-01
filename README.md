# Nova OS Stack

Reference deployment manifests for [Nova OS](https://github.com/MeganovaAI/nova-os-sdk) — the agentic operating system from MegaNova.

This repo contains:

- A root `docker-compose.yml` that brings up **Nova OS core** (server + Postgres + SurrealDB) from the public Docker image at `ghcr.io/meganovaai/nova-os`.
- An `apps/` directory with optional companion stacks: LibreChat (chat UI), SearXNG (meta-search), crawl4ai / Firecrawl (page fetchers), Docling (document parser), FlashRank (reranker), Phoenix (LLM observability), Hermes (agent gateway).
- `docs/` with cross-cutting setup notes (networking, OIDC, upgrades).

You don't need any of the apps under `apps/` to run Nova OS. Pull only what you need.

## Quickstart — core only

```bash
git clone https://github.com/MeganovaAI/nova-os-stack.git
cd nova-os-stack

cp .env.example .env
# Edit .env — set at minimum:
#   NOVA_OS_ADMIN_EMAIL, NOVA_OS_ADMIN_PASSWORD, POSTGRES_PASSWORD,
#   NOVA_OS_PUBLIC_URL, and at least one LLM provider key.

docker compose up -d
docker compose logs -f nova-os    # wait for "ready on :8900"

curl http://localhost:8900/health  # expect {"status":"ok"}
```

The full install walkthrough lives at <https://docs.meganova.ai/nova-os/install>.

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
| [`apps/firecrawl`](apps/firecrawl) | PDF-friendly fetch + extract (5-container stack) | 3022 | AGPL-3.0 |
| [`apps/docling`](apps/docling) | Document-to-Markdown parser (PDF OCR + DOCX) | 5001 | Apache-2.0 |
| [`apps/flashrank`](apps/flashrank) | Cross-encoder reranker for retrieval | 8002 | MIT |
| [`apps/phoenix`](apps/phoenix) | OTLP trace receiver + UI for LLM observability | 6006 / 4317 | ELv2 |
| [`apps/hermes`](apps/hermes) | NousResearch Hermes agent gateway bridge | – | Apache-2.0 |

### Licensing note

SearXNG and Firecrawl OSS are AGPL-3.0. Nova OS communicates with them over their public HTTP APIs only — it does not bundle or link against them. Customers who prefer to avoid AGPL components entirely can swap in alternatives via the documented `Fetcher` interface.

## Versioning

Each tag of this repo pins a known-working set of (Nova OS, companion-app) image versions. The default in `.env.example` tracks the most recent stable Nova OS release.

- Nova OS image versions: <https://github.com/orgs/MeganovaAI/packages/container/package/nova-os>
- Release notes: <https://docs.meganova.ai/nova-os/releases>

## Docs

- [Install guide](https://docs.meganova.ai/nova-os/install) — first-time setup
- [docs/networking.md](docs/networking.md) — how the containers reach each other
- [docs/oidc-setup.md](docs/oidc-setup.md) — how to register companion apps as OIDC clients
- [docs/upgrade.md](docs/upgrade.md) — upgrading between Nova OS versions

## License

MIT — see [LICENSE](LICENSE). Each `apps/<name>/` retains the upstream image's license; see the per-app README for details.
