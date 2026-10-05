# workstation-monitoring

A stateless OpenTelemetry collector for Linux workstations. One `docker compose up`
captures host metrics and kernel (dmesg) logs and ships them to the homelab
management-cluster OTel gateway over a Cloudflare tunnel. The collector persists
nothing locally, so it survives swapping workstations and Linux bases without
config changes.

## How it works

A single `otel/opentelemetry-collector-contrib` container:

- **host metrics** via the `hostmetrics` receiver, reading a read-only `/host`
  rootfs mount (`root_path: /host`) — CPU, memory, load, disk, filesystem,
  network, paging, processes.
- **container metrics** via `docker_stats` over the Docker socket.
- **kernel logs** via the `journald` receiver in `dmesg` mode, running the host's
  own `journalctl` through a chroot into `/host`. Running the host binary means the
  journalctl version always matches the running distro, so kernel-log capture works
  on any systemd base with no image rebuild.

Telemetry is tagged `source=workstation` and shipped OTLP/HTTP with gzip to the
gateway. Auth is a Cloudflare Access service token (two request headers); the tunnel
edge rejects anything unauthenticated before it reaches the cluster.

The collector runs as root with the host rootfs mounted read-only. That is the
minimum the journald chroot needs to run the host's journalctl; it is not
`privileged`.

## Prerequisites

- **Docker + Docker Compose** on the host.
- **Persistent journald.** Kernel messages must survive a hard crash and reboot, so
  the host needs persistent storage:

  ```
  sudo mkdir -p /var/log/journal && sudo systemctl restart systemd-journald
  ```

  Real-time shipping already captures the messages leading up to a crash; this is
  the backstop for the final moments before a hard lockup.
- **Azure service-principal secret.** `CLIENT_SECRET` is supplied out-of-band
  (export it or put it in `.env`); it authenticates the Key Vault pull.
- **The Cloudflare Access token already in Key Vault**
  (`workstation-otel-cf-access-client-id` / `-secret`). `mise run pull-secrets`
  fails loud if it is missing.

## Quick start

```
mise run bootstrap-env     # seed .env with the required keys
export CLIENT_SECRET=...    # the Azure SP secret (or edit .env)
mise run pull-secrets       # pull the CF Access token from Key Vault into .env
docker compose up -d
```

## Secrets

Secrets reach the host through the same mise + Azure Key Vault flow as the
management cluster. `.env` is gitignored; only `.env.example` (keys, no values) is
tracked. Shell-exported values take precedence over `.env`.

## App telemetry on this workstation

The collector also receives OTLP/HTTP from apps running on the same workstation, published on `127.0.0.1:4318` only, so nothing off-host can reach it. Browser-hosted apps preflight the OTLP POST, so the receiver answers CORS for the allowed app origins listed under `receivers.otlp.protocols.http.cors` in `config.yaml`; add an origin there rather than widening to `*`. App traces and metrics go through their own pipelines (`traces/apps`, `metrics/apps`) so the app's own `service.name` survives; the collector only tags them with `source=workstation` and the workstation name.
