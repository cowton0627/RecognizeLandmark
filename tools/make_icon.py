#!/usr/bin/env python3
"""
產生 RecognizeLandmark 的 app icon(1024x1024 PNG)。

從 repo 根目錄執行:
    python3 tools/make_icon.py

預設會覆蓋 RecognizeLandmark/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png。
依賴:Pillow(pip install Pillow)。
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def make_icon():
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 255))

    # ---- 1. Sunset gradient background ----
    top = (255, 168, 120)   # warm coral
    mid = (228, 78, 132)    # rose
    bot = (38, 28, 78)      # deep indigo
    bg = ImageDraw.Draw(img)
    for y in range(SIZE):
        t = y / SIZE
        if t < 0.55:
            color = lerp(top, mid, t / 0.55) + (255,)
        else:
            color = lerp(mid, bot, (t - 0.55) / 0.45) + (255,)
        bg.line([(0, y), (SIZE, y)], fill=color)

    # ---- 2. Soft sun glow (upper-right) ----
    glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = int(SIZE * 0.72), int(SIZE * 0.26)
    gd.ellipse([cx - 220, cy - 220, cx + 220, cy + 220],
               fill=(255, 235, 200, 100))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=80))
    img = Image.alpha_composite(img, glow)

    # ---- 3. Distant mountains (two faded layers) ----
    for alpha, ymin, ymax, n_peaks, jitter in [
        (60, 0.60, 0.70, 7, 0.04),
        (90, 0.66, 0.76, 5, 0.05),
    ]:
        layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        pts = [(0, int(SIZE * ymax))]
        for i in range(n_peaks + 1):
            x = int(SIZE * i / n_peaks)
            if i % 2 == 0:
                y = int(SIZE * (ymax - jitter * 1.5))
            else:
                y = int(SIZE * (ymin + jitter * (i % 3)))
            pts.append((x, y))
        pts.append((SIZE, int(SIZE * ymax)))
        pts.append((SIZE, SIZE))
        pts.append((0, SIZE))
        ld.polygon(pts, fill=(20, 12, 50, alpha))
        img = Image.alpha_composite(img, layer)

    # ---- 4. Drop shadow for tower ----
    shadow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    cx_t = SIZE // 2
    top_y = int(SIZE * 0.22)
    spire_base_y = int(SIZE * 0.36)
    body_top_y = int(SIZE * 0.42)
    tier_y = int(SIZE * 0.56)
    body_bot_y = int(SIZE * 0.76)
    base_y = int(SIZE * 0.82)
    base_bot_y = int(SIZE * 0.84)

    spire_half = 8
    body_top_half = 46
    tier_half = 78
    body_bot_half = 78
    base_half = 130

    tower_pts = [
        (cx_t, top_y),
        (cx_t + spire_half, spire_base_y),
        (cx_t + body_top_half, body_top_y),
        (cx_t + body_top_half, tier_y - 14),
        (cx_t + tier_half, tier_y - 14),
        (cx_t + tier_half, tier_y + 14),
        (cx_t + body_bot_half, tier_y + 14),
        (cx_t + body_bot_half, body_bot_y),
        (cx_t + base_half, base_y),
        (cx_t + base_half, base_bot_y),
        (cx_t - base_half, base_bot_y),
        (cx_t - base_half, base_y),
        (cx_t - body_bot_half, body_bot_y),
        (cx_t - body_bot_half, tier_y + 14),
        (cx_t - tier_half, tier_y + 14),
        (cx_t - tier_half, tier_y - 14),
        (cx_t - body_top_half, tier_y - 14),
        (cx_t - body_top_half, body_top_y),
        (cx_t - spire_half, spire_base_y),
    ]
    # Offset shadow slightly down
    shadow_pts = [(x + 6, y + 14) for (x, y) in tower_pts]
    sd.polygon(shadow_pts, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=18))
    img = Image.alpha_composite(img, shadow)

    # ---- 5. Tower silhouette (white) ----
    twr = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    td = ImageDraw.Draw(twr)
    td.polygon(tower_pts, fill=(255, 255, 255, 255))

    # Lit windows on the body (small warm rectangles)
    win_color = (255, 220, 130, 230)
    for y_pos in [int(SIZE * 0.62), int(SIZE * 0.66), int(SIZE * 0.70)]:
        for x_off in [-30, 0, 30]:
            td.rectangle([cx_t + x_off - 6, y_pos,
                          cx_t + x_off + 6, y_pos + 12],
                         fill=win_color)

    img = Image.alpha_composite(img, twr)

    # ---- 6. Glowing dot at spire tip ----
    dot_glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    dgd = ImageDraw.Draw(dot_glow)
    dot_y = top_y - 22
    dgd.ellipse([cx_t - 70, dot_y - 70, cx_t + 70, dot_y + 70],
                fill=(255, 230, 130, 130))
    dot_glow = dot_glow.filter(ImageFilter.GaussianBlur(radius=22))
    img = Image.alpha_composite(img, dot_glow)

    dot = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    ddd = ImageDraw.Draw(dot)
    dot_r = 16
    ddd.ellipse([cx_t - dot_r, dot_y - dot_r,
                 cx_t + dot_r, dot_y + dot_r],
                fill=(255, 235, 150, 255))
    img = Image.alpha_composite(img, dot)

    # ---- 7. Viewfinder corner brackets (subtle) ----
    brk = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    bd = ImageDraw.Draw(brk)
    m = 110          # margin from edge
    L = 95           # bracket arm length
    T = 14           # thickness
    col = (255, 255, 255, 130)
    # Top-left
    bd.rectangle([m, m, m + L, m + T], fill=col)
    bd.rectangle([m, m, m + T, m + L], fill=col)
    # Top-right
    bd.rectangle([SIZE - m - L, m, SIZE - m, m + T], fill=col)
    bd.rectangle([SIZE - m - T, m, SIZE - m, m + L], fill=col)
    # Bottom-left
    bd.rectangle([m, SIZE - m - T, m + L, SIZE - m], fill=col)
    bd.rectangle([m, SIZE - m - L, m + T, SIZE - m], fill=col)
    # Bottom-right
    bd.rectangle([SIZE - m - L, SIZE - m - T, SIZE - m, SIZE - m], fill=col)
    bd.rectangle([SIZE - m - T, SIZE - m - L, SIZE - m, SIZE - m], fill=col)
    img = Image.alpha_composite(img, brk)

    # iOS app icons must be opaque RGB (no alpha channel)
    return img.convert('RGB')


if __name__ == '__main__':
    icon = make_icon()
    repo_root = Path(__file__).resolve().parent.parent
    out = repo_root / 'RecognizeLandmark' / 'Assets.xcassets' / \
        'AppIcon.appiconset' / 'AppIcon-1024.png'
    icon.save(out, 'PNG', optimize=True)
    print(f'wrote {out}')
