# LibreChat companion app

A drop-in chat UI for Nova OS, wired through:

- The OpenAI-compatible `/v1/chat/completions` endpoint Nova OS exposes (the `Nova OS` custom endpoint in `librechat.yaml` points at `http://nova-os:8900/v1`).
- Nova OS's built-in OIDC provider for single sign-on (`OPENID_*` envs in `docker-compose.yaml`).

Image: [`ghcr.io/danny-avila/librechat`](https://github.com/danny-avila/LibreChat) — MIT licensed.

## Setup

```bash
cp apps/librechat/.env.example apps/librechat/.env
# Fill in the 5 required secrets — see .env.example for generation hints.
```

Register `librechat` as an OIDC client in Nova OS (Settings → OIDC), set the client secret to the value you put in `NOVA_OS_OIDC_CLIENT_SECRET`, and add the redirect URI `${LIBRECHAT_PUBLIC_URL}/oauth/openid/callback`. Step-by-step in [`docs/oidc-setup.md`](../../docs/oidc-setup.md).

## Bring up

```bash
docker compose -f docker-compose.yml -f apps/librechat/docker-compose.yaml up -d
```

LibreChat will be available on `http://localhost:3080` (override the host port via `LIBRECHAT_PORT`).

## Issuing a Nova OS API key

LibreChat needs a Nova OS API key (`NOVA_OS_API_KEY`) so it can call the `/v1/chat/completions` endpoint on behalf of authenticated users. Issue one in the Nova OS dashboard under **Settings → API Keys**, then paste it into `apps/librechat/.env`.

## Customising

- `librechat.yaml` defines the model list shown in the UI. Add or remove agent IDs as needed — they must match agents declared in Nova OS.
- `APP_TITLE` and `CUSTOM_FOOTER` (in `.env`) control the page title and footer copy.
- `ALLOW_REGISTRATION=false` disables self-signup once you have your initial users.

## Concurrency note

`CONCURRENT_MESSAGE_MAX` defaults to `5` in this compose. The upstream LibreChat default of `2` causes 429s when a retry arrives during a long deep-research call.
