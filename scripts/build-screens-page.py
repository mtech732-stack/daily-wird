#!/usr/bin/env python3
"""يبني صفحة اللقطات (screens/index.html) من الصور الموجودة في المجلّد.
الاستعمال: build-screens-page.py <screens-dir> <commit-sha> <run-url>
"""
import html, sys
from datetime import datetime, timezone
from pathlib import Path

root, sha, run_url = Path(sys.argv[1]), sys.argv[2], sys.argv[3]

SCREENS = {"01-home": "الشاشة الوحيدة: اسم التطبيق"}
DEVICES = [("large", "iPhone 17 Pro Max · الأكبر"), ("small", "iPhone 17e · الأصغر")]
VARIANTS = [("light", "نهاري", ""), ("dark", "ليلي", ""), ("light", "نهاري · رمادي", "-gray"), ("dark", "ليلي · رمادي", "-gray")]

shots = sorted({p.name.split("__")[0] for p in root.glob("*__*__*.png")})
missing = []
sections = []
for key in shots:
    title = SCREENS.get(key, key)
    rows = []
    for dev, dev_label in DEVICES:
        figs = []
        for app, label, suffix in VARIANTS:
            name = f"{key}__{dev}__{app}{suffix}.png"
            if not (root / name).exists():
                missing.append(name)
                continue
            figs.append(
                f'<figure><a href="{name}"><img src="{name}" alt="{html.escape(title)} · {label}" loading="lazy"></a>'
                f"<figcaption>{label}</figcaption></figure>"
            )
        rows.append(f'<h3>{dev_label}</h3><div class="grid">{"".join(figs)}</div>')
    sections.append(f'<section><h2>{html.escape(title)}</h2>{"".join(rows)}</section>')

if missing or not shots:
    sys.exit("لقطات ناقصة: " + ", ".join(missing or ["لا شيء"]))

now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
page = f"""<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>لقطات الورد اليومي</title>
<style>
:root {{ --bg:#F7F4EC; --fg:#0F3F6E; --muted:#5b6b7c; --card:#fff; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg:#13283E; --fg:#F2EDE2; --muted:#a9b4c0; --card:#1b3550; }} }}
body {{ margin:0; padding:16px; background:var(--bg); color:var(--fg);
  font-family:-apple-system, "SF Arabic", "Geeza Pro", sans-serif; }}
header p {{ color:var(--muted); font-size:14px; margin:4px 0; }}
h1 {{ font-size:22px; margin:0 0 8px; }}
h2 {{ font-size:18px; margin:24px 0 8px; }}
h3 {{ font-size:15px; margin:16px 0 8px; color:var(--muted); font-weight:600; }}
.grid {{ display:grid; grid-template-columns:repeat(2, minmax(0,1fr)); gap:12px; }}
@media (min-width:900px) {{ .grid {{ grid-template-columns:repeat(4, minmax(0,1fr)); }} }}
figure {{ margin:0; background:var(--card); border-radius:14px; padding:8px; }}
img {{ width:100%; height:auto; display:block; border-radius:10px; }}
figcaption {{ text-align:center; font-size:13px; padding-top:6px; }}
a {{ color:inherit; }}
</style>
</head>
<body>
<header>
<h1>لقطات الورد اليومي</h1>
<p>تُحدَّث تلقائياً بعد كل دمج. اضغط أي لقطة لتكبيرها.</p>
<p>آخر تحديث: {now} · الإيداع <a href="https://github.com/mtech732-stack/daily-wird/commit/{sha}">{sha[:7]}</a> · <a href="{html.escape(run_url)}">التشغيل</a></p>
</header>
{"".join(sections)}
</body>
</html>
"""
(root / "index.html").write_text(page, encoding="utf-8")
print("صفحة اللقطات:", len(shots), "شاشة")
