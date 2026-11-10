#!/usr/bin/env python3
"""لقطات طلب الدمج قبل دمجه (القرار 11): ينسخ لقطات التشغيل إلى مجلّد في فرع previews،
ويكتب فيه README.md يعرضها، فيفتحها المالك من هاتفه على GitHub قبل الدمج.
الاستعمال: build-pr-preview.py <screens-dir> <out-dir> <pr-number> <commit-sha> <run-url>
"""
import shutil, sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from screen_titles import SCREENS  # noqa: E402

src, out, pr, sha, run_url = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5]
if out.exists():
    shutil.rmtree(out)
out.mkdir(parents=True)
for png in src.glob("*.png"):
    shutil.copy(png, out / png.name)

DEVICES = [("large", "iPhone 17 Pro Max · الأكبر"), ("small", "iPhone 17e · الأصغر")]
VARIANTS = [("light", "", "نهاري"), ("dark", "", "ليلي"), ("light", "-gray", "نهاري رمادي"), ("dark", "-gray", "ليلي رمادي")]
keys = sorted({p.name.split("__")[0] for p in out.glob("*__*__*.png")})
now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
lines = [
    f"# لقطات طلب الدمج #{pr} قبل دمجه",
    "",
    f"الإيداع [`{sha[:7]}`](https://github.com/mtech732-stack/daily-wird/commit/{sha}) · [التشغيل]({run_url}) · {now}",
    "",
    "اضغط أي لقطة لتكبيرها. وبعد الدمج تُنشر في صفحة اللقطات العامة.",
    "",
]
for key in keys:
    lines += [f"## {SCREENS.get(key, key)}", ""]
    for dev, dev_label in DEVICES:
        cells = []
        for look, suffix, label in VARIANTS:
            name = f"{key}__{dev}__{look}{suffix}.png"
            if (out / name).exists():
                cells.append(f'<a href="{name}"><img src="{name}" width="160" alt="{label}"></a>')
        if cells:
            lines += [f"**{dev_label}** (نهاري · ليلي · نهاري رمادي · ليلي رمادي)", "", " ".join(cells), ""]
(out / "README.md").write_text("\n".join(lines), encoding="utf-8")
print(f"معاينة #{pr}: {len(keys)} شاشة")
