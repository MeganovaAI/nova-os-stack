# Hermes companion app

NousResearch [Hermes Agent](https://github.com/NousResearch/hermes-agent) gateway bridge for Nova OS.

Image: `nousresearch/hermes-agent` — Apache-2.0.

## Bring up

```bash
docker compose -f docker-compose.yml -f apps/hermes/docker-compose.yaml up -d
```

Persistent state is kept in `apps/hermes/hermes-data/` on the host.

## Notes

This bridge is optional and only useful if you've adopted the Hermes agent ecosystem on the partner side. The container runs `gateway run` and joins Nova OS's network so `nova-os` can reach it by name.
