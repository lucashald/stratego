"""Turn approved concept renders into normalizer-ready source art.

The concept banners arrive as flat RGB images on a solid backdrop, while the
normalizer finds a banner's content box from its alpha channel. Handed an RGB
image it would treat the whole canvas as content and bake the backdrop into the
icon, so the exterior has to be keyed out first.

The backdrop is a flat colour, so the exterior is grown inward from the border
rather than removed by a model: it is deterministic, it reproduces exactly on
another machine, and it leaves the banner's edge trim untouched. Only pixels
reachable from the border are cleared, so a backdrop-coloured pixel enclosed by
the banner survives.

    python tools/prepare_faction_icons.py --faction yellow
    python tools/normalize_unit_icons.py \\
        --source assets/unit_icons/source/yellow \\
        --output assets/unit_icons/yellow \\
        --proof docs/yellow_unit_icon_proof.png
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

# Chosen on how each candidate reads once the board has shrunk it to about 36
# pixels, which is where a thin or low-contrast emblem disappears. Both factions
# take the crossbow for Medium Archer: the alternatives reduce to a faint
# horizontal smudge, while the crossbow keeps a readable cross.
PICKS = {
    "blue": {
        # Rebuilt from the concept renders in the assets root, which are a
        # different artwork from the set Blue originally shipped: full-bleed,
        # near square, with a heavy metal-bound border. That border is also a
        # stronger Weight cue than the plain edge it replaces, which matters
        # now that Weight is public on sight.
        "li": "banner_blue_light_infantry_spear_cloth_poc_v2.png",
        "mi": "banner_blue_medium_infantry_shield_spear_cloth_poc_v2.png",
        "hi": "banner_blue_heavy_infantry_shield_spear_cloth_poc_v2.png",
        "la": "banner_blue_light_archer_bow_cloth_poc_v2.png",
        "ma": "banner_blue_medium_archer_crossbow_cloth_v3.png",
        # Two candidates here; the realistic catapult is the newer one and the
        # reason the set was rebuilt at all.
        "ha": "banner_blue_heavy_archer_realistic_catapult_v3.png",
        "lc": "banner_blue_light_cavalry_horse_cloth_poc_v2.png",
        "mc": "banner_blue_medium_cavalry_lance_cloth_poc_v2.png",
        "hc": "banner_blue_heavy_cavalry_armored_cloth_poc_v2.png",
    },
    "yellow": {
        "li": "banner_yellow_light_infantry_quilted_linen_poc.png",
        "mi": "banner_yellow_medium_infantry_quilted_linen_poc.png",
        "hi": "banner_yellow_heavy_infantry_quilted_linen_poc.png",
        "la": "banner_yellow_light_archer_quilted_linen_poc.png",
        "ma": "banner_yellow_medium_archer_crossbow_quilted_linen_v2.png",
        "ha": "banner_yellow_heavy_archer_realistic_catapult_v2.png",
        "lc": "banner_yellow_light_cavalry_quilted_linen_poc.png",
        "mc": "banner_yellow_medium_cavalry_quilted_linen_poc.png",
        "hc": "banner_yellow_heavy_cavalry_quilted_linen_poc.png",
    },
    "red": {
        # The older red `_poc` archers were passed over: they carry opaque
        # black exteriors and a different lighting treatment, so mixing them in
        # would break the set's consistency.
        "li": "banner_red_light_infantry_leather_bright_lighting_v2.png",
        "mi": "banner_red_medium_infantry_leather_bright_lighting_v2.png",
        "hi": "banner_red_heavy_infantry_leather_bright_lighting_v2.png",
        "la": "banner_red_light_archer_leather_bright_lighting_v2.png",
        "ma": "banner_red_medium_archer_crossbow_leather_bright_lighting_v3.png",
        "ha": "banner_red_heavy_archer_leather_bright_lighting_v2.png",
        "lc": "banner_red_light_cavalry_leather_bright_lighting_v2.png",
        "mc": "banner_red_medium_cavalry_leather_bright_lighting_v2.png",
        "hc": "banner_red_heavy_cavalry_leather_bright_lighting_v2.png",
    },
}

# Tried in ascending order; the widest one that does not start eating the
# banner wins. A single fixed value cannot serve every faction: Yellow and Red
# sit on a noisy grey backdrop that a tight tolerance cannot bridge, so the fill
# never propagates and nothing is removed, while Blue sits on near-black and its
# own dark cloth falls within a wide tolerance of it, so the fill crosses the
# edge and hollows the banner out. What separates them is not the backdrop but
# how close the banner's own colour sits to it, which is only knowable per
# image.
TOLERANCES = (8, 12, 16, 20, 26, 32, 40)
# A banner is a pentagon on a square canvas, so roughly an eighth of its own
# box is legitimately empty below the point. Past this the fill has crossed
# into the cloth.
MAX_INTERIOR_HOLES = 0.16


def key_exterior(image: Image.Image, tolerance: int) -> Image.Image:
    """Clear the flat backdrop, working inward from the border."""
    rgb = np.asarray(image.convert("RGB")).astype(np.int16)
    height, width, _ = rgb.shape
    border = np.concatenate([rgb[0, :, :], rgb[-1, :, :], rgb[:, 0, :], rgb[:, -1, :]])
    backdrop = np.median(border, axis=0)
    close = np.sqrt(((rgb - backdrop) ** 2).sum(2)) < tolerance

    seen = np.zeros((height, width), bool)
    queue: deque = deque()
    for x in range(width):
        for y in (0, height - 1):
            if close[y, x] and not seen[y, x]:
                seen[y, x] = True
                queue.append((y, x))
    for y in range(height):
        for x in (0, width - 1):
            if close[y, x] and not seen[y, x]:
                seen[y, x] = True
                queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < height and 0 <= nx < width and close[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                queue.append((ny, nx))

    out = np.asarray(image.convert("RGBA")).copy()
    out[..., 3] = np.where(seen, 0, 255)
    return Image.fromarray(out, "RGBA")


def _interior_holes(keyed: Image.Image) -> tuple[float, tuple | None]:
    """How much of the banner's own box was cleared, and that box."""
    mask = keyed.getchannel("A").point(lambda v: 255 if v > 2 else 0)
    box = mask.getbbox()
    if box is None:
        return 1.0, None
    inner = np.asarray(mask.crop(box))
    return float((inner == 0).sum()) / inner.size, box


def key_best(image: Image.Image) -> tuple[Image.Image, int]:
    """Key with the widest tolerance that leaves the banner intact."""
    best = None
    for tolerance in TOLERANCES:
        keyed = key_exterior(image, tolerance)
        holes, box = _interior_holes(keyed)
        if box is None:
            continue
        removed = 1.0 - ((box[2] - box[0]) * (box[3] - box[1])) / (image.width * image.height)
        # Nothing removed means the fill never propagated; too many holes means
        # it propagated into the cloth. Only the ones in between are candidates.
        if removed > 0.001 and holes <= MAX_INTERIOR_HOLES:
            best = (keyed, tolerance)
    if best is None:
        # Full bleed: the banner runs to the canvas edge, so there is no
        # backdrop to remove and the whole image is content. Returning it
        # opaque is correct, but it also means this banner cannot share a
        # shape with siblings that were photographed with a margin.
        opaque = image.convert("RGBA")
        opaque.putalpha(255)
        return opaque, 0
    return best


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--faction", required=True, choices=sorted(PICKS))
    parser.add_argument("--assets", default="assets")
    args = parser.parse_args()

    assets = Path(args.assets)
    destination = assets / "unit_icons" / "source" / args.faction
    destination.mkdir(parents=True, exist_ok=True)

    aspects: list[float] = []
    full_bleed: list[str] = []
    for code, filename in PICKS[args.faction].items():
        source = assets / filename
        if not source.exists():
            raise SystemExit(f"missing source art: {source}")
        with Image.open(source) as opened:
            keyed, tolerance = key_best(opened)
        box = keyed.getchannel("A").point(lambda v: 255 if v > 2 else 0).getbbox()
        if box is None:
            raise SystemExit(f"{filename}: keying removed the whole image")
        # Whether the exterior went is a question about the corners, not about
        # how much of the canvas the banner fills: art framed tightly, or
        # casting a wide soft shadow, legitimately covers most of it.
        alpha = keyed.getchannel("A")
        corners = [alpha.getpixel(p) for p in
                   ((3, 3), (keyed.width - 4, 3), (3, keyed.height - 4),
                    (keyed.width - 4, keyed.height - 4))]
        if tolerance == 0:
            # Full bleed, flagged rather than rejected: opaque corners are
            # correct here, but this banner has no margin of its own and so
            # cannot register against siblings that do.
            full_bleed.append(code)
        elif any(value > 2 for value in corners):
            raise SystemExit(f"{filename}: exterior not removed, corner alpha {corners}")
        aspects.append((box[2] - box[0]) / (box[3] - box[1]))
        keyed.save(destination / f"{code}.png")
        holes, _ = _interior_holes(keyed)
        print(f"{args.faction}/{code}.png  <- {filename}  (tol {tolerance}, holes {holes:.0%})")

    # The normalizer stretches every banner into one shared registration box, so
    # sources that disagree about their own proportions each get a different
    # distortion and the set stops looking like a set. Green, already approved,
    # spans 0.085, so that is the working tolerance.
    if full_bleed:
        print(f"  NOTE: full bleed, no margin of their own: {', '.join(full_bleed)}")
    spread = max(aspects) - min(aspects)
    print(f"aspect spread {spread:.3f} across {len(aspects)} banners")
    if spread > 0.09:
        print(f"  WARNING: wider than the approved Green set (0.085). Banners will be "
              f"stretched inconsistently against each other.")


if __name__ == "__main__":
    main()
