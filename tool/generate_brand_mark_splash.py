#!/usr/bin/env python3
"""Build brand_mark_splash.png from brand_mark.png for the native splash.

Maps near-white plate pixels to Secondary s800 (#1E1B4B) so the mark reads on
[AppColors.canvas] / p50. Re-run when brand_mark.png changes, then
`dart run flutter_native_splash:create`.
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError as e:
    print("Install Pillow: pip install pillow", file=sys.stderr)
    raise SystemExit(1) from e

# SecondaryPalette.s800
PLATE = (0x1E, 0x1B, 0x4B, 0xFF)


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    src = root / "assets/branding/brand_mark.png"
    dst = root / "assets/branding/brand_mark_splash.png"
    im = Image.open(src).convert("RGBA")
    pixels = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a < 8:
                continue
            if r > 245 and g > 245 and b > 245:
                pixels[x, y] = PLATE
    im.save(dst, optimize=True)
    print(f"Wrote {dst} ({w}x{h})")


if __name__ == "__main__":
    main()
