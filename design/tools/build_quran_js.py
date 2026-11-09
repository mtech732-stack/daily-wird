#!/usr/bin/env python3
"""يولّد design/shared/quran.js من data/quran-boundaries.json (الجدول المعتمد بعد القرار 12).
لا يغيّر شيئاً في الحدود؛ ينقلها كما هي لتقرأها صفحات التصميم المرجعية.
التشغيل من جذر المستودع:  python3 design/tools/build_quran_js.py
"""
import hashlib, json, pathlib
root = pathlib.Path(__file__).resolve().parents[2]
src = root / "data" / "quran-boundaries.json"
raw = src.read_bytes()
d = json.loads(raw)
out = {
    "source": "data/quran-boundaries.json",
    "sha256": hashlib.sha256(raw).hexdigest(),
    "quarters": [{k: q[k] for k in ("n", "hizb", "juz", "first", "last", "firstPage", "lastPage", "suras")} for q in d["quarters"]],
    "suras": {s["n"]: s["name"] for s in d["suras"]},
    "pages": [p["first"] for p in d["pages"]],
}
js = "// مولَّد آلياً من data/quran-boundaries.json · لا يُعدَّل باليد\nwindow.QURAN=" + json.dumps(out, ensure_ascii=False, separators=(",", ":")) + ";\n"
(root / "design" / "shared" / "quran.js").write_text(js, encoding="utf-8")
print("quran.js:", len(out["quarters"]), "أرباع ·", len(out["suras"]), "سورة · sha256", out["sha256"][:12])
