#!/usr/bin/env python3
"""ينسخ لقطات اختبارات الواجهة من مجلّد التصدير إلى مجلّد الموقع بأسماء ثابتة.
الاستعمال: collect-shots.py <export-dir> <out-dir> <device-key> <appearance>
الاسم الناتج: <اسم اللقطة>__<device-key>__<appearance>.png
"""
import json, re, shutil, sys
from pathlib import Path

export, out, device, appearance = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], sys.argv[4]
out.mkdir(parents=True, exist_ok=True)
manifest = json.loads((export / "manifest.json").read_text())
count = 0
for test in manifest:
    for att in test.get("attachments", []):
        human = att.get("suggestedHumanReadableName", "")
        m = re.match(r"(\d\d-[a-z0-9-]+)", human)
        if not m:
            continue
        dst = out / f"{m.group(1)}__{device}__{appearance}.png"
        shutil.copy(export / att["exportedFileName"], dst)
        print("لقطة:", dst.name)
        count += 1
if count == 0:
    sys.exit("لا لقطات في " + str(export))
