# HAOS Alloy image. Released images are built by .github/workflows/release.yml;
# a local build (folder in /local_apps) works too. No BUILD_FROM (not provided
# since Supervisor 2026.04.0), so FROM is explicit.
#
# Base pinned by the multi-arch index digest for grafana/alloy v1.20.1
# (Docker Hub and registry-1 both return sha256:2aa2099a...; verified).
FROM grafana/alloy:v1.21.0@sha256:9726bfba078de9bc2212c60c6e643238c700b4fe0868ea78cbe03163d03d95bf

ARG BUILD_ARCH
ARG BUILD_VERSION=dev
ARG BUILD_REVISION=unknown

LABEL \
    io.hass.type="app" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.title="HAOS Alloy" \
    org.opencontainers.image.description="Grafana Alloy shipping the HAOS host journal to Loki" \
    org.opencontainers.image.version="${BUILD_VERSION}" \
    org.opencontainers.image.revision="${BUILD_REVISION}" \
    org.opencontainers.image.licenses="Apache-2.0" \
    org.opencontainers.image.source="https://github.com/TBording/haos-alloy"

# Pick up Ubuntu security fixes newer than the pinned base (grype in CI fails
# on fixable high findings; grafana/alloy's own Dockerfile upgrades too).
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Alloy links the Snowflake driver, which at start extracts a native library to
# /tmp and mmaps it executable. This app never talks to Snowflake, and the
# AppArmor profile denies exec-mmap on /tmp; this switch skips the attempt
# (snowflakedb/gosnowflake minicore.go, disableMinicoreEnv).
ENV SF_DISABLE_MINICORE=true

COPY config.alloy /etc/alloy/config.alloy
COPY run.sh /run.sh
RUN chmod 0755 /run.sh && chmod 0644 /etc/alloy/config.alloy

# No USER line on purpose: run.sh starts as root only to read the host journal's
# gid from the mounted directory, then setpriv drops to uid 473 (the upstream
# "alloy" user) with that gid as its only supplementary group and no
# capabilities. A static USER cannot carry a gid allocated at HAOS build time.

# Override upstream ENTRYPOINT (/bin/alloy) so run.sh can print diagnostics first.
ENTRYPOINT ["/run.sh"]
CMD []
