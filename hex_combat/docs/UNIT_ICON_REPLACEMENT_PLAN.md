# Unit Icon Replacement Plan

Status: implemented for Blue, Red, Green, and Yellow, including Flags and
faction-specific unknown banners. The planning sections below are retained as
the production record, not as an active asset backlog.

## Implementation progress

- All four faction sets are normalized under `res://assets/unit_icons/`.
- Approved high-resolution sources are retained under
  `res://assets/unit_icons/source/<faction>/`.
- Canonical Infantry, Archer and Cavalry emblems selected for all three Weights.
- All nine runtime files are 512 x 512 with verified exterior alpha.
- An actual-size review sheet is available at
  `res://docs/green_unit_icon_proof.png`.
- All nine Green banners use the same 472 x 472 registration box and 20-pixel
  outer margins; no per-Role optical scaling is applied.
- A player-aware central catalog supplies every faction's formations, Flag,
  and unknown banner.
- Board formations, roster thumbnails and battle cards now reuse that catalog.
- Current Strength, selection, and orders remain live overlays.
- Visible-but-unidentified enemies use faction-specific safe artwork.
- Mipmaps are enabled for clean downscaling at board and roster sizes.
- The deterministic game suite passes all 445 checks.

## Goal

Replace the current code-drawn formation banners with the detailed cloth,
leather and embroidered banner style represented by the PNG experiments in
`res://assets`, while preserving the information the game must communicate at
board scale:

- faction by field colour and material treatment
- Weight by frame weight/material
- Role by a large central emblem
- current Strength by a live numeral
- hidden identity, selection, orders and damage without information leaks

The art should become the shared identity for a formation on the board, in the
formation list and in battle cards. The minimap should remain schematic.

## Recommendation

Use one finished, precomposed banner texture for each faction and formation
type, with Strength and interaction state drawn by the game at runtime.

This fits the supplied artwork better than trying to split it into generic
frames and emblems. In the reference images, cloth folds, wear, border material,
emblem lighting and faction character are integrated. Keeping the finished
banner as one texture preserves that quality and makes the render path simple.

The complete set is 40 banners:

- 4 factions x 9 movable formation types = 36
- 4 faction Flags = 4

The current high-resolution PNGs should be retained as source/reference art.
Game-ready exports should use a consistent canvas and silhouette.

## Implemented Green trial

The runtime lookup is centralized in `res://scripts/unit_icon_catalog.gd`.
`board_view.gd` draws catalog art for revealed movable formations, then adds
live Strength and interaction overlays. `main.gd` uses the same catalog for the
formation roster and battle cards. The minimap remains schematic.

For this first rollout every player intentionally resolves to the Green set.
The small faction-colour marker keeps armies distinguishable without changing
the banner artwork. Hidden enemy identities never select a type-specific
texture, and Flags stay on the existing safe fallback until Flag art exists.

The current asset experiments are not yet directly interchangeable:

- most are 1254 x 1254, with one differently sized image;
- some have transparent exteriors and others have opaque black exteriors;
- silhouettes, borders, emblem scale and empty space vary;
- Green has examples for all nine movable types, Blue and Red are partial,
  Yellow is absent, and no faction has a finished Flag;
- some types have multiple candidates that still need one canonical choice.

The older `UI_UPDATE_PLAN.md` assumption that six component assets cover the
set does not account for the four-faction engine or the faction-specific detail
in the new experiments. This plan supersedes that assumption for formation art.

## Visual contract

Approve this contract before producing the missing art so the set does not
drift again.

### Canvas and silhouette

- Export every runtime banner on a 512 x 512 transparent canvas.
- Use one pointed-bottom silhouette and identical outer bounds for every file.
- Keep at least 4% transparent padding around the frame so glow and selection
  effects do not clip.
- Keep the lower middle visually quiet for the live Strength numeral.
- Keep the emblem in the upper-middle safe zone and make its silhouette survive
  reduction to approximately 40 pixels.
- Remove all opaque black exterior pixels and repair alpha fringes before
  import.

### Information mapping

| Game information | Visual carrier |
|---|---|
| Faction | Blue, Red, Green or Yellow field plus faction-specific fabric/wear |
| Light | narrow, lightly built border |
| Medium | broader iron/silver border |
| Heavy | thick, reinforced or ornate heavy border |
| Infantry | spear/shield family |
| Archer | bow, crossbow or siege-bow family |
| Cavalry | horse/lance family |
| Flag | faction crest or standard emblem, with no Strength numeral |
| Current Strength | large runtime numeral in the lower-middle safe zone |
| Damaged | warm numeral tint; do not bake damage into the texture |
| Selected | external glow/outline; do not recolour the banner |
| Ordered | small external check badge |
| Unknown enemy | faction-specific blank/reverse banner with `?`; no Role or Strength |

Use distinct equipment to reinforce the Weight progression. A recommended
Archer sequence is bow -> crossbow -> catapult/siege bow. Choose one of the
existing alternatives for each slot before the remaining factions are made.

### Size tiers

The same information cannot be legible at every board zoom, so use explicit
render tiers:

1. **Overview, below 44 px per cell:** draw a simplified thumbnail derived from
   the approved banner, plus a large Strength numeral. Do not draw names or
   small decoration.
2. **Board, 44-71 px per cell:** draw the full banner, central emblem and live
   Strength. This is the primary gameplay presentation.
3. **Close, 72 px and above:** use the same banner at higher detail. A short Role
   label may be added only if it does not cover the emblem.

Keep each board banner inside its own cell. Detailed two-cell-tall banners would
obscure formations in adjacent ranks and make selection/hit testing ambiguous.

## Asset production

### 1. Lock a proof set

Use the complete Green set to create a nine-icon comparison sheet at 36, 56 and
88 pixels. Select one canonical candidate for every duplicated type. Review the
set for:

- consistent outer silhouette and border thickness progression;
- unmistakable Infantry, Archer and Cavalry silhouettes;
- a clear Light -> Medium -> Heavy progression within each Role;
- enough quiet space for one- and two-digit Strength values;
- readability over grass, water, fog and selection highlights.

Do not produce the other factions until this sheet is approved.

### 2. Complete the coverage matrix

Create the missing Blue, Red and Yellow formations and four Flags using the
approved proof set as the positional template. Factions may have different
materials and ornament, but emblem placement, silhouette, frame progression
and Strength safe zone must match.

Canonical runtime naming:

```text
res://assets/unit_icons/blue/flag.png
res://assets/unit_icons/blue/li.png
res://assets/unit_icons/blue/mi.png
...
res://assets/unit_icons/yellow/hc.png
```

Keep experiments and full-resolution sources under
`res://assets/unit_icons/source/` or outside the exported game. Do not mix
`_poc`, `_v2` or descriptive alternatives into the runtime directory.

### 3. Normalize and audit

Add a repeatable asset-audit step that fails when a runtime image has the wrong
dimensions, a non-transparent exterior, missing safe-zone space or no catalog
entry. Enable mipmaps/linear filtering for the game-ready textures so the
detailed art downsamples cleanly at Fit zoom.

## Code implementation

### 1. Add a central catalog

Create `res://scripts/unit_icon_catalog.gd` with the only mapping from
`(player, piece.type)` to texture. It should also expose the faction-specific
unknown banner and a temporary fallback to the current procedural treatment.

The catalog should validate all values in `StrategoGame.PLAYER_ORDER` against:

`F, LI, MI, HI, LA, MA, HA, LC, MC, HC`.

Keeping this lookup outside `main.gd` and `board_view.gd` prevents the board,
roster and battle cards from acquiring different naming rules.

### 2. Replace the board base art

In `StrategoBoardView._draw_piece()`:

1. calculate the current cell-relative destination rectangle;
2. draw the existing shadow;
3. draw the revealed catalog texture, or the faction-specific unknown texture;
4. draw live Strength only when identity is revealed and the piece is not a
   Flag;
5. leave selection, order badges and combat overlays above the banner.

During rollout, keep the existing procedural code behind one temporary feature
constant. Remove `_draw_weight_frame()`, `_draw_role_icon()` and the frame
texture cache only after the full matrix and screenshots pass review.

The hidden path must never select a type-specific texture or draw Strength. Use
the existing `is_piece_revealed_to()` decision as the single gate.

### 3. Reuse the art in the HUD

- Replace the roster's two-letter swatch with a cropped `TextureRect` thumbnail,
  while retaining the adjacent full name, Strength and movement pips.
- Replace `_draw_card_shield()` with the same catalog texture and runtime
  Strength overlay at card size.
- Use the same hidden-banner rule when an enemy battle participant is not
  entitled to be identified.
- Leave minimap units as coloured dots; detailed banners at minimap scale would
  add noise without information.

### 4. Preserve interaction geometry

Do not derive hit testing from transparent pixels. Movement, selection,
drag-selection and deployment continue to use the unit's board cell. Selected
banners may glow, but should not scale beyond the cell far enough to cover a
neighbour's Strength or emblem.

## Verification

### Automated checks

- Catalog coverage test for every faction/type pair and every unknown banner.
- Texture load test that reports missing or invalid assets before a match starts.
- Existing deterministic suite through `Test New.bat` to confirm no game,
  movement, fog, replay or combat behavior changed.
- Asset audit for 512 x 512 size, alpha exterior and canonical filenames.

### Screenshot matrix

Use `res://scripts/screenshot.gd` to capture:

- Meeting and four-player scenarios;
- Blue, Red, Green and Yellow formations;
- Fit/overview, default, mid and maximum zoom;
- revealed pieces, visible-but-unknown enemies and fog-hidden pieces;
- selected, group-selected, ordered and damaged formations;
- roster thumbnails and one multi-unit battle card;
- 1600 x 900 plus one smaller supported window size.

Review at actual display size, not only enlarged. In particular, verify that
the detailed texture does not turn into a dark square around 35-44 pixels.

### Acceptance criteria

- Faction, Role and current Strength are readable without opening the inspector
  at default zoom.
- Weight is distinguishable without relying on a letter.
- Every faction/type combination has intentional art; no mixed placeholder set
  ships.
- Hidden units reveal neither Role nor Strength through texture, outline or
  thumbnail.
- No banner covers a neighbouring unit's emblem or Strength.
- Board, roster and battle cards use the same canonical art.
- Fit zoom remains tactically readable and close zoom shows the supplied art's
  material detail.
- No missing-texture warnings or gameplay-test regressions remain.

## Rollout order

1. Approve the Green nine-icon proof sheet and the visual contract.
2. Normalize those nine images and implement the catalog plus board feature
   switch.
3. Validate the three size tiers and hidden-unit treatment with screenshots.
4. Produce and audit the remaining faction/type matrix and four Flags.
5. Switch the board to art by default.
6. Replace roster swatches and battle-card shields.
7. Run the full screenshot matrix and deterministic tests.
8. Remove the temporary procedural fallback and archive obsolete frame assets.

The first review point is deliberately early: one complete faction proves the
style and small-scale readability before time is spent creating the other 31
banners.
