from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter, ImageOps


def _build_detailmap(source_path: Path, output_path: Path, size: int) -> None:
    src = Image.open(source_path).convert("RGBA")
    square_extent = min(src.width, src.height)
    left = (src.width - square_extent) // 2
    top = (src.height - square_extent) // 2
    src = src.crop((left, top, left + square_extent, top + square_extent))
    src = src.resize((size, size), Image.Resampling.LANCZOS)

    luminance = ImageOps.grayscale(src)
    luminance = ImageOps.autocontrast(luminance, cutoff=2)
    luminance = ImageEnhance.Contrast(luminance).enhance(1.55)
    luminance = ImageEnhance.Sharpness(luminance).enhance(1.20)
    luminance = luminance.filter(ImageFilter.GaussianBlur(radius=0.4))

    detail = Image.new("L", (size, size), 0)
    pixels_out = detail.load()
    pixels_in = luminance.load()
    cx = (size - 1) * 0.5
    cy = (size - 1) * 0.5
    radius = size * 0.46
    feather = size * 0.035

    for y in range(size):
        for x in range(size):
            dx = x - cx
            dy = y - cy
            dist = (dx * dx + dy * dy) ** 0.5
            if dist >= radius + feather:
                pixels_out[x, y] = 0
                continue
            edge_alpha = 1.0
            if dist > radius:
                edge_alpha = max(0.0, 1.0 - (dist - radius) / feather)
            value = int(pixels_in[x, y] * edge_alpha)
            pixels_out[x, y] = max(0, min(255, value))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    detail.save(output_path)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Derive a reusable grayscale star detailmap from a solar reference image."
    )
    parser.add_argument("--input", required=True, help="Input solar reference image path")
    parser.add_argument("--output", required=True, help="Output PNG path")
    parser.add_argument("--size", type=int, default=512, help="Output square size in pixels")
    args = parser.parse_args()

    _build_detailmap(Path(args.input), Path(args.output), args.size)


if __name__ == "__main__":
    main()
