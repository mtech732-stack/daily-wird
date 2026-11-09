#!/usr/bin/env python3
"""يبني data/quran-boundaries.json من ملف «تنزيل» الوصفي data/source/tanzil-quran-data.xml.

لا يضيف حدّاً من خارج المصدر ولا يصحّح فيه شيئاً. كل ما يفعله:
- ينقل بداية كل وجه (604) وبداية كل ربع (240) واسم كل سورة وعدد آياتها (114) كما هي.
- يشتقّ آخر آية في كل ربع: الآية التي تسبق مباشرة أول آية في الربع الذي بعده (والربع 240 ينتهي بآخر المصحف 114:6).
- يشتقّ أول وجه وآخر وجه يمسّهما الربع: الآية تُنسب إلى الوجه الذي تبدأ فيه (فالمصدر يعطي بدايات الأوجه وحدها).
- يشتقّ السور التي يمسّها الربع، وأول ربع وآخر ربع يمسّان كل سورة.
- يشتقّ الحزب والجزء من رقم الربع (القسم 6.1): الحزب = ⌈الربع ÷ 4⌉، والجزء = ⌈الحزب ÷ 2⌉.
- يضيف أسماء الأجزاء بالعربية.

الاستعمال: python3 data/tools/build_boundaries.py
"""
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent
SRC = DATA / "source" / "tanzil-quran-data.xml"
OUT = DATA / "quran-boundaries.json"

JUZ_ORDINALS = [
    "الأول", "الثاني", "الثالث", "الرابع", "الخامس", "السادس", "السابع", "الثامن", "التاسع", "العاشر",
    "الحادي عشر", "الثاني عشر", "الثالث عشر", "الرابع عشر", "الخامس عشر",
    "السادس عشر", "السابع عشر", "الثامن عشر", "التاسع عشر", "العشرون",
    "الحادي والعشرون", "الثاني والعشرون", "الثالث والعشرون", "الرابع والعشرون", "الخامس والعشرون",
    "السادس والعشرون", "السابع والعشرون", "الثامن والعشرون", "التاسع والعشرون", "الثلاثون",
]


def read_source(path=SRC):
    root = ET.parse(path).getroot()
    suras = [(int(e.get("index")), e.get("name"), int(e.get("ayas")), int(e.get("start")))
             for e in root.iter("sura")]
    def starts(tag):
        return [(int(e.get("index")), (int(e.get("sura")), int(e.get("aya")))) for e in root.iter(tag)]
    return suras, starts("page"), starts("quarter")


def build(path=SRC):
    suras, pages, quarters = read_source(path)
    suras.sort(); pages.sort(); quarters.sort()
    ayas = {n: count for n, _, count, _ in suras}
    # الترتيب المطلق للآية في المصحف (0 … 6235)
    offset = {n: start for n, _, _, start in suras}
    total = sum(ayas.values())
    def abs_(ref): return offset[ref[0]] + ref[1] - 1
    def ref(i):
        for n, _, count, start in suras:
            if start <= i < start + count:
                return (n, i - start + 1)
        raise ValueError(i)
    page_starts = [abs_(r) for _, r in pages]
    def page_of(i):
        p = 0
        for k, s in enumerate(page_starts, 1):
            if s <= i: p = k
            else: break
        return p

    q_out = []
    for k, (n, first) in enumerate(quarters):
        a = abs_(first)
        b = abs_(quarters[k + 1][1]) - 1 if k + 1 < len(quarters) else total - 1
        last = ref(b)
        hizb = (n + 3) // 4
        q_out.append({
            "n": n, "hizb": hizb, "juz": (hizb + 1) // 2,
            "first": list(first), "last": list(last),
            "firstPage": page_of(a), "lastPage": page_of(b),
            "suras": list(range(first[0], last[0] + 1)),
        })
    s_out = []
    for n, name, count, _ in suras:
        touching = [q["n"] for q in q_out if n in q["suras"]]
        s_out.append({"n": n, "name": name, "ayas": count,
                      "firstQuarter": touching[0] if touching else None,
                      "lastQuarter": touching[-1] if touching else None})
    return {
        "format": 1,
        "mushaf": "مصحف المدينة النبوية · 604 أوجه · حفص",
        "source": "Tanzil quran-data.xml 1.0 (ترخيص cc-by) · انظر data/SOURCE.md",
        "ayaRef": "[السورة، الآية]",
        "pages": [{"n": n, "first": list(r)} for n, r in pages],
        "quarters": q_out,
        "suras": s_out,
        "juzNames": [f"الجزء {o}" for o in JUZ_ORDINALS],
    }


def dump(doc):
    """سطر لكل سجلّ، ليسهل على البشر مراجعة الملف ومقارنة تغييراته."""
    lines = ["{"]
    keys = list(doc)
    for i, k in enumerate(keys):
        v = doc[k]; comma = "," if i < len(keys) - 1 else ""
        if isinstance(v, list):
            lines.append(f'  "{k}": [')
            for j, item in enumerate(v):
                c = "," if j < len(v) - 1 else ""
                lines.append("    " + json.dumps(item, ensure_ascii=False, separators=(", ", ": ")) + c)
            lines.append("  ]" + comma)
        else:
            lines.append(f'  "{k}": ' + json.dumps(v, ensure_ascii=False) + comma)
    lines.append("}")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    OUT.write_text(dump(build()), encoding="utf-8")
    print(f"كُتب {OUT.relative_to(DATA.parent)}")
    sys.exit(0)
