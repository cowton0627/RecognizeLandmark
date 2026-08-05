#!/usr/bin/env python3
"""把原始截圖(iPhone 實機或模擬器輸出)整理成 README 可用的尺寸。

iPhone 截圖是 1179x2556 之類的 3x 解析度,一張 500KB~2MB,直接進 repo 會讓
clone 變重、diff 也難看。這支把它們等比縮到指定寬度、去掉多餘 metadata,
輸出到 docs/screenshots/。

用法:
    python3 tools/prep_screenshots.py ~/Desktop/raw-shots
    python3 tools/prep_screenshots.py ~/Desktop/raw-shots --width 900 --format jpg

輸出檔名沿用來源檔名(副檔名依 --format)。要改 README 顯示的檔名,直接把來源
檔改成想要的名字再跑一次。

依賴:pip install Pillow
"""

import argparse
import sys
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = REPO_ROOT / "docs" / "screenshots"
SOURCE_SUFFIXES = {".png", ".jpg", ".jpeg", ".heic"}


def prep(src: Path, out_dir: Path, width: int, fmt: str, quality: int) -> Path:
    with Image.open(src) as image:
        image = image.convert("RGB")
        if image.width > width:
            height = round(image.height * width / image.width)
            image = image.resize((width, height), Image.LANCZOS)

        out_path = out_dir / f"{src.stem}.{fmt}"
        if fmt == "jpg":
            image.save(out_path, "JPEG", quality=quality, optimize=True)
        else:
            image.save(out_path, "PNG", optimize=True)
    return out_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path, help="放原始截圖的資料夾(或單一檔案)")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help=f"輸出目錄(預設 {DEFAULT_OUT.relative_to(REPO_ROOT)})")
    parser.add_argument("--width", type=int, default=640, help="輸出寬度 px(預設 640,README 顯示 ~300px 時仍是 2x 清晰度)")
    parser.add_argument("--format", choices=["png", "jpg"], default="png", help="輸出格式(預設 png)")
    parser.add_argument("--quality", type=int, default=88, help="JPEG 品質(只有 --format jpg 有效)")
    args = parser.parse_args()

    if args.source.is_file():
        sources = [args.source]
    else:
        sources = sorted(p for p in args.source.iterdir() if p.suffix.lower() in SOURCE_SUFFIXES)

    if not sources:
        print(f"在 {args.source} 找不到可處理的圖片", file=sys.stderr)
        return 1

    args.out.mkdir(parents=True, exist_ok=True)
    for src in sources:
        out_path = prep(src, args.out, args.width, args.format, args.quality)
        size_kb = out_path.stat().st_size / 1024
        print(f"{src.name} -> {out_path.relative_to(REPO_ROOT)} ({size_kb:.0f} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
