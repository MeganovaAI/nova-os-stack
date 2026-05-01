# Networking

How the containers in this stack reach each other, and how to plug into an existing host network.

## The shared bridge network

The root `docker-compose.yml` creates a single user-defined bridge network named `nova-net` and attaches `nova-os`, `postgres`, and `surrealdb` to it.

Every companion app under `apps/` declares the same network as `external: true`. This means:

1. The root compose must come up **first** — it creates the network. Run `docker compose -f docker-compose.yml up -d` before any companion-app overlay.
2. Companion apps can reach each other and Nova OS by service name. From inside a container:
   - `http://nova-os:8900` — Nova OS API
   - `http://searxng:8080` — SearXNG (when running)
   - `http://crawl4ai:11235` — crawl4ai
   - `http://firecrawl-api:3002` — Firecrawl API
   - `http://docling:5001` — Docling
   - `http://flashrank:8000` — FlashRank
   - `phoenix:4317` — Phoenix OTLP gRPC

## Host port map (defaults)

| Service | Container port | Host port | Override env |
|---|---|---|---|
| Nova OS | 8900 | 8900 | `NOVA_OS_PORT` |
| LibreChat | 3080 | 3080 | `LIBRECHAT_PORT` |
| SearXNG | 8080 | 8888 | `SEARXNG_PORT` |
| crawl4ai | 11235 | 11235 | `CRAWL4AI_PORT` |
| Firecrawl API | 3002 | 3022 | `FIRECRAWL_PORT` |
| Docling | 5001 | 5001 | `DOCLING_PORT` |
| FlashRank | 8000 | 8002 | `FLASHRANK_PORT` |
| Phoenix UI | 6006 | 6006 | `PHOENIX_UI_PORT` |
| Phoenix OTLP gRPC | 4317 | 4317 | `PHOENIX_GRPC_PORT` |
| Phoenix OTLP HTTP | 4318 | 4318 | `PHOENIX_HTTP_PORT` |

Postgres, SurrealDB, MongoDB (LibreChat), Redis / RabbitMQ / Postgres (Firecrawl) are **not** published to the host. They stay on `nova-net`.

## Reverse-proxy in front of Nova OS

Most production deploys put nginx, Caddy, or Traefik in front of Nova OS to terminate TLS and route subpaths. Two key requirements:

1. **`NOVA_OS_PUBLIC_URL` must match the user-facing URL** (e.g. `https://nova-os.your-company.example`). It's used as the OIDC issuer claim — mismatches break SSO into LibreChat or any other OIDC client.
2. **Server-Sent Events**: Nova OS streams chat completions over SSE. Disable proxy buffering on streaming endpoints. For nginx:

   ```nginx
   location /v1/ {
       proxy_pass http://localhost:8900;
       proxy_http_version 1.1;
       proxy_buffering off;
       gzip off;
       chunked_transfer_encoding off;
       add_header X-Accel-Buffering no;
   }
   ```

   Without these, Cloudflare and HTTP/2 proxies can buffer responses and produce `ERR_HTTP2_PROTOCOL_ERROR` in the browser.

A complete nginx + Caddy + Traefik example lives in the [Install guide](https://docs.meganova.ai/nova-os/install).

## Joining an existing Docker network

If you already have a `traefik-net` or similar, attach Nova OS to it as well by editing the root compose:

```yaml
services:
  nova-os:
    networks:
      - nova-net
      - traefik-net

networks:
  traefik-net:
    external: true
```

`nova-net` should remain to keep companion apps reachable.
