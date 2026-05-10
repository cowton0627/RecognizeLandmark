#!/usr/bin/env python3
"""
產生 RecognizeLandmark 的 app icon(1024x1024 PNG)。

從 repo 根目錄執行:
    python3 tools/make_icon.py

預設會覆蓋 RecognizeLandmark/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png。
依賴:Pillow(pip install Pillow)。
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def make_icon():
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 255))

    # ---- 1. 4-stop sunset gradient ----
    top = (255, 198, 150)        # warm peach
    mid_upper = (232, 130, 128)  # coral
    mid_lower = (105, 65, 130)   # warm purple
    bot = (22, 18, 50)           # deep navy
    bg = ImageDraw.Draw(img)
    for y in range(SIZE):
        t = y / SIZE
        if t < 0.30:
            c = lerp(top, mid_upper, t / 0.30)
        elif t < 0.62:
            c = lerp(mid_upper, mid_lower, (t - 0.30) / 0.32)
        else:
            c = lerp(mid_lower, bot, (t - 0.62) / 0.38)
        bg.line([(0, y), (SIZE, y)], fill=c + (255,))

    # ---- 2. Warm horizon glow(取代大太陽) ----
    horizon = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    hd = ImageDraw.Draw(horizon)
    hy = int(SIZE * 0.66)
    hd.ellipse([SIZE // 2 - 440, hy - 70, SIZE // 2 + 440, hy + 70],
               fill=(255, 195, 145, 120))
    horizon = horizon.filter(ImageFilter.GaussianBlur(radius=85))
    img = Image.alpha_composite(img, horizon)

    # ---- 3. Distant mountains:3 layers,sin-based smooth curves ----
    for alpha, base_y, amp, phase, color in [
        (70, int(SIZE * 0.66), 0.040, 0.0, (35, 28, 70)),
        (110, int(SIZE * 0.72), 0.035, 0.7, (24, 18, 56)),
        (150, int(SIZE * 0.77), 0.025, 1.4, (18, 14, 44)),
    ]:
        layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        pts = []
        for x in range(0, SIZE + 1, 6):
            wave = (
                math.sin(x / SIZE * math.pi * 3 + phase) * 0.6
                + math.sin(x / SIZE * math.pi * 7 + phase * 2) * 0.3
                + math.sin(x / SIZE * math.pi * 13 + phase * 3) * 0.1
            )
            y = int(base_y - SIZE * amp * wave)
            pts.append((x, y))
        pts.append((SIZE, SIZE))
        pts.append((0, SIZE))
        ld.polygon(pts, fill=color + (alpha,))
        img = Image.alpha_composite(img, layer)

    # ---- 4. Tokyo Tower 式輪廓:天線 + 上柱 + 觀景艙 + 下柱 + 撐開底座 ----
    cx = SIZE // 2
    antenna_tip_y    = int(SIZE * 0.17)
    antenna_base_y   = int(SIZE * 0.28)
    upper_col_top_y  = int(SIZE * 0.30)
    pod_top_y        = int(SIZE * 0.40)
    pod_bot_y        = int(SIZE * 0.50)
    lower_col_bot_y  = int(SIZE * 0.70)
    base_bot_y       = int(SIZE * 0.84)

    antenna_w = 5
    column_w  = 28
    pod_w     = 78
    base_w    = 92

    right = [
        (cx,                  antenna_tip_y),
        (cx + antenna_w,      antenna_base_y),
        (cx + column_w,       upper_col_top_y),
        (cx + column_w,       pod_top_y),
        (cx + pod_w,          pod_top_y),
        (cx + pod_w,          pod_bot_y),
        (cx + column_w,       pod_bot_y),
        (cx + column_w,       lower_col_bot_y),
        (cx + base_w,         base_bot_y),
    ]
    left = [(2 * cx - x, y) for (x, y) in reversed(right)]
    tower_pts = right + left

    # 4a. Drop shadow(讓塔有重量、不浮空)
    shadow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sh_pts = [(x + 5, y + 22) for (x, y) in tower_pts]
    sd.polygon(sh_pts, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=24))
    img = Image.alpha_composite(img, shadow)

    # 4b. 觀景艙暖光(光暈在塔身後面,塔身會蓋上來)
    pod_glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    pgd = ImageDraw.Draw(pod_glow)
    pod_cy = (pod_top_y + pod_bot_y) // 2
    pgd.ellipse(
        [cx - pod_w - 30, pod_cy - 35,
         cx + pod_w + 30, pod_cy + 35],
        fill=(255, 200, 130, 80),
    )
    pod_glow = pod_glow.filter(ImageFilter.GaussianBlur(radius=14))
    img = Image.alpha_composite(img, pod_glow)

    # 4c. 塔身(白)
    twr = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    td = ImageDraw.Draw(twr)
    td.polygon(tower_pts, fill=(252, 250, 248, 255))

    # 4d. 觀景艙中央橫向暖光帶(暗示「窗戶亮了」)
    strip_h = 5
    td.rectangle(
        [cx - pod_w + 10, pod_cy - strip_h,
         cx + pod_w - 10, pod_cy + strip_h],
        fill=(255, 195, 125, 245),
    )

    img = Image.alpha_composite(img, twr)

    # ---- 5. 天線尖端細小光點 + 柔光 ----
    glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    glow_y = antenna_tip_y - 22
    gd.ellipse([cx - 38, glow_y - 38, cx + 38, glow_y + 38],
               fill=(255, 235, 170, 110))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=16))
    img = Image.alpha_composite(img, glow)

    dot = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dot)
    dot_r = 7
    dd.ellipse([cx - dot_r, glow_y - dot_r, cx + dot_r, glow_y + dot_r],
               fill=(255, 240, 185, 255))
    img = Image.alpha_composite(img, dot)

    # iOS app icons must be opaque RGB
    return img.convert('RGB')


if __name__ == '__main__':
    icon = make_icon()
    repo_root = Path(__file__).resolve().parent.parent
    out = repo_root / 'RecognizeLandmark' / 'Resources' / 'Assets.xcassets' / \
        'AppIcon.appiconset' / 'AppIcon-1024.png'
    icon.save(out, 'PNG', optimize=True)
    print(f'wrote {out}')
