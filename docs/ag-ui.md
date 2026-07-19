# AG-UI — agent ↔ UI streaming protocol

Libra OS speaks [AG-UI 1.0.0](https://docs.ag-ui.com/concepts/events) as an opt-in alternative streaming shape on the chat endpoint. This page documents how to point an AG-UI-compatible client (the most common being [CopilotKit](https://www.copilotkit.ai)) at a running Libra OS.

> **Adopted via [issue #370](https://github.com/MeganovaAI/nova-os/issues/370).** AG-UI is the standardised wire format; CopilotKit is the React SDK most commonly used to consume it. Libra OS picked AG-UI to avoid inventing a custom event format when an industry standard already exists.

## When to use AG-UI vs LibreChat

| Use case | Recommended |
|---|---|
| First-time evaluator / quickstart demo | LibreChat (`apps/librechat/`) — already wired via OIDC + OpenAI-compat |
| Embedding chat into an existing React app | CopilotKit + AG-UI |
| Building a custom branded UI from scratch | CopilotKit + AG-UI (or any AG-UI client) |
| Backend agent-to-agent integration | Don't need either — use `/v1/chat/completions` directly |

LibreChat consumes Libra OS's OpenAI-compatible `/v1/chat/completions`. CopilotKit consumes the AG-UI shape on `/agents/v1/:api_key/chat`. They're parallel paths, both supported permanently.

## Opting into AG-UI on the wire

The Libra OS chat endpoint defaults to a backward-compatible shape (the [issue #99](https://github.com/MeganovaAI/nova-os/issues/99) event format). To get AG-UI 1.0.0 events instead, the client must opt in **per request**, either via header or request body:

**Header form (preferred):**
```http
POST /agents/v1/<api_key>/chat HTTP/1.1
Content-Type: application/json
X-Protocol: ag-ui

{"messages": [{"role": "user", "content": "Hello"}]}
```

**Body form (for clients that can't set custom headers):**
```json
{
  "messages": [{"role": "user", "content": "Hello"}],
  "metadata": {"protocol": "ag-ui"}
}
```

Either opts the response into the AG-UI shape. The server adds `X-AG-UI-Version: 1.0.0` as a response header so clients can negotiate compatibility without guessing.

## Event shapes

Per the [AG-UI spec](https://docs.ag-ui.com/concepts/events), every SSE event is a JSON object with a `type` field plus event-specific payload. Libra OS emits these event types:

**Lifecycle:** `RUN_STARTED` (`threadId`, `runId`) → ... → `RUN_FINISHED` (`outcome.type: "success"`) or `RUN_ERROR` (`message`, `code`).

**Text streaming:** `TEXT_MESSAGE_START` (`messageId`, `role: "assistant"`) → `TEXT_MESSAGE_CONTENT` (`messageId`, `delta`) × N → `TEXT_MESSAGE_END` (`messageId`).

**Reasoning** (the thinking channel; renamed from `THINKING_*` to `REASONING_*` in early 2026 per spec churn): same start/content/end shape with `messageId`.

**Tool calls:** `TOOL_CALL_START` (`toolCallId`, `toolCallName`) → `TOOL_CALL_ARGS` (`toolCallId`, `delta` as serialized JSON chunk) × N → `TOOL_CALL_END` (`toolCallId`) → `TOOL_CALL_RESULT` (`toolCallId`, `content`).

Wire field names use camelCase to match the AG-UI spec verbatim. Libra OS internals stay snake_case and translate at the emission boundary.

## CopilotKit integration recipe

CopilotKit ships React hooks + pre-built UI components that consume AG-UI. You'll need an existing React app (Next.js, Vite, CRA, anything).

### Install

```bash
npm install @copilotkit/react-core @copilotkit/react-ui
```

### Wire to Libra OS

```tsx
// app/copilot-provider.tsx
import { CopilotKit } from "@copilotkit/react-core";
import { CopilotChat } from "@copilotkit/react-ui";
import "@copilotkit/react-ui/styles.css";

const NOVA_OS_URL = import.meta.env.VITE_NOVA_OS_URL ?? "http://localhost:8900";
const NOVA_OS_API_KEY = import.meta.env.VITE_NOVA_OS_API_KEY ?? "default";

export function ChatPanel() {
  return (
    <CopilotKit
      runtimeUrl={`${NOVA_OS_URL}/agents/v1/${NOVA_OS_API_KEY}/chat`}
      // Opt into the AG-UI shape on every request CopilotKit issues.
      headers={{ "X-Protocol": "ag-ui" }}
    >
      <CopilotChat
        labels={{
          title: "Libra OS",
          initial: "How can I help?",
        }}
      />
    </CopilotKit>
  );
}
```

### Auth

For authenticated chats (`NOVA_OS_AUTH_ENABLED=true`, the default), pass a JWT bearer:

```tsx
<CopilotKit
  runtimeUrl={`${NOVA_OS_URL}/agents/v1/${NOVA_OS_API_KEY}/chat`}
  headers={{
    "X-Protocol": "ag-ui",
    "Authorization": `Bearer ${userJwt}`,
  }}
>
```

The JWT comes from either Libra OS's OIDC provider (`/oauth/authorize` → `/oauth/token`) or from the dashboard login (`POST /api/auth/login` → `access_token`). See `docs/oidc-setup.md` for the OIDC route.

### Pointing at a specific agent

The default API key route lands on the default agent. To target a specific app-scoped agent (per the [multi-app primitive](../README.md#multi-app-primitive-v017)):

```tsx
runtimeUrl: `${NOVA_OS_URL}/v1/apps/<app_name>/agents/<agent_id>/chat`
```

## Verifying it works

From the browser devtools network tab while CopilotKit is streaming:
- Request URL ends in `/chat`
- Request header `X-Protocol: ag-ui` is present
- Response header `X-AG-UI-Version: 1.0.0` is present
- Response body is `text/event-stream` with `data: {"type":"RUN_STARTED",...}` lines

If you see `data: {"type":"content",...}` or `data: {"type":"pipeline_start",...}` instead, the request did NOT opt into AG-UI — Libra OS fell back to the default shim shape. Double-check the header / body field.

## Spec versioning

The `X-AG-UI-Version` response header (`1.0.0`) lets clients pin to a known shape. Upstream AG-UI spec changes that rename event types (the early-2026 `THINKING_*` → `REASONING_*` rename was one such) bump the version; Libra OS pins per-release and updates in lockstep with its [release notes](https://docs.meganova.ai/nova-os/releases).

## Cross-references

- **AG-UI spec:** <https://docs.ag-ui.com/concepts/events>
- **CopilotKit:** <https://www.copilotkit.ai> + <https://github.com/CopilotKit/CopilotKit>
- **Libra OS adoption issue:** [MeganovaAI/nova-os#370](https://github.com/MeganovaAI/nova-os/issues/370)
- **Backward-compat event shape** (the default when AG-UI not requested): [MeganovaAI/nova-os#99](https://github.com/MeganovaAI/nova-os/issues/99)
- **For a working chat UI without writing React:** see [`apps/librechat/`](../apps/librechat/) — it consumes the OpenAI-compatible endpoint, not AG-UI, but it's one `docker compose up` away.

## A note on what this isn't

CopilotKit is a React SDK, not a standalone container. There's no `docker compose up copilotkit` — you embed CopilotKit's components into your own React app (the recipe above). For a turnkey chat UI in this stack, use LibreChat. For a custom UI in your existing app, use CopilotKit + this recipe.
