#!/usr/bin/env bash
# يطبع معرّف محاكٍ بعينه: الاسم ونسخة iOS مثبّتان. يفشل إن لم يوجد.
# الاستعمال: scripts/sim-udid.sh "iPhone 17 Pro Max" 26.5
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
xcrun simctl list devices available -j | python3 "$here/sim-udid.py" "$1" "$2"
