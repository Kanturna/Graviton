from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter


def _find_disc_geometry(alpha: Image.Image) -> tuple[float, float, float]:
    bbox = alpha.getbbox()
    width, height = alpha.size
    if bbox is None:
        return width * 0.5, height * 0.5, min(width, height) * 0.45

    left, top, right, bottom = bbox
    center_x = (left + right - 1) * 0.5
    center_y = (top + bottom - 1) * 0.5
    radius = max(right - left, bottom - top) * 0.5
    return center_x, center_y, max(1.0, radius)


def _crop_square_centered(source: Image.Image, center_x: float, center_y: float, radius: float) -> Image.Image:
    half_extent = max(1.0, radius * 1.05)
    extent = max(2, int(round(half_extent * 2.0)))
    left = int(math.floor(center_x - half_extent))
    top = int(math.floor(center_y - half_extent))
    right = left + extent
    bottom = top + extent

    cropped = Image.new("RGBA", (extent, extent), (0, 0, 0, 0))
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


def _smooth_profile(profile: list[float], window: int = 7) -> list[float]:
    out: list[float] = []
    for i in range(len(profile)):
        start = max(0, i - window)
        end = min(len(profile), i + window + 1)
        values = profile[start:end]
        if not values:
            out.append(1.0)
            continue
        out.append(sum(values) / len(values))
    return out


def _build_radial_luma_profile(luma: Image.Image, alpha: Image.Image, radius_px: float) -> list[float]:
    bins = 256
    sums = [0.0] * bins
    counts = [0] * bins
    pixels_l = luma.load()
    pixels_a = alpha.load()
    size = luma.size[0]
    cx = (size - 1) * 0.5
    cy = (size - 1) * 0.5

    for y in range(size):
        for x in range(size):
            a = pixels_a[x, y]
            if a <= 16:
                continue
            dx = x - cx
            dy = y - cy
            dist = math.hypot(dx, dy)
            if dist > radius_px * 0.97:
                continue
            t = min(0.999, dist / max(radius_px, 1.0))
            idx = min(bins - 1, int(t * bins))
            sums[idx] += pixels_l[x, y]
            counts[idx] += 1

    profile: list[float] = []
    last_value = 128.0
    for i in range(bins):
        if counts[i] > 0:
            last_value = sums[i] / counts[i]
        profile.append(last_value)
    return _smooth_profile(profile)


def _flatten_radial_shading(image: Image.Image) -> Image.Image:
    rgba = image.copy().convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = rgba.convert("RGB")
    luma = rgb.convert("L")
    size = rgba.size[0]
    cx = (size - 1) * 0.5
    cy = (size - 1) * 0.5
    radius_px = size * 0.46

    profile = _build_radial_luma_profile(luma, alpha, radius_px)
    profile_sample = profile[int(len(profile) * 0.42):int(len(profile) * 0.70)]
    target = sum(profile_sample) / max(len(profile_sample), 1)
    pixels_rgba = rgba.load()
    pixels_a = alpha.load()

    for y in range(size):
        for x in range(size):
            a = pixels_a[x, y]
            if a <= 0:
                pixels_rgba[x, y] = (0, 0, 0, 0)
                continue

            dx = x - cx
            dy = y - cy
            dist = math.hypot(dx, dy)
            t = min(0.999, dist / max(radius_px, 1.0))
            idx = min(len(profile) - 1, int(t * len(profile)))
            radial_luma = max(profile[idx], 1.0)
            flatten = target / radial_luma
            flatten = 1.0 + (flatten - 1.0) * 0.82
            flatten = min(1.85, max(0.75, flatten))

            r, g, b, _ = pixels_rgba[x, y]
            pixels_rgba[x, y] = (
                min(255, max(0, int(r * flatten))),
                min(255, max(0, int(g * flatten))),
                min(255, max(0, int(b * flatten))),
                a,
            )

    return rgba


def _apply_detail_and_mask(image: Image.Image) -> Image.Image:
    rgba = image.copy().convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = rgba.convert("RGB")
    luma = rgb.convert("L")
    blurred = luma.filter(ImageFilter.GaussianBlur(radius=3.2))
    color_blur = rgb.filter(ImageFilter.GaussianBlur(radius=22.0))
    size = rgba.size[0]
    cx = (size - 1) * 0.5
    cy = (size - 1) * 0.5
    inner_radius = size * 0.43
    outer_radius = size * 0.47

    pixels_rgba = rgba.load()
    pixels_a = alpha.load()
    pixels_l = luma.load()
    pixels_b = blurred.load()
    pixels_cb = color_blur.load()

    avg_r = 0.0
    avg_g = 0.0
    avg_b = 0.0
    avg_count = 0.0
    for y in range(size):
        for x in range(size):
            a = pixels_a[x, y]
            if a <= 32:
                continue
            dx = x - cx
            dy = y - cy
            if math.hypot(dx, dy) > inner_radius:
                continue
            r, g, b, _ = pixels_rgba[x, y]
            w = a / 255.0
            avg_r += r * w
            avg_g += g * w
            avg_b += b * w
            avg_count += w

    if avg_count <= 0.0:
        avg_color = (124.0, 110.0, 96.0)
    else:
        avg_color = (
            avg_r / avg_count,
            avg_g / avg_count,
            avg_b / avg_count,
        )

    for y in range(size):
        for x in range(size):
            a = pixels_a[x, y]
            if a <= 0:
                pixels_rgba[x, y] = (0, 0, 0, 0)
                continue

            detail = (pixels_l[x, y] - pixels_b[x, y]) / 255.0
            r, g, b, _ = pixels_rgba[x, y]
            br, bg, bb = pixels_cb[x, y]
            local_r = avg_color[0] + (r - br) * 0.42
            local_g = avg_color[1] + (g - bg) * 0.42
            local_b = avg_color[2] + (b - bb) * 0.42
            detail_gain = 1.0 + detail * 1.45
            r = min(255, max(0, int(local_r * detail_gain)))
            g = min(255, max(0, int(local_g * detail_gain)))
            b = min(255, max(0, int(local_b * detail_gain)))

            dist = math.hypot(x - cx, y - cy)
            if dist >= outer_radius:
                mask = 0.0
            elif dist <= inner_radius:
                mask = 1.0
            else:
                mask = 1.0 - (dist - inner_radius) / max(outer_radius - inner_radius, 1.0)
            mask *= a / 255.0
            pixels_rgba[x, y] = (r, g, b, min(255, max(0, int(mask * 255.0))))

    out = ImageEnhance.Contrast(rgba).enhance(1.10)
    out = ImageEnhance.Sharpness(out).enhance(1.18)
    return out


def _build_reference_map(source_path: Path, output_path: Path, size: int) -> None:
    src = Image.open(source_path).convert("RGBA")
    center_x, center_y, radius = _find_disc_geometry(src.getchannel("A"))
    src = _crop_square_centered(src, center_x, center_y, radius)
    src = src.resize((size, size), Image.Resampling.LANCZOS)
    src = _flatten_radial_shading(src)
    src = _apply_detail_and_mask(src)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    src.save(output_path)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Derive a hybrid-friendly planet/moon reference map from a user-provided beauty render."
    )
    parser.add_argument("--input", required=True, help="Input planet or moon PNG path")
    parser.add_argument("--output", required=True, help="Output PNG path")
    parser.add_argument("--size", type=int, default=512, help="Output square size in pixels")
    args = parser.parse_args()

    _build_reference_map(Path(args.input), Path(args.output), args.size)


if __name__ == "__main__":
    main()
