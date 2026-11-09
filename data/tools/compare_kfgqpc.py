#!/usr/bin/env python3
"""مقارنة تشخيصية لجدول الحدود ببيانات مجمّع الملك فهد (hafsData_v18.json).

ليست جزءاً من الجدول ولا تغيّره؛ غرضها كشف مواضع الشكّ لتُكتب في docs/open-questions.md.
المطابقة الرسمية بمصدر ثانٍ عمل المدقّق (6.3 البند 2)، والحكم الأخير لمصحف المالك (البند 3).

الاستعمال: python3 data/tools/compare_kfgqpc.py <مسار hafsData_v18.json>
"""
import json
import sys
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent
RUB = "۞"  # ۞


def main(path):
    kf = json.loads(Path(path).read_text(encoding="utf-8"))
    doc = json.loads((DATA / "quran-boundaries.json").read_text(encoding="utf-8"))
    marks = {(a["sora"], a["aya_no"]) for a in kf if RUB in a["aya_text"]}
    kf_page = {}
    for a in kf:
        kf_page.setdefault(a["page"], (a["sora"], a["aya_no"]))
    kf_juz = {}
    for a in kf:
        kf_juz.setdefault(a["jozz"], (a["sora"], a["aya_no"]))

    print("## الأرباع: بداية كل ربع في «تنزيل» وعلامة ۞ في نصّ المجمّع\n")
    q_first = {tuple(q["first"]): q["n"] for q in doc["quarters"]}
    no_mark = [(n, r) for r, n in q_first.items() if r not in marks]
    at_sura_start = [x for x in no_mark if x[1][1] == 1]
    other = sorted(x for x in no_mark if x[1][1] != 1)
    extra = sorted(r for r in marks if r not in q_first)
    print(f"- أرباع تبدأ بأول سورة (لا تُرسم عندها ۞ عادةً): {len(at_sura_start)}")
    print(f"- أرباع أخرى بلا علامة ۞ في المجمّع: {other or 'لا شيء'}")
    print(f"- علامات ۞ في المجمّع لا يقابلها ربع في «تنزيل»: {extra or 'لا شيء'}")
    print(f"- مجموع علامات ۞ في المجمّع: {len(marks)}\n")

    print("## الأجزاء: الجزء المشتقّ من الأرباع وبداية الجزء في المجمّع\n")
    by_juz = {}
    for q in doc["quarters"]:
        by_juz.setdefault(q["juz"], tuple(q["first"]))
    for j in range(1, 31):
        if by_juz[j] != kf_juz.get(j):
            print(f"- الجزء {j}: من الأرباع {by_juz[j][0]}:{by_juz[j][1]} · في المجمّع {kf_juz[j][0]}:{kf_juz[j][1]}")
    print()

    print("## الأوجه: أول آية في كل وجه\n")
    diffs = [(x["n"], tuple(x["first"]), kf_page.get(x["n"])) for x in doc["pages"]
             if tuple(x["first"]) != kf_page.get(x["n"])]
    print(f"عدد الأوجه المختلفة: {len(diffs)} من 604\n")
    if diffs:
        print("| الوجه | «تنزيل» | المجمّع v18 |\n|---|---|---|")
        for n, a, b in diffs:
            print(f"| {n} | {a[0]}:{a[1]} | {b[0]}:{b[1]} |")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
