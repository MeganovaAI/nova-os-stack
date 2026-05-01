# SearXNG companion app

Self-hosted meta-search aggregator. Provides Nova OS's `web` skill with snippet-level search results without a per-query API cost.

Image: [`searxng/searxng`](https://github.com/searxng/searxng) — **AGPL-3.0**.

## License posture

Nova OS communicates with SearXNG over its public HTTP API only and does not bundle, link against, or ship SearXNG. Customers running this stack are responsible for complying with SearXNG's AGPL terms (which is straightforward for self-hosted use). If your legal team needs a non-AGPL alternative, swap in the `Fetcher` interface — see Nova OS docs.

## Bring up

```bash
docker compose -f docker-compose.yml -f apps/searxng/docker-compose.yaml up -d
```

SearXNG will be available on `http://localhost:8888`. The `searxng-data/` directory holds its config — first start auto-creates a baseline.

## Wire to Nova OS

Add to the root `.env`:

```
SEARXNG_URL=http://searxng:8080
```

Then `docker compose up -d nova-os` to pick up the change. Verify:

```bash
curl -sS "http://localhost:8888/search?q=nova+os&format=json" | head -c 500
```

## Customisation

The `searxng-data/settings.yml` file (created on first boot) controls which engines are enabled, instance branding, and rate-limit policies. See <https://docs.searxng.org/admin/settings/index.html>.
