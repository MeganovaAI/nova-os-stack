# Firecrawl companion app

Self-hosted Firecrawl OSS — fetch + extract with strong PDF handling. Pairs with [crawl4ai](../crawl4ai): Nova OS's `RoutingFetcher` automatically routes PDF URLs to Firecrawl and HTML to crawl4ai when both are configured.

Image: [`ghcr.io/firecrawl/firecrawl`](https://github.com/firecrawl/firecrawl) — **AGPL-3.0**.

This stack is monolithic — 5 containers (api, playwright, redis, rabbitmq, postgres) — so only deploy it if you actually need PDF fetching beyond what [Docling](../docling) handles at ingestion time.

## License posture

Nova OS communicates with Firecrawl over its public HTTP API only. See [`apps/searxng/README.md`](../searxng/README.md) for the AGPL posture.

## Setup

```bash
cp apps/firecrawl/.env.example apps/firecrawl/.env
# Generate the queue-admin key, then:
docker compose -f docker-compose.yml -f apps/firecrawl/docker-compose.yaml up -d
```

API on `http://localhost:3022`. Redis / RabbitMQ / Postgres stay on the internal compose network.

## Wire to Nova OS

Add to the root `.env`:

```
FIRECRAWL_URL=http://firecrawl-api:3002
```

Then `docker compose up -d nova-os`. Verify:

```bash
curl -sS -X POST http://localhost:3022/v1/scrape \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://example.com","formats":["markdown"]}'
```

## Resource notes

- GPU is not used. Do not allocate one.
- LLM-based `/extract` and JSON-format scrape silently degrade without `OPENAI_API_KEY` / `OLLAMA_BASE_URL`. Basic `/v1/scrape` works without them.
- Default resource limits: API 4 CPU / 8 GB, Playwright 2 CPU / 4 GB, others smaller. Adjust in `docker-compose.yaml` for your host.
