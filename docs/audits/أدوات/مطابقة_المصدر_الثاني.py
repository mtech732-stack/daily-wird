#!/usr/bin/env python3
"""المدقّق · ش0 · المرحلة 5: مطابقة جدول الحدود بمصدر ثانٍ (6.3 البند 2).

المصدر الثاني: بيانات Quran.com (واجهة API الإصدار 4: rub_el_hizb_number وhizb_number وjuz_number وpage_number لكل آية)،
كما نُشرت سورةً سورةً في المستودع wisnuwiry/alquran-id عند الإيداع b0b0265 (المجلّد app/data/).
الاستعمال:
  git clone https://github.com/wisnuwiry/alquran-id && git -C alquran-id checkout b0b0265
  python3 -I مطابقة_المصدر_الثاني.py alquran-id/app/data data/quran-boundaries.json
تقرأ الأداة كل ملف سورة في المجلّد بحقل id فيه، أيّاً كان اسمه، وتتجاهل ما ليس سورة (مثل chapters.json).
وتطبع بصمة المصدر: sha256 لمحتوى ملفات السور الـ114 متتابعةً بترتيب id.
"""
import hashlib
import json
import sys
from pathlib import Path

src, table = Path(sys.argv[1]), json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
files = {}
for f in sorted(src.glob("*.json")):
    d = json.loads(f.read_text(encoding="utf-8"))
    if isinstance(d, dict) and "verses" in d and "id" in d:
        files[d["id"]] = (f, d)
assert sorted(files) == list(range(1, 115)), "يلزم 114 ملف سورة"
h = hashlib.sha256()
for i in range(1, 115):
    h.update(files[i][0].read_bytes())
print("بصمة المصدر:", h.hexdigest())
V = {}
for i in range(1, 115):
    for v in files[i][1]["verses"]:
        s, a = map(int, v["verse_key"].split(":"))
        V[(s, a)] = v
assert len(V) == 6236
first, last, pfirst = {}, {}, {}
for k in sorted(V):
    r = V[k]["rub_el_hizb_number"]
    first.setdefault(r, k)
    last[r] = k
    pfirst.setdefault(V[k]["page_number"], k)

picks = [106 if j == 14 else 8 * (j - 1) + ((j - 1) % 8) + 1 for j in range(1, 31)]
bad = []
for n in picks:
    q = table["quarters"][n - 1]
    a, b = first[n], last[n]
    if not (tuple(q["first"]) == a and tuple(q["last"]) == b
            and (q["firstPage"], q["lastPage"]) == (V[a]["page_number"], V[b]["page_number"])
            and q["hizb"] == V[a]["hizb_number"] and q["juz"] == V[a]["juz_number"]):
        bad.append(n)
print(f"العيّنة: {len(picks) - len(bad)} من {len(picks)} مطابقة، تغطّي {len({table['quarters'][n-1]['juz'] for n in picks})} جزءاً", bad or "")
allq = [n for n in range(1, 241) if tuple(table["quarters"][n - 1]["first"]) != first[n]]
allp = [p["n"] for p in table["pages"] if tuple(p["first"]) != pfirst[p["n"]]]
print(f"فوق العيّنة: بدايات الأرباع الـ240 المختلفة {allq or 0} · بدايات الأوجه الـ604 المختلفة {allp or 0}")
sys.exit(1 if bad or allq or allp else 0)
