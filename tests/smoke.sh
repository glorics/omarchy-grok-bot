#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
bash "$root/bin/run-capped" python3 "$root/status.py" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for key in ("ok", "installed", "source", "statusText", "productUrl", "signedIn", "computerLabel"):
    assert key in data, key
assert data.get("source") in ("official", "package", "path", "none"), data.get("source")
print("status.py ok · installed=%s source=%s status=%s version=%s" % (
    data.get("installed"), data.get("source"), data.get("statusText"), data.get("appVersion")))
'
got=$(python3 -c 'print("A"*300000)' | wc -c)
capped=$(set +o pipefail; GLORICS_MAX_BYTES=65536 bash "$root/bin/run-capped" python3 -c 'print("A"*300000)' 2>/dev/null | wc -c)
test "$capped" -le 65536
test "$got" -gt 65536
echo "run-capped ok · $capped bytes (limit 65536)"

if command -v omarchy >/dev/null; then
  omarchy plugin validate "$root"
  echo "omarchy plugin validate ok"
fi
