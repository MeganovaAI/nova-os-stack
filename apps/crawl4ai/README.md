# crawl4ai companion app

Page fetcher with strong handling of JavaScript-heavy SPAs. Pairs well with SearXNG: SearXNG returns the result list, crawl4ai enriches the top-N hits with full-page Markdown.

Image: [`unclecode/crawl4ai`](https://github.com/unclecode/crawl4ai) — Apache-2.0.

## Bring up

```bash
docker compose -f docker-compose.yml -f apps/crawl4ai/docker-compose.yaml up -d
```

API will be available on `http://localhost:11235`.

## Wire to Libra OS

Add to the root `.env`:

```
CRAWL4AI_URL=http://crawl4ai:11235
```

Then `docker compose up -d nova-os`. Verify:

```bash
curl -sS -X POST http://localhost:11235/crawl \
  -H 'Content-Type: application/json' \
  -d '{"urls":["https://example.com"],"crawler_params":{"headless":true},"extraction_strategy":{"type":"NoExtractionStrategy"}}' | head -c 500
```

## Known limitation

crawl4ai returns HTTP 500 with a "minimal_text, no_content_elements" anti-bot false-positive on `application/pdf` content. Pair with [Firecrawl](../firecrawl) (or [Docling](../docling) for ingestion-time PDF parsing) if you need PDF support — Libra OS's `RoutingFetcher` automatically routes `*.pdf` URLs to Firecrawl when both are configured.
