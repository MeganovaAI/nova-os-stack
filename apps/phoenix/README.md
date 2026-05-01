# Phoenix companion app

[Arize Phoenix](https://github.com/Arize-ai/phoenix) — open-source LLM observability platform. Receives OpenTelemetry (OTLP) traces from Nova OS and visualises them as a structured span tree: every ingest job, retrieval call, and tool invocation as a node.

Image: `arizephoenix/phoenix` — **ELv2** (Elastic License 2.0). Self-hosting permitted; SaaS redistribution requires a commercial agreement with Arize.

## Bring up

```bash
docker compose -f docker-compose.yml -f apps/phoenix/docker-compose.yaml up -d
```

- UI: <http://localhost:6006>
- OTLP gRPC receiver: `:4317` (what Nova OS connects to)
- OTLP HTTP receiver: `:4318` (alternative)

## Wire to Nova OS

Add to the root `.env`:

```
OTEL_EXPORTER_OTLP_ENDPOINT=phoenix:4317
```

Then `docker compose up -d nova-os`. Trigger any chat / search / ingest action — traces should appear in the Phoenix UI within seconds.

## What Nova OS traces

| Span | OpenInference kind | Where |
|---|---|---|
| `ingest.process` | CHAIN | per-file: outer span wrapping parse → chunk → store |
| `ingest.parse` | _(child)_ | parser name + MIME type + bytes |
| `ingest.chunk` | _(child)_ | chunker name + chunk count |
| `ingest.store` | _(child)_ | backend + collection + chunk count |
| `retrieval.retrieve` | RETRIEVER | outer span: query + top_k + doc IDs |
| `retrieval.search.vector` | _(child)_ | per-collection vector search |
| `retrieval.search.bm25` | _(child)_ | per-collection BM25 fallback |
| `retrieval.fuse` | _(child)_ | RRF merge: input lists + fused count |
| `retrieval.rerank` | _(child)_ | reranker name + counts |
| `retrieval.filter` | _(child)_ | scope filter or LLM relevance filter |
| `agent.tool_call` | TOOL | `knowledge_search` tool handler |

## No-op when disabled

When `OTEL_EXPORTER_OTLP_ENDPOINT` is unset, span creation costs a few nanoseconds and no goroutines are launched. Production deployments that don't need tracing pay essentially zero overhead — no need to remove the wiring code.

## Other OTLP backends

Phoenix speaks standard OTLP. You can point Nova OS at Grafana Tempo (`tempo:4317`), LangSmith, Langtrace, or any OTLP collector by changing only the `OTEL_EXPORTER_OTLP_ENDPOINT` value — no code changes.
