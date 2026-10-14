#!/usr/bin/env python3
"""Generate the Progress Tracker app icon.

Draws the brand mark — the lime-to-teal accent gradient on a rounded
"squircle" with a bold checkmark, matching the in-app header logo — and
packs it into a multi-resolution macOS ``AppIcon.icns`` plus a 1024px
master PNG.

The only dependency is Pillow (``pip install pillow``). No macOS-only
tools (``iconutil``/``sips``) are required, so the icon can be rebuilt on
any platform:

    python3 scripts/generate-icon.py

Outputs are written to ``Resources/``.
"""

from __future__ import annotations

import io
import os
import struct

from PIL import Image, ImageDraw, ImageFilter

# --- Brand palette (matches Sources/ProgressTracker/ContentView.swift) -------
# accent gradient: lime -> teal, header checkmark ink is a near-black green.
LIME = (186, 255, 89)   # Color(red: 0.73, green: 1.00, blue: 0.35)
TEAL = (69, 240, 214)   # Color(red: 0.27, green: 0.94, blue: 0.84)
INK = (16, 54, 41)      # deep forest green for the checkmark

SS = 4  # supersampling factor for smooth, anti-aliased edges


def _lerp(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _diagonal_gradient(size: int) -> Image.Image:
    """A smooth top-left (lime) to bottom-right (teal) diagonal gradient."""
    grad = Image.new("RGB", (size, size))
    px = grad.load()
    denom = max(1, (size - 1) * 2)
    for y in range(size):
        for x in range(size):
            t = (x + y) / denom
            px[x, y] = _lerp(LIME, TEAL, t)
    return grad


def render_icon(size: int) -> Image.Image:
    """Render a single square RGBA icon of the given pixel size."""
    s = size * SS
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    # macOS icon grid: the rounded body occupies ~80% of the canvas, centred,
    # leaving transparent padding so it sits correctly beside other Dock icons.
    inset = round(s * 0.0977)
    radius = round(s * 0.1800)
    box = (inset, inset, s - inset, s - inset)

    # Rounded-square mask for the body.
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)

    # Gradient fill clipped to the body.
    body = _diagonal_gradient(s)
    canvas.paste(body, (0, 0), mask)

    # Soft highlight sweep across the top for a little depth. The band is
    # blurred so it fades out rather than ending on a hard edge.
    highlight = Image.new("L", (s, s), 0)
    hd = ImageDraw.Draw(highlight)
    hd.rounded_rectangle((inset, inset, s - inset, inset + round(s * 0.40)),
                         radius=radius, fill=48)
    highlight = highlight.filter(ImageFilter.GaussianBlur(round(s * 0.05)))
    white = Image.new("RGBA", (s, s), (255, 255, 255, 255))
    canvas = Image.composite(white, canvas, Image.composite(highlight, Image.new("L", (s, s), 0), mask))

    # Bold checkmark that echoes the header mark.
    draw = ImageDraw.Draw(canvas)
    pts = [
        (round(s * 0.320), round(s * 0.530)),
        (round(s * 0.452), round(s * 0.662)),
        (round(s * 0.712), round(s * 0.372)),
    ]
    width = round(s * 0.082)
    draw.line(pts, fill=INK, width=width, joint="curve")
    # Round caps for the two free ends.
    r = width // 2
    for (cx, cy) in (pts[0], pts[-1]):
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=INK)

    return canvas.resize((size, size), Image.LANCZOS)


def build_icns(master: Image.Image) -> bytes:
    """Pack PNG-encoded icon variants into an .icns container."""
    # OSType -> pixel size. Retina variants reuse the same pixels as their
    # equivalent point size, which is valid and keeps the file compact.
    variants = [
        (b"icp4", 16),
        (b"icp5", 32),
        (b"ic11", 32),   # 16pt @2x
        (b"ic12", 64),   # 32pt @2x
        (b"ic07", 128),
        (b"ic13", 256),  # 128pt @2x
        (b"ic08", 256),
        (b"ic14", 512),  # 256pt @2x
        (b"ic09", 512),
        (b"ic10", 1024),  # 512pt @2x
    ]
    entries = bytearray()
    for ostype, px in variants:
        img = master.resize((px, px), Image.LANCZOS) if px != master.width else master
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        data = buf.getvalue()
        entries += ostype + struct.pack(">I", len(data) + 8) + data
    total = len(entries) + 8
    return b"icns" + struct.pack(">I", total) + bytes(entries)


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "Resources")
    os.makedirs(out_dir, exist_ok=True)

    master = render_icon(1024)

    png_path = os.path.join(out_dir, "AppIcon-1024.png")
    master.save(png_path, format="PNG")

    icns_path = os.path.join(out_dir, "AppIcon.icns")
    with open(icns_path, "wb") as fh:
        fh.write(build_icns(master))

    print(f"Wrote {png_path}")
    print(f"Wrote {icns_path}")


if __name__ == "__main__":
    main()
