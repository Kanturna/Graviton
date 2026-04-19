from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter, ImageOps


def _threshold_mask(luminance: Image.Image) -> tuple[int, list[tuple[int, int, int]], list[tuple[int, int, int]]]:
    pixels = luminance.load()
    width, height = luminance.size
    max_value = max(luminance.getextrema()[1], 1)
    threshold = max(28, int(max_value * 0.18))

    row_spans: list[tuple[int, int, int]] = []
    max_row_span = 0
    for y in range(height):
        left = -1
        right = -1
        for x in range(width):
            if pixels[x, y] >= threshold:
                if left == -1:
                    left = x
                right = x
        if left != -1:
            span = right - left + 1
            row_spans.append((y, left, right))
            max_row_span = max(max_row_span, span)

    col_spans: list[tuple[int, int, int]] = []
    max_col_span = 0
    for x in range(width):
        top = -1
        bottom = -1
        for y in range(height):
            if pixels[x, y] >= threshold:
                if top == -1:
                    top = y
                bottom = y
        if top != -1:
            span = bottom - top + 1
            col_spans.append((x, top, bottom))
            max_col_span = max(max_col_span, span)

    return threshold, row_spans, col_spans


def _find_disc_geometry(luminance: Image.Image) -> tuple[float, float, float]:
    width, height = luminance.size
    _, row_spans, col_spans = _threshold_mask(luminance)
    if not row_spans or not col_spans:
        return width * 0.5, height * 0.5, min(width, height) * 0.45

    max_row_span = max((right - left + 1) for _, left, right in row_spans)
    max_col_span = max((bottom - top + 1) for _, top, bottom in col_spans)
    core_rows = [
        (y, left, right)
        for y, left, right in row_spans
        if (right - left + 1) >= max_row_span * 0.70
    ]
    core_cols = [
        (x, top, bottom)
        for x, top, bottom in col_spans
        if (bottom - top + 1) >= max_col_span * 0.70
    ]
    if not core_rows:
        core_rows = row_spans
    if not core_cols:
        core_cols = col_spans

    center_x = sum((left + right) * 0.5 for _, left, right in core_rows) / len(core_rows)
    center_y = sum((top + bottom) * 0.5 for _, top, bottom in core_cols) / len(core_cols)
    radius_x = sum((right - left + 1) * 0.5 for _, left, right in core_rows) / len(core_rows)
    radius_y = sum((bottom - top + 1) * 0.5 for _, top, bottom in core_cols) / len(core_cols)
    radius = max(1.0, min(radius_x, radius_y))
    return center_x, center_y, radius


def _crop_square_centered(source: Image.Image, center_x: float, center_y: float, radius: float) -> Image.Image:
    half_extent = max(1.0, radius * 1.06)
    extent = max(2, int(round(half_extent * 2.0)))
    left = int(math.floor(center_x - half_extent))
    top = int(math.floor(center_y - half_extent))
    right = left + extent
    bottom = top + extent

    cropped = Image.new("RGBA", (extent, extent), (0, 0, 0, 255))
    src_left = max(0, left)
    src_top = max(0, top)
    src_right = min(source.width, right)
    src_bottom = min(source.height, bottom)
    if src_right <= src_left or src_bottom <= src_top:
        return cropped

    region = source.crop((src_left, src_top, src_right, src_bottom))
    paste_x = src_left - left
    paste_y = src_top - top
    cropped.paste(region, (paste_x, paste_y))
    return cropped


def _build_detailmap(source_path: Path, output_path: Path, size: int) -> None:
    src = Image.open(source_path).convert("RGBA")
    luminance_source = ImageOps.grayscale(src).filter(ImageFilter.GaussianBlur(radius=1.2))
    center_x, center_y, radius = _find_disc_geometry(luminance_source)
    src = _crop_square_centered(src, center_x, center_y, radius)
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
