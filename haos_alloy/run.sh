#!/bin/sh
# HAOS Alloy entrypoint. Starts as root only long enough to (1) read the app
# options and (2) learn the host journal's gid, then drops to uid 473 with that
# gid as its only group, no capabilities and no_new_privs, and execs Alloy.
#
# Why root at start: journald: true bind-mounts the host journal read-only and
# adds no group (supervisor/docker/app.py). The files are root:systemd-journal
# 0640, the gid is allocated when HAOS is built, and the manifest cannot set a
# user or groups. The machine-id directory is setgid, so its gid is the host's
# journal gid. The options file is also root-only.
set -eu

UID_RUN=473
OPTIONS=/data/options.json

fail() { echo "FATAL: $*"; exit 1; }

# loki_url: a required option (schema url). Parsed without jq: one string key.
[ -r "$OPTIONS" ] || fail "$OPTIONS not readable"
LOKI_URL=$(sed -n 's/.*"loki_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$OPTIONS")
case "$LOKI_URL" in
    https://*|http://*) ;;
    *) fail "option loki_url must be an http(s) URL, got '${LOKI_URL}'" ;;
esac
case "$LOKI_URL" in
    *[[:space:]\"\\]*) fail "option loki_url contains whitespace, a quote or a backslash" ;;
esac
export LOKI_URL

command -v setpriv >/dev/null || fail "setpriv missing from image"

JDIR=
for d in /var/log/journal/*/; do
    [ -d "$d" ] && { JDIR=$d; break; }
done
[ -n "$JDIR" ] || fail "no journal under /var/log/journal (is journald: true set?)"
JGID=$(stat -c %g "$JDIR")
[ "$JGID" -ne 0 ] || fail "journal dir gid is 0, refusing to run with the root group"

# Alloy reports a healthy component and ships nothing when it cannot read the
# journal, so check the read here and stop loudly instead.
# shellcheck disable=SC2016 # $1 expands in the inner shell, by design
setpriv --reuid="$UID_RUN" --regid="$UID_RUN" --groups="$JGID" \
    sh -c 'head -c1 "$1"system.journal >/dev/null' _ "$JDIR" \
    || fail "uid $UID_RUN with gid $JGID cannot read ${JDIR}system.journal"

# A positive control: this line goes to the host journal under this app's
# identifier and must come back out of Loki.
echo "haos-alloy-canary $(date +%s)"

# Storage on /data so the journal position survives restarts and updates.
# Top directory only: Alloy creates everything below it as uid 473 (0700), and
# root here has no dac_override/dac_read_search under the AppArmor profile.
mkdir -p /data/alloy
chown "$UID_RUN:$UID_RUN" /data/alloy

echo "starting alloy as uid $UID_RUN, groups $JGID, no capabilities, pushing to $LOKI_URL"
exec setpriv --reuid="$UID_RUN" --regid="$UID_RUN" --groups="$JGID" \
    --inh-caps=-all --bounding-set=-all --no-new-privs \
    /bin/alloy run /etc/alloy/config.alloy --storage.path=/data/alloy \
    --disable-reporting
