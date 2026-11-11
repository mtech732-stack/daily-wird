#!/usr/bin/env python3
"""يولّد شاشة البداية (ش6) وأيقونة «الملوّنة» (Tinted) من مقاييس الأيقونة المعتمدة (القرار 13، design/icon/README.md).

الاستعمال: python3 design/tools/build_launch.py
الإخراج: design/launch/*.svg و design/icon/app-icon-tinted.svg
المقياس: شريط الأيقونة 388 على لوح 1024 يصير 72 نقطة في شاشة البداية، أي ×0.1856.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
K = 72 / 388  # مقياس الأيقونة → شاشة البداية

THEMES = {
    # الأرضية · الشريط · الذهبي · البرتقالي · خطّ العلامة الداخلي
    "light": dict(paper="#F7F4EC", band="#0F3F6E", gilt="#DF8C16", ribbon="#DF8C16", inner="#0F3F6E"),
    "dark": dict(paper="#13283E", band="#1B3450", gilt="#E39A33", ribbon="#E39A33", inner="#13283E"),
}


def star(unit, color, opacity, sw, pid):
    """نقش النجمة الثمانية والصليب، بوحدة unit (128 في الأيقونة)."""
    s = unit / 128
    def p(pts):
        return " ".join(f"{x*s:.2f},{y*s:.2f}" for x, y in pts)
    oct_ = [(107.5,64),(94.8,76.7),(94.8,94.8),(76.7,94.8),(64,107.5),(51.3,94.8),(33.2,94.8),(33.2,76.7),(20.5,64),(33.2,51.3),(33.2,33.2),(51.3,33.2),(64,20.5),(76.7,33.2),(94.8,33.2),(94.8,51.3)]
    dia = [(64,45.7),(82.3,64),(64,82.3),(45.7,64)]
    u = unit
    return (f'<pattern id="{pid}" width="{u:.2f}" height="{u:.2f}" patternUnits="userSpaceOnUse">'
            f'<g fill="none" stroke="{color}" stroke-opacity="{opacity}" stroke-width="{sw:.2f}" stroke-linejoin="round">'
            f'<polygon points="{p(oct_)}"/><polygon points="{p(dia)}"/>'
            f'<path d="M0 {64*s:.2f} H{20.48*s:.2f} M{107.52*s:.2f} {64*s:.2f} H{u:.2f} M{64*s:.2f} 0 V{20.48*s:.2f} M{64*s:.2f} {107.52*s:.2f} V{u:.2f}"/>'
            f'<path d="M0 0 L{42.2*s:.2f} {42.2*s:.2f} M{u:.2f} 0 L{85.8*s:.2f} {42.2*s:.2f} M0 {u:.2f} L{42.2*s:.2f} {85.8*s:.2f} M{u:.2f} {u:.2f} L{85.8*s:.2f} {85.8*s:.2f}"/>'
            f'</g></pattern>')


def band_block(W, y0, t, pid):
    """الشريط ومسطرتاه: غليظة ثم رفيعة أعلاه، ورفيعة ثم غليظة أسفله (كإطار رأس السورة)."""
    thick, thin, gap = 20*K, 7*K, 8*K
    bh = 388*K
    y = y0
    out = [f'<rect x="0" y="{y:.2f}" width="{W}" height="{thick:.2f}" fill="{t["gilt"]}"/>']
    y += thick + gap
    out.append(f'<rect x="0" y="{y:.2f}" width="{W}" height="{thin:.2f}" fill="{t["gilt"]}"/>')
    y += thin
    top_band = y
    out.append(f'<rect x="0" y="{y:.2f}" width="{W}" height="{bh:.2f}" fill="{t["band"]}"/>')
    out.append(f'<rect x="0" y="{y:.2f}" width="{W}" height="{bh:.2f}" fill="url(#{pid})"/>')
    y += bh
    out.append(f'<rect x="0" y="{y:.2f}" width="{W}" height="{thin:.2f}" fill="{t["gilt"]}"/>')
    y += thin + gap
    out.append(f'<rect x="0" y="{y:.2f}" width="{W}" height="{thick:.2f}" fill="{t["gilt"]}"/>')
    y += thick
    return "".join(out), top_band, y


def block_height():
    return 2*(20*K + 8*K + 7*K) + 388*K


def ribbon(cx, bottom, t):
    """شريط العلامة: من أعلى الشاشة إلى ما بعد الشريط، وطرفه مشقوق، وحوله فاصل بلون الأرضية."""
    w, notch, halo, inset, inner = 240*K, 101*K, 22*K, 20*K, 7*K
    x0, x1 = cx - w/2, cx + w/2
    d = f"M{x0:.2f} -10 H{x1:.2f} V{bottom:.2f} L{cx:.2f} {bottom-notch:.2f} L{x0:.2f} {bottom:.2f} Z"
    di = (f"M{x0+inset:.2f} -10 V{bottom-inset*1.4:.2f} L{cx:.2f} {bottom-notch-inset*1.2:.2f} "
          f"L{x1-inset:.2f} {bottom-inset*1.4:.2f} V-10")
    return (f'<path d="{d}" fill="none" stroke="{t["paper"]}" stroke-width="{halo:.2f}" stroke-linejoin="miter"/>'
            f'<path d="{d}" fill="{t["ribbon"]}"/>'
            f'<path d="{di}" stroke="{t["inner"]}" stroke-opacity="0.55" stroke-width="{inner:.2f}" fill="none" stroke-linejoin="round"/>')


def launch(W, H, theme):
    t = THEMES[theme]
    pid = f"lp{theme}"
    bh = block_height()
    y0 = round((H - bh) / 2, 2)
    bands, _, yb = band_block(W, y0, t, pid)
    # موضع العلامة كما في الأيقونة: مركزها على 700 من 1024 (يمين المركز)
    cx = W * 700 / 1024
    tail = (880 - 706) * K
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-label="شاشة البداية">'
            f'<defs>{star(128*K, t["gilt"], 0.5, 4.2*K*1.6, pid)}</defs>'
            f'<rect width="{W}" height="{H}" fill="{t["paper"]}"/>{bands}{ribbon(cx, yb + tail, t)}</svg>')


def band_asset(theme, W=1320):
    """صورة الشريط وحده للمهندس: عرض 1320 يُقصّ من الجانبين على كل شاشة (contentMode center)."""
    t = THEMES[theme]
    pid = f"bp{theme}"
    bh = block_height()
    bands, _, _ = band_block(W, 0, t, pid)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{bh:.2f}" viewBox="0 0 {W} {bh:.2f}">'
            f'<defs>{star(128*K, t["gilt"], 0.5, 4.2*K*1.6, pid)}</defs>{bands}</svg>')


def ribbon_asset(theme, H=120):
    """صورة العلامة وحدها (مع فاصلها): عرضها ثابت، ويُمدّ أعلاها (slicing) ويبقى طرفها المشقوق."""
    t = THEMES[theme]
    w, halo = 240*K, 22*K
    W = w + halo
    cx = W/2
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W:.2f}" height="{H+halo/2:.2f}" viewBox="0 0 {W:.2f} {H+halo/2:.2f}">'
            f'{ribbon(cx, H, t)}</svg>')


def tinted_icon():
    """الأيقونة الملوّنة (Tinted) في iOS: رمادية على أسود، والنظام يلوّنها بلون المستخدم. الأفتح هو الأبرز: العلامة ثم المسطرتان."""
    src = (ROOT / "icon" / "app-icon-light.svg").read_text()
    rep = {
        'fill="#0F3F6E"/>\n  <rect x="0" y="318"': 'fill="#000000"/>\n  <rect x="0" y="318"',
        'fill="#134A80"': 'fill="#1E1E1E"',
        'stroke="#DF8C16" stroke-opacity="0.5"': 'stroke="#FFFFFF" stroke-opacity="0.32"',
        'fill="#DF8C16"/><rect x="0" y="310"': 'fill="#A6A6A6"/><rect x="0" y="310"',
    }
    for a, b in rep.items():
        assert a in src, a
        src = src.replace(a, b)
    src = src.replace('height="7" fill="#DF8C16"', 'height="7" fill="#A6A6A6"').replace('height="20" fill="#DF8C16"', 'height="20" fill="#A6A6A6"')
    src = src.replace('stroke="#0F3F6E" stroke-width="22"', 'stroke="#000000" stroke-width="22"')
    src = src.replace('<path d="M580 -10 H820 V880 L700 779 L580 880 Z" fill="#DF8C16"/>', '<path d="M580 -10 H820 V880 L700 779 L580 880 Z" fill="#FFFFFF"/>')
    src = src.replace('stroke="#0F3F6E" stroke-opacity="0.55"', 'stroke="#000000" stroke-opacity="0.45"')
    src = src.replace('id="s17p"', 'id="s19p"').replace('url(#s17p)', 'url(#s19p)')
    assert "#DF8C16" not in src and "#0F3F6E" not in src
    return src


def main():
    out = ROOT / "launch"
    out.mkdir(exist_ok=True)
    for theme in THEMES:
        for (W, H) in [(393, 852), (375, 667), (440, 956)]:
            (out / f"launch-{theme}-{W}.svg").write_text(launch(W, H, theme))
        (out / f"launch-band-{theme}.svg").write_text(band_asset(theme))
        (out / f"launch-ribbon-{theme}.svg").write_text(ribbon_asset(theme))
    (ROOT / "icon" / "app-icon-tinted.svg").write_text(tinted_icon())
    print("block", round(block_height(), 2), "ribbon w", round(240*K, 2))


if __name__ == "__main__":
    main()
