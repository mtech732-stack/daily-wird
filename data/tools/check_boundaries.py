#!/usr/bin/env python3
"""الفاحص الآلي لجدول الحدود (وثيقة المشروع 6.3 البند 1، وفحص الربع المشترك لـ 7.1.1).

يقرأ data/quran-boundaries.json ويطبع كل شرط ونتيجته، ويخرج برمز 1 إن فشل أي شرط.
لا يعتمد على شيء خارج مكتبة Python القياسية.

الاستعمال: python3 data/tools/check_boundaries.py
"""
import json
import sys
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_boundaries  # noqa: E402

results = []


def check(title, ok, detail=""):
    results.append(ok)
    print(("✓ " if ok else "✗ ") + title + (f" — {detail}" if detail else ""))


def main():
    doc = json.loads((DATA / "quran-boundaries.json").read_text(encoding="utf-8"))
    pages, quarters, suras = doc["pages"], doc["quarters"], doc["suras"]
    ayas = {s["n"]: s["ayas"] for s in suras}
    order = [(s, a) for s in sorted(ayas) for a in range(1, ayas[s] + 1)]
    pos = {r: i for i, r in enumerate(order)}
    def p(ref): return pos.get(tuple(ref))

    print("— 6.3 البند 1 —")
    check("604 أوجه مرقّمة 1…604 بلا فجوة", [x["n"] for x in pages] == list(range(1, 605)), f"{len(pages)}")
    check("240 ربعاً مرقّمة 1…240 بلا فجوة", [x["n"] for x in quarters] == list(range(1, 241)), f"{len(quarters)}")
    check("114 سورة مرقّمة 1…114 بلا فجوة", [x["n"] for x in suras] == list(range(1, 115)), f"{len(suras)}")
    check("عدد آيات المصحف 6236", len(order) == 6236, f"{len(order)}")
    refs = [x["first"] for x in pages] + [r for q in quarters for r in (q["first"], q["last"])]
    bad = [r for r in refs if p(r) is None]
    check("كل آية مذكورة موجودة (السورة والآية في مداهما)", not bad, str(bad[:5]))
    if bad:
        return finish()
    check("بدايات الأوجه متصاعدة بلا تكرار",
          all(p(a["first"]) < p(b["first"]) for a, b in zip(pages, pages[1:])))
    check("بدايات الأرباع متصاعدة بلا تكرار",
          all(p(a["first"]) < p(b["first"]) for a, b in zip(quarters, quarters[1:])))
    check("أول ربع يبدأ بالفاتحة 1:1 في الوجه 1",
          quarters[0]["first"] == [1, 1] and quarters[0]["firstPage"] == 1 and pages[0]["first"] == [1, 1])
    check("آخر ربع ينتهي بآخر المصحف 114:6", quarters[-1]["last"] == [114, 6])
    gaps = [q["n"] for q, nxt in zip(quarters, quarters[1:]) if p(q["last"]) + 1 != p(nxt["first"])]
    check("آخر آية في كل ربع تسبق مباشرة أول آية في الذي بعده (لا فجوة ولا تداخل)", not gaps, str(gaps[:10]))
    check("كل ربع أوّله قبل آخره أو هو هو", all(p(q["first"]) <= p(q["last"]) for q in quarters))
    starts = [p(x["first"]) for x in pages]
    def page_of(i): return max(k for k, s in enumerate(starts, 1) if s <= i)
    wrong = [q["n"] for q in quarters
             if not (1 <= q["firstPage"] <= q["lastPage"] <= 604)
             or q["firstPage"] != page_of(p(q["first"])) or q["lastPage"] != page_of(p(q["last"]))]
    check("كل ربع يمسّ وجهاً واحداً على الأقل، ووجهاه يطابقان بدايات الأوجه", not wrong, str(wrong[:10]))
    untouched = [s["n"] for s in suras if not any(s["n"] in q["suras"] for q in quarters)]
    check("كل سورة يمسّها ربع واحد على الأقل", not untouched, str(untouched))

    print("— الحزب والجزء (6.1) —")
    check("الحزب = ⌈الربع ÷ 4⌉ والجزء = ⌈الحزب ÷ 2⌉",
          all(q["hizb"] == (q["n"] + 3) // 4 and q["juz"] == (q["hizb"] + 1) // 2 for q in quarters))
    check("60 حزباً و30 جزءاً", {q["hizb"] for q in quarters} == set(range(1, 61))
          and {q["juz"] for q in quarters} == set(range(1, 31)))
    check("30 اسماً للأجزاء", len(doc["juzNames"]) == 30 and all(n.startswith("الجزء ") for n in doc["juzNames"]))
    check("أسماء السور 114 غير فارغة", all(s["name"].strip() for s in suras))

    print("— الربع المشترك والعرض بالسور (7.1.1) —")
    check("سور كل ربع متّصلة من سورة أوّله إلى سورة آخره",
          all(q["suras"] == list(range(q["first"][0], q["last"][0] + 1)) for q in quarters))
    mism = []
    for s in suras:
        touching = [q["n"] for q in quarters if s["n"] in q["suras"]]
        if touching != list(range(s["firstQuarter"], s["lastQuarter"] + 1)):
            mism.append(s["n"])
    check("أرباع كل سورة متّصلة، وتطابق أول ربع وآخر ربع فيها", not mism, str(mism[:10]))
    shared = [q for q in quarters if len(q["suras"]) > 1]
    ok = all(q["n"] in range(next(s for s in suras if s["n"] == x)["firstQuarter"],
                             next(s for s in suras if s["n"] == x)["lastQuarter"] + 1)
             for q in shared for x in q["suras"])
    check("كل ربع مشترك يظهر تحت كل سورة يمسّها (ربع واحد في السجلّ)", ok,
          f"الأرباع المشتركة {len(shared)}")
    check("كل ربع يمسّ سورة واحدة على الأقل", all(q["suras"] for q in quarters))
    check("أول ربع يمسّ الفاتحة والبقرة معاً (ربع مشترك)", quarters[0]["suras"] == [1, 2])
    check("آخر ربع يمسّ 15 سورة (100 … 114)", quarters[-1]["suras"] == list(range(100, 115)))

    print("— المطابقة بالمصدر —")
    rebuilt = build_boundaries.build()
    check("الملف يطابق ما يُبنى من ملف «تنزيل» حرفاً بحرف",
          build_boundaries.dump(rebuilt) == (DATA / "quran-boundaries.json").read_text(encoding="utf-8"))
    return finish(len(shared))


def finish(shared=None):
    n, ok = len(results), sum(results)
    print(f"\nالنتيجة: {ok} من {n} شرطاً " + ("— ناجح" if ok == n else "— فاشل"))
    return 0 if ok == n else 1


if __name__ == "__main__":
    sys.exit(main())
