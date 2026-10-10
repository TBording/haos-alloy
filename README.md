# HAOS Alloy

A Home Assistant OS app that ships the host journal (Core, Supervisor, plugins,
apps, kernel, AppArmor) to Loki with [Grafana Alloy](https://grafana.com/docs/alloy/),
running as a non-root process with no Supervisor API access.

## Install

1. Settings → Apps → App store → ⋮ → Repositories, add
   `https://github.com/TBording/haos-alloy`.
2. Install **HAOS Alloy**, set `loki_url`, and start it.

See [haos_alloy/DOCS.md](haos_alloy/DOCS.md) for configuration, the labels it
sends, how to check it works, and the security design.

## Images

Release images are published to `ghcr.io/tbording/haos-alloy` from a version
tag by [release.yml](.github/workflows/release.yml), signed with cosign keyless
and carrying SLSA provenance and SBOM attestations. Verify one with:

```sh
cosign verify ghcr.io/tbording/haos-alloy:<version> \
  --certificate-identity-regexp '^https://github.com/TBording/haos-alloy/\.github/workflows/release\.yml@refs/tags/v' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## License

Apache-2.0. Grafana Alloy is Apache-2.0 as well.
