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

if grep -n 'capture_output=True' "$root/status.py"; then
  echo "status.py still uses capture_output=True" >&2
  exit 1
fi
python3 - "$root" <<'PY'
import os, stat, sys, tempfile
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import status as grok

proc = grok.run(["python3", "-c", "print('A'*200000)"], timeout=5, max_bytes=4096)
assert len(proc.stdout.encode()) <= 4096, len(proc.stdout)
assert proc.returncode != 0
print("producer cap ok · %d bytes rc=%s" % (len(proc.stdout), proc.returncode))

base = Path(tempfile.mkdtemp())
secret = base / "secret"
secret.mkdir()
marker = secret / "owned"
marker.write_text("keep")
os.chmod(secret, 0o755)
planted = base / "state"
planted.symlink_to(secret)
assert grok.ensure_private_dir(planted)
assert planted.is_dir() and not planted.is_symlink()
assert marker.read_text() == "keep"
assert stat.S_IMODE(secret.stat().st_mode) == 0o755
print("state dir ok · symlink not followed")
PY

if command -v omarchy >/dev/null; then
  omarchy plugin validate "$root"
  echo "omarchy plugin validate ok"
fi
