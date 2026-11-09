#!/usr/bin/env bash
# يطبع معرّف محاكٍ بعينه: الاسم ونسخة iOS مثبّتان. يفشل إن لم يوجد.
# الاستعمال: scripts/sim-udid.sh "iPhone 17 Pro Max" 26.5
set -euo pipefail
name="$1"; os="$2"
runtime="com.apple.CoreSimulator.SimRuntime.iOS-${os//./-}"
xcrun simctl list devices available -j | python3 -c '
import json, sys
name, runtime = sys.argv[1], sys.argv[2]
devs = json.load(sys.stdin)["devices"].get(runtime, [])
hits = [d["udid"] for d in devs if d["name"] == name]
if not hits:
    sys.stderr.write(f"لا محاكي: {name} على {runtime}\nالمتاح: {[d[\"name\"] for d in devs]}\n")
    sys.exit(1)
print(hits[0])
' "$name" "$runtime"
