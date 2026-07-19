# Deployment templates

Three ready-to-use docker-compose layouts for the most common Libra OS
deployment shapes. Each has its own `.env.example`, `docker-compose.yml`,
`verify.sh`, and a deployment-specific README.

| Template | Use when |
|---|---|
| [`local-dev/`](local-dev/) | Single host, laptop or demo box. HTTP only, no TLS. Operator is the only user. |
| [`single-host-prod/`](single-host-prod/) | Single host, real partner traffic. Includes nginx + TLS termination with operator-managed certs (Let's Encrypt etc.). |
| [`partner-tls-terminated/`](partner-tls-terminated/) | Partner already has a TLS-terminating reverse proxy upstream (Cloudflare Tunnel, AWS ALB, Caddy, K8s ingress, corporate LB). Libra OS runs HTTP internally; partner's existing infra handles TLS + WAF. |

All three:

1. Copy `.env.example` → `.env`, fill in the required values
2. `docker compose up -d`
3. `./verify.sh` to confirm the deployment is green
4. On any FAIL line, the `fix:` hint points at the specific env var or command

`verify.sh` runs three or four layers of checks depending on the
template, ending with `docker exec nova-os nova-os doctor deployment`
which audits ~10 correctness signals from inside the container.

## Picking a template

```
                  ┌─ "I run this on my laptop" ──────► local-dev/
                  │
   New deploy ────┼─ "I have one host I control end-to-end" ───► single-host-prod/
                  │
                  └─ "I'm wiring Libra OS into existing infra" ─► partner-tls-terminated/
```

If you outgrow `local-dev/`, move to `single-host-prod/` by adding nginx
+ certs and re-pointing `NOVA_OS_PUBLIC_URL` at the new HTTPS hostname.
The data volumes are compatible — `docker compose down` (no `-v`)
in `local-dev/`, then `up -d` in `single-host-prod/` against the same
host preserves Postgres, SurrealDB, and MongoDB state.
