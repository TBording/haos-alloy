# HAOS Alloy

Ships the Home Assistant OS host journal to Loki with Grafana Alloy: Core,
the Supervisor and its plugins, every app's log, the kernel and AppArmor
(`audit`) lines.

## Configuration

| Option | Required | Meaning |
|---|---|---|
| `loki_url` | yes | Loki push endpoint, e.g. `https://loki.example/loki/api/v1/push`. No auth or tenant header is sent. |

The app's containers resolve names through the Supervisor DNS plugin. If the
Loki host is only in a local DNS zone, make sure that resolver is asked
first: `ha dns options --servers dns://<local-resolver>`.

## What it sends

Every journal entry, labelled:

- `host="haos"`, `job="haos-journal"`
- `syslog_identifier`: `homeassistant` for Core, `hassio_supervisor`,
  `hassio_dns`, …, `app_<slug>` for each app, `kernel`, `audit`
- `unit`: the systemd unit where there is one

The first start sends the last hour. After that, the journal position is kept
under `/data`, so restarts and updates resume where they stopped.

## Checking it works

Alloy reports itself healthy and ships nothing if it cannot read the
journal or reach Loki, and Loki push errors are logged only at debug level.
So check Loki, not the app log:

- On every start the app prints `haos-alloy-canary <epoch>`. Query
  `{host="haos", job="haos-journal"} |= "haos-alloy-canary <epoch>"`.
- Alert on absence, e.g. `sum(count_over_time({host="haos", job="haos-journal"}[10m])) < 1`
  with no data treated as alerting.

## Security

- No Supervisor or Core API access. `journald: true` gives a read-only mount of
  the host journal and nothing else.
- The entrypoint starts as root only to read the options and the journal's group
  id. It then drops to uid 473 with only that group, no capabilities and
  `no_new_privs` before Alloy starts.
- An enforce-mode AppArmor profile allows four capabilities, all for that drop
  (`setuid`, `setgid`, `setpcap`, `chown`). Writes are limited to `/data/alloy` and `/tmp`.
- Alloy's usage reporting is off (`--disable-reporting`). The Snowflake driver's
  native-library load is switched off (`SF_DISABLE_MINICORE`).
