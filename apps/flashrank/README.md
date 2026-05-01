# FlashRank companion app

Cross-encoder reranker sidecar for Nova OS's knowledge retriever. Re-scores retrieved chunks after the RRF merge step, producing significantly more accurate relevance scores than embedding-only retrieval at the same compute budget.

Library: [flashrank](https://github.com/PrithivirajDamodaran/FlashRank) — MIT. CPU-only, ~22 MB model.

This app builds a small FastAPI wrapper around the `flashrank` Python library. The build context lives in [`flashrank/`](flashrank/) and is copied verbatim from the Nova OS marketplace reference.

## Bring up

```bash
docker compose -f docker-compose.yml -f apps/flashrank/docker-compose.yaml up -d
```

The first start downloads the model (~22 MB) and takes ~60s — wait for the healthcheck to pass.

## Wire to Nova OS

Add to the root `.env`:

```
FLASHRANK_URL=http://flashrank:8000
```

Then `docker compose up -d nova-os`. Nova OS auto-activates the FlashRank reranker when `FLASHRANK_URL` is set. Set `NOVA_OS_RERANKER=off` to disable even when the URL is configured.

## Pipeline position

FlashRank runs after RRF merge, before graph expansion. A sidecar error is non-fatal — the retriever falls back to the fused order and logs a warning.

## Model selection

Override `FLASHRANK_MODEL` in `.env` to switch models. Available as of 2026-04:

- `ms-marco-MiniLM-L-12-v2` — default, ~34 MB, quality baseline.
- `ms-marco-TinyBERT-L-2-v2` — faster, slightly lower quality.
- `ms-marco-MultiBERT-L-12`, `rank-T5-flan`, `Splade_PP_en_v1` — specialised options.

## Smoke test

```bash
curl -s http://localhost:8002/health
curl -s -X POST http://localhost:8002/rerank \
  -H 'Content-Type: application/json' \
  -d '{"query":"capital of France","documents":["Paris is the capital","London is great"],"top_k":2}'
```
