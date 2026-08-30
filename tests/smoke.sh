#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$root/status.py" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for key in ("ok", "installed", "source", "statusText", "productUrl"):
    assert key in data, key
assert data.get("source") in ("official", "package", "path", "none"), data.get("source")
print("status.py ok · installed=%s source=%s status=%s version=%s" % (
    data.get("installed"), data.get("source"), data.get("statusText"), data.get("appVersion")))
'
if command -v omarchy >/dev/null; then
  omarchy plugin validate "$root"
  echo "omarchy plugin validate ok"
fi
