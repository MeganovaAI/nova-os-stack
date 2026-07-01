# Nova OS on Kubernetes — multi-tenant by subdomain

Run many isolated Nova OS tenants on one cluster, each on its own subdomain
(`<tenant>.os.meganovaai.com`), with **onboarding a tenant = one values file**.

This is *infrastructure* multi-tenancy, not application multi-tenancy: every
tenant is its own stateless `nova-os` Deployment with its own database — the
cluster is shared, the tenants are not. That keeps the isolation you want
(independent data, schema, release cadence, blast radius) while consolidating
the ops of running many instances.

> **When to use this.** k8s earns its complexity at roughly 5–10+ operated
> tenants or a fast release cadence. Below that, a single VM with the
> `templates/single-host-prod` compose + an nginx/Caddy subdomain vhost is less
> moving parts. Adopt k8s when manual box management is the bottleneck — not by
> default.

## Architecture

```
                          *.os.meganovaai.com  (wildcard DNS → ingress LB)
                                    │
                       ┌────────────┴────────────┐   ingress-nginx + one
                       │      Ingress rules       │   wildcard TLS cert
        acme.…─────────┤ host → svc/nova-os-acme  ├─────── bosong.…
                       └────────────┬────────────┘
              ┌─────────────────────┼─────────────────────┐
       Deploy nova-os-acme    Deploy nova-os-bosong    …per tenant (stateless)
              │                     │
              └─────────┬───────────┘
                        ▼
        Shared Postgres (db-per-tenant)  +  Shared SurrealDB (ns-per-tenant)
```

- **nova-os** is stateless (settings live in its DB), so a tenant is a
  Deployment + Service + Ingress + a small PVC for writable files
  (`/data`: runtime agents, uploaded docs, rendered reports).
- **Datastores are shared by default** — one Postgres with a database per
  tenant, one SurrealDB with a namespace per tenant. Set via `database.*` /
  `surreal.*`. For a self-contained single tenant, flip `postgres.enabled` /
  `surrealdb.enabled` to bundle them inside the release instead.

## Prerequisites

- An ingress controller (defaults assume `ingress-nginx`).
- Wildcard DNS `*.os.meganovaai.com` → the ingress load balancer.
- A wildcard TLS cert for `*.os.meganovaai.com` in a Secret (issue once with
  cert-manager + a DNS-01 issuer, reused by every tenant): set
  `ingress.tls.wildcardSecretName`. Or drop it and add a cert-manager
  cluster-issuer annotation for per-host certs.
- A shared Postgres and SurrealDB reachable in-cluster (unless bundling).

### Per-tenant datastore provisioning (shared mode)

nova-os runs its own schema migrations on boot, but does **not** create its
database. Once per tenant:

```sql
-- on the shared Postgres
CREATE DATABASE acme OWNER nova;
```

SurrealDB namespaces/databases are created on first write, so no manual step —
just give each tenant a distinct `surreal.namespace` (defaults to the tenant
slug).

## Flow A — plain Helm, one release per tenant

```bash
helm upgrade --install acme ./helm/nova-os -n tenant-acme --create-namespace \
  -f ./helm/tenants/acme.yaml
```

Onboard another tenant: copy `helm/tenants/_example.yaml` → `acme.yaml`, edit,
`helm upgrade --install`.

## Flow B — GitOps, one file per tenant (recommended at scale)

```bash
kubectl apply -f ./helm/argocd/applicationset.yaml
```

Now **dropping `helm/tenants/<tenant>.yaml` into the repo creates the tenant**
(its own namespace `tenant-<name>`, served at `<tenant>.os.meganovaai.com`);
deleting the file removes it. The ApplicationSet renders `helm/nova-os` with
each tenant file. `[a-z]*.yaml` in the generator skips `_example.yaml`.

## Secrets

Never commit plaintext secrets. Either:
- **`secrets.existingSecret`** — reference a Secret you manage out-of-band
  (recommended; see `bosong.yaml`), or
- encrypt the tenant values file with **SOPS** or **sealed-secrets**.

Nova OS's boot security guard **refuses to start** unless:
`NOVA_OS_JWT_SECRET` (≥16 chars), `NOVA_OS_ADMIN_EMAIL` (not the old leaked
default), `NOVA_OS_ADMIN_PASSWORD` (≥12 chars) are set. The chart marks these
`required`.

## Key values

| Value | Purpose |
|---|---|
| `tenant` | Slug — drives resource names, subdomain, default db/namespace |
| `ingress.domain` / `ingress.host` | `<tenant>.<domain>`, or a full host override |
| `ingress.tls.wildcardSecretName` | Shared wildcard cert secret (reused by all tenants) |
| `database.*` / `secrets.databaseUrl` | Shared Postgres; per-tenant db = tenant slug |
| `surreal.url` / `surreal.namespace` | Shared SurrealDB; per-tenant namespace = tenant slug |
| `postgres.enabled` / `surrealdb.enabled` | Bundle datastores for a self-contained tenant |
| `models.*` | Per-tenant model routing (answer/brain/skill) |
| `extraEnv` | Vertical overlay toggles (e.g. `nova-os-school`) |
| `autoscaling.*` | Per-tenant HPA |
| `ipcLock` | CAP_IPC_LOCK — the k8s equivalent of compose `ulimits: memlock: -1` |

## Notes

- **memlock.** Go's EPOLLET netpoll is accounted against `RLIMIT_MEMLOCK`
  (default 64 KiB on many runtimes) and nova-os won't start when it's too low.
  `ipcLock: true` (default) adds `CAP_IPC_LOCK` to exempt it. On restricted
  clusters that forbid added capabilities, set `ipcLock: false` and raise the
  node runtime's default memlock ulimit.
- **The playground (#761) is separate.** A public try-it sandbox is *one*
  multi-tenant-lite instance (anonymous trials, hard rate limits), not a
  per-subdomain fleet member. Don't model it with this chart.
