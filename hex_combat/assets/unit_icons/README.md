# Unit icon assets

Runtime textures live in faction folders such as `green/`. Approved
high-resolution working art lives under `source/<faction>/`.

The current Green proof set uses these canonical emblems:

| Code | Formation | Emblem |
|---|---|---|
| LI | Light Infantry | single spear |
| MI | Medium Infantry | round shield and spear |
| HI | Heavy Infantry | reinforced round shield and spear |
| LA | Light Archer | bow |
| MA | Medium Archer | crossbow |
| HA | Heavy Archer | catapult |
| LC | Light Cavalry | galloping horse |
| MC | Medium Cavalry | horse head and lance |
| HC | Heavy Cavalry | armoured horse head and lance |

All runtime PNGs are 512 x 512 with genuine exterior transparency and a shared
centre point. Every banner occupies the same 472 x 472 registration box, leaving
exactly 20 transparent pixels on each outer edge. Their Godot imports generate
mipmaps for clean reduction to board, roster and battle-card sizes.

Until the other faction sets are ready, `UnitIconCatalog` intentionally maps
every movable formation to this Green set. Flags are not included yet.

Regenerate the runtime set and proof sheet from the `new` project directory:

```powershell
python tools/normalize_unit_icons.py `
  --source assets/unit_icons/source/green `
  --output assets/unit_icons/green `
  --proof docs/green_unit_icon_proof.png
```

The proof sheet shows every icon at 88, 56 and 36 pixels. Review that file at
100% scale before approving or replacing source art.
