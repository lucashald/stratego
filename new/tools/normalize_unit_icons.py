"""Normalize approved unit-banner sources into aligned runtime textures.

The source art may use different canvas sizes and transparent margins. Runtime
icons all receive the same 512 x 512 canvas and the same 20-pixel content box so
the board can swap textures without the banner jumping or changing scale.

Usage from the ``new`` project directory::

    python tools/normalize_unit_icons.py \
        --source assets/unit_icons/source/green \
        --output assets/unit_icons/green \
        --proof docs/green_unit_icon_proof.png
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


UNIT_CODES = ("li", "mi", "hi", "la", "ma", "ha", "lc", "mc", "hc")
CANVAS_SIZE = 512
PADDING = 20
ALPHA_THRESHOLD = 2


def _content_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    if ALPHA_THRESHOLD > 0:
        alpha = alpha.point(lambda value: 255 if value > ALPHA_THRESHOLD else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("image contains no visible pixels")
    return bbox


def normalize(source: Path, destination: Path, fit: bool = False) -> None:
    with Image.open(source) as opened:
        image = opened.convert("RGBA")

    bbox = _content_bbox(image)
    visible = image.crop(bbox)
    target_extent = CANVAS_SIZE - PADDING * 2

    if fit:
        # Scale uniformly and pad the short side with transparency. The banner
        # keeps its true proportions, and centres agree, at the cost of sets
        # whose sources disagree about their shape ending up different widths.
        # That is the honest presentation of inconsistent art rather than a
        # per-image stretch that hides it.
        scale = min(target_extent / visible.width, target_extent / visible.height)
        size = (max(1, round(visible.width * scale)), max(1, round(visible.height * scale)))
        visible = visible.resize(size, resample=Image.Resampling.LANCZOS)
        offset = ((CANVAS_SIZE - size[0]) // 2, (CANVAS_SIZE - size[1]) // 2)
    else:
        # Every banner is forced to the same square registration box. Within a
        # set whose sources agree this is invisible, and it guarantees textures
        # swap without the banner changing size. Across a set that does not
        # agree, each image is stretched by a different amount.
        visible = visible.resize(
            (target_extent, target_extent),
            resample=Image.Resampling.LANCZOS,
        )
        offset = (PADDING, PADDING)
    normalized = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    normalized.alpha_composite(visible, offset)

    destination.parent.mkdir(parents=True, exist_ok=True)
    normalized.save(destination, format="PNG", optimize=True)

    with Image.open(destination) as check:
        if check.size != (CANVAS_SIZE, CANVAS_SIZE):
            raise ValueError(f"{destination}: unexpected output size {check.size}")
        corners = (
            check.getpixel((0, 0))[3],
            check.getpixel((CANVAS_SIZE - 1, 0))[3],
            check.getpixel((0, CANVAS_SIZE - 1))[3],
            check.getpixel((CANVAS_SIZE - 1, CANVAS_SIZE - 1))[3],
        )
        if any(corners):
            raise ValueError(f"{destination}: exterior is not transparent: {corners}")


def build_proof(output_dir: Path, destination: Path) -> None:
    previews = (88, 56, 36)
    column_width = 108
    header_height = 30
    row_heights = (112, 80, 60)
    label_width = 50
    sheet_width = label_width + column_width * len(UNIT_CODES)
    sheet_height = header_height + sum(row_heights)
    background = (13, 22, 20, 255)
    cell = (67, 82, 52, 255)
    grid = (126, 139, 92, 90)
    gold = (224, 196, 124, 255)

    sheet = Image.new("RGBA", (sheet_width, sheet_height), background)
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()

    for index, code in enumerate(UNIT_CODES):
        x = label_width + index * column_width
        draw.text((x + column_width // 2, 10), code.upper(), font=font, fill=gold, anchor="mm")

    y = header_height
    for preview_size, row_height in zip(previews, row_heights):
        draw.text((label_width // 2, y + row_height // 2), f"{preview_size}px", font=font, fill=gold, anchor="mm")
        for index, code in enumerate(UNIT_CODES):
            x = label_width + index * column_width
            tile_left = x + 6
            tile_top = y + 4
            tile_right = x + column_width - 6
            tile_bottom = y + row_height - 4
            draw.rectangle((tile_left, tile_top, tile_right, tile_bottom), fill=cell)
            draw.line((tile_left, (tile_top + tile_bottom) // 2, tile_right, (tile_top + tile_bottom) // 2), fill=grid)
            draw.line(((tile_left + tile_right) // 2, tile_top, (tile_left + tile_right) // 2, tile_bottom), fill=grid)
            with Image.open(output_dir / f"{code}.png") as opened:
                icon = opened.convert("RGBA").resize((preview_size, preview_size), Image.Resampling.LANCZOS)
            icon_x = x + (column_width - preview_size) // 2
            icon_y = y + (row_height - preview_size) // 2
            sheet.alpha_composite(icon, (icon_x, icon_y))
        y += row_height

    destination.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(destination, format="PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--proof", type=Path)
    parser.add_argument("--fit", action="store_true",
                        help="scale uniformly and pad, instead of stretching to the square box")
    args = parser.parse_args()

    missing = [code for code in UNIT_CODES if not (args.source / f"{code}.png").is_file()]
    if missing:
        raise SystemExit(f"missing source icons: {', '.join(missing)}")

    for code in UNIT_CODES:
        source = args.source / f"{code}.png"
        destination = args.output / f"{code}.png"
        normalize(source, destination, args.fit)
        print(f"normalized {code}: {source} -> {destination}")

    if args.proof:
        build_proof(args.output, args.proof)
        print(f"proof sheet: {args.proof}")


if __name__ == "__main__":
    main()
