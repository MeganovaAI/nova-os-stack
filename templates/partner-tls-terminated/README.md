# Partner TLS-Terminated Template

For partner deployments where an **external reverse proxy** terminates
TLS upstream of this host — Cloudflare Tunnel, corporate load balancer,
Caddy / Traefik on a separate host, AWS ALB, Kubernetes ingress, etc.
Nova OS runs HTTP-only internally; the partner's existing infrastructure
handles the TLS termination + WAF + rate limiting.

## Topology

```
                  ┌──── public internet ────┐
                  │                          │
                  │  https://nova.partner.com│
                  │                          │
                  └────────────┬─────────────┘
                               │  (TLS terminates here)
                               ▼
              ┌──── Cloudflare / ALB / Caddy ────┐
              │   (operated by the partner)      │
              └────────────────┬─────────────────┘
                               │ HTTP (private network)
                               ▼
                      this host's :8900
                               │
                       ┌───────┴──────┐
                       │              │
                  nova-os         librechat
                       │
              ┌────────┴────────┐
              │                 │
          postgres         surrealdb
```

## When to use this template

- Partner already has a TLS-terminating reverse proxy they want to keep
  (Cloudflare Tunnel, F5, AWS ALB, internal Caddy, K8s ingress)
- Partner's security policy requires WAF / rate limiting / IP allow-list
  upstream of containers they run
- Partner runs Nova OS on a host without public exposure (private subnet
  with private routing)
- You want to avoid managing TLS certs from inside the docker-compose

## Setup

```bash
cp .env.example .env
# edit .env: NOVA_OS_PUBLIC_URL=https://nova.partner.com (the public URL
#            their reverse proxy advertises), OPENAI_API_KEY=..., etc.
docker compose up -d
./verify.sh
```

The compose binds nova-os :8900 + librechat :3080 to `0.0.0.0` —
partner's reverse proxy reaches them via private routing on whatever
network they've configured. Tweak the `bind:` lines in `docker-compose.yml`
if you need to restrict to a specific interface.

## Reverse-proxy requirements

The external proxy MUST:

1. **Pass `Host` header verbatim** — Nova OS uses the request's Host to
   build OIDC redirect URIs. If the proxy rewrites Host, OIDC breaks.
2. **Forward `X-Forwarded-Proto: https`** — Nova OS reads this to decide
   if the link is secure. Without it, server-issued links may use `http://`.
3. **Disable response buffering** — SSE streaming requires chunks reach the
   client immediately. Cloudflare: turn off "Cache" on `/v1/`, `/agents/`,
   `/chat/`. ALB: idle timeout ≥ 600s. Caddy: `flush_interval -1`.
4. **Idle timeout ≥ 10 minutes** — long-running brain chats can take 3-5
   minutes. Heartbeats fire every 10s but some proxies count idle as
   "no data" regardless.
5. **Allow `Upgrade: websocket` headers** — LibreChat's UI uses WS for
   live chat.

Sample Cloudflare Tunnel config:

```yaml
# ~/.cloudflared/config.yml
tunnel: <tunnel-id>
credentials-file: /etc/cloudflared/<tunnel-id>.json
ingress:
  - hostname: nova.partner.com
    service: http://localhost:8900
    originRequest:
      noTLSVerify: true       # we're HTTP internally
      connectTimeout: 10s
      tcpKeepAlive: 30s
      keepAliveTimeout: 600s
      disableChunkedEncoding: false
  - service: http_status:404
```

Sample Caddy block:

```caddyfile
nova.partner.com {
    encode gzip
    reverse_proxy localhost:8900 {
        flush_interval -1
        transport http {
            response_header_timeout 600s
        }
    }
    handle /chat/* {
        reverse_proxy localhost:3080 {
            flush_interval -1
        }
    }
}
```

## verify.sh

Three layers (skips the cert-file check since TLS is upstream):

1. **HTTP probes** to local :8900 / :3080
2. **OIDC issuer match** — discovery doc issuer must equal
   `NOVA_OS_PUBLIC_URL` exactly (the partner's external URL)
3. **`nova-os doctor deployment`** — env vars, DB, gateway, agents

verify.sh does NOT probe the partner's external URL (they may have
auth in front), so a true end-to-end test requires the partner to
hit `${NOVA_OS_PUBLIC_URL}/health` from their network manually.

## URLs

After the partner points DNS + their reverse proxy at this host:

- LibreChat: `${NOVA_OS_PUBLIC_URL}/chat/`
- Dashboard: `${NOVA_OS_PUBLIC_URL}/admin/`
- API: `${NOVA_OS_PUBLIC_URL}/v1/`
