"""Fail CI if the manifest or AppArmor profile drifts from the app's privilege design.

Standard library only (the runner's python3 has no PyYAML), so config.yaml is
checked by top-level key, which is all these rules need.
"""
import re
import sys

APP = "haos_alloy"
config = open(f"{APP}/config.yaml").read()
profile = open(f"{APP}/apparmor.txt").read()
top = {m.group(1): m.group(2).strip() for m in re.finditer(r"(?m)^([a-z_]+):(.*)$", config)}
bad = []

for key, want in (("journald", "true"), ("apparmor", "true"), ("init", "false")):
    if top.get(key) != want:
        bad.append(f"{key} must be {want}")
for key in ("hassio_api", "hassio_role", "homeassistant_api", "host_network", "host_pid",
            "host_ipc", "privileged", "devices", "full_access", "map", "ports", "uart", "usb"):
    if key in top:
        bad.append(f"{key} must not be set")
if not re.search(r"(?m)^  loki_url: null$", config):
    bad.append("options.loki_url must default to null (no internal hostname in a public repo)")

profiles = re.findall(r"(?m)^profile .*$", profile)
if len(profiles) != 1:
    bad.append("apparmor.txt needs exactly one line starting with 'profile'")
elif "complain" in profiles[0]:
    bad.append("AppArmor profile is in complain mode")
if re.search(r"(?m)^\s*(capability|file|network)\s*,", profile):
    bad.append("blanket capability/file/network rule in apparmor.txt")
caps = set(re.findall(r"(?m)^\s*capability\s+(\w+)\s*,", profile))
if caps != {"setuid", "setgid", "setpcap", "chown"}:
    bad.append(f"capability set changed: {sorted(caps)}")

if bad:
    sys.exit("\n".join(bad))
print("manifest and AppArmor profile OK")
