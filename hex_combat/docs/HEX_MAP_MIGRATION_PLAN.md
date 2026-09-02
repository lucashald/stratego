# Hex map migration plan

Status: implemented in the combined `hex_combat` project on 2026-09-01. The
square-grid `new` project remains unchanged as a control. This document is the
migration record; its staged instructions are historical rather than an open
implementation backlog. Balance values remain provisional.

## Goal

Replace the square, four-neighbour battlefield with a hex battlefield so that
movement, vision, melee adjacency, and archer range all use one unambiguous step
metric. In particular, an archer's short shot should reach the six adjacent
hexes and a long shot should reach the twelve hexes exactly two steps away.

This is a board-topology change, not only a drawing change. It affects scenario
geometry, deployment, objectives, the bot, replays, controls, and balance as
well as ranged targeting.

## Recommended foundation

Use **flat-top hexes in an odd-column offset layout**, while continuing to store
locations as `Vector2i(column, row)` and JSON `[column, row]` pairs.

Reasons:

- North and south are true straight neighbours, so the river crossing,
  top/bottom deployment, and campaign front line read naturally.
- Existing positions can be read mechanically even though every shipped map
  still needs to be reviewed and re-authored for the new topology.
- Offset coordinates keep scenario authoring approachable. Axial/cube
  coordinates should be used internally only for distance and rounding.
- It avoids maintaining square and hex engines indefinitely. The migration can
  happen on a branch, but the shipped engine should have one topology.

Before committing to the full migration, build a small interaction spike with a
formation, a river, and range-one/range-two highlights. Confirm that flat-top
hexes, staggered columns, selection, and top-to-bottom movement feel right. If
equal treatment of all four player edges is still a first-class requirement,
also test that explicitly: a rectangular offset map has four boundaries but
six movement directions and may not give every starting edge identical play.

## Rules contract to establish first

Create a small `HexGrid` utility and make it the only owner of topology and
screen conversion. Its public contract should cover:

- the six neighbours of a cell;
- adjacency;
- terrain-agnostic step distance;
- all cells within a radius;
- offset-to-axial/cube conversion and back;
- hex center in pixels;
- hex polygon corners;
- pixel-to-hex conversion using inverse projection and cube rounding;
- board pixel bounds for fitting, panning, and the minimap.

`StrategoGame` can keep wrapper methods such as `neighbors`, `are_adjacent`,
`grid_distance`, and `cells_within_range`. Existing callers then migrate
without learning coordinate details. Remove remaining direct cardinal checks
and hardcoded `[UP, RIGHT, DOWN, LEFT]` lists so the wrappers are genuinely the
single source of truth.

The range contract should be explicit:

- distance 0: the same hex;
- distance 1: melee adjacency and short archer range;
- distance 2: long archer range;
- movement cost: one per adjacent passable hex;
- vision radius: hex distance, subject to later balance tuning;
- no line-of-sight rule is added as part of this migration.

## Migration stages

### 1. Prove topology independently

Add unit tests for the `HexGrid` utility before changing gameplay.

- Every interior cell has six unique neighbours.
- Adjacency and distance are symmetric.
- Each neighbour is distance one.
- A radius-one area contains 7 cells including its origin; radius two contains
  19; radius four contains 61 before board-edge clipping.
- Cells on odd and even rows produce the correct neighbour sets.
- Offset/cube round trips preserve coordinates.
- Pixel-to-hex round trips work at centers and just inside every edge/corner.

Then switch the four topology wrappers in `stratego_game.gd` to `HexGrid` and
replace cardinal-only validation in group and leftover movement. At this stage,
headless rules tests should work even though the visible board is temporarily
wrong.

### 2. Convert rendering and hit testing

Refactor `board_view.gd` around board pixel bounds rather than a square `side`
and a square `cell` rectangle.

- Draw each terrain cell as a six-point polygon.
- Place formations, objectives, fog, selection, order ghosts, shot lines, and
  combat overlays at `HexGrid.cell_center`.
- Replace division-based mouse hit testing with `HexGrid.pixel_to_cell`.
- Size and clamp zoom/pan from the actual staggered map bounds.
- Convert the overview/minimap using the same projection; do not maintain a
  second approximation of the geometry.
- Clip or shape fog and deployment highlights to hex polygons.
- Redraw the bridge and river banks as continuous terrain across staggered
  cells rather than assuming square rectangles.
- Review banner size and march offsets so formations do not overlap adjacent
  rows.

Rendering acceptance: at minimum, verify fit view plus several zoom levels,
both row parities, every board edge, fog, river/bridge terrain, order animation,
combat overlays, and overview navigation with screenshots.

### 3. Replace four-direction interaction

Movement should be primarily map-driven: selecting a formation exposes six
neighbour markers and clicking one issues the step. Group movement uses the
same six direction vectors.

Replace the current four-button movement pad with six direction buttons laid
out like the hex neighbours. Decide and display a six-key mapping rather than
silently overloading the arrow keys. Mouse-only play must remain complete; the
keyboard is a shortcut, not the definition of a legal direction.

Update all player-facing language from “square” to “hex” or the neutral “cell,”
including errors, hints, logs, objective descriptions, and external-control
help.

### 4. Re-author scenarios and objectives

Keep `[column, row]` in campaign JSON, but add explicit map metadata, for
example `grid: "hex_odd_q_flat"`, plus width and height. A missing grid value
must not be guessed after hex maps ship.

Review every setup rather than treating old coordinates as balanced:

- lake shapes and passable gaps;
- the river row, bridge width, and approach lanes;
- fixed formation locations in both campaign battles;
- meeting/skirmish separation and back-rank placement;
- four-player and Crossroads deployment zones;
- center objectives and what counts as a central cell on an even-sized map;
- reach objectives, currently represented by `Rect2i` rectangles.

Replace rectangular reach areas with an explicit set of cells or a named edge
predicate. “Escape through the north edge” is more durable than embedding a
rectangle whose meaning depends on the grid layout.

Do not promise automatic conversion of authored maps. The same numeric cell
may load successfully but have different neighbours, approach lanes, and range
coverage. Re-author and visually inspect each shipped battle.

### 5. Audit bot, simulation, and evaluation logic

The bot already uses `neighbors` and `grid_distance` in many places, so those
callers should inherit hex behavior. Audit the exceptions:

- direct direction lists;
- Euclidean distance-to-center scoring;
- home-edge and center-lane heuristics;
- deployment and formation templates built from rows/columns;
- batch-runner objective and arrival calculations;
- any model input whose spatial features assume four neighbours or a square
  board.

Run deterministic bot-vs-bot smoke tests first, then re-establish balance
baselines. Do not compare win-rate data across the topology change as if it
were the same ruleset.

### 6. Version persistence and external interfaces

Increment the deterministic replay version and record the grid type and board
dimensions in replay setup data and public state exports. The safest initial
policy is to reject old square-grid replays with a clear message and retain
them as archived artifacts; replaying them under hex adjacency would produce a
different match and invalidate their digests.

Add the same topology metadata to campaign battle data and any MCP/API board
state. Coordinate arrays may remain two integers, but their declared coordinate
system becomes part of the contract.

Regenerate committed campaign replays and battle reports only after their maps
are final. Do not overwrite historical square-grid replays without labeling or
archiving them.

### 7. Full regression and balance pass

Convert square-specific tests into topology statements rather than performing
a blind coordinate rewrite. The regression suite should cover:

- paths in all six directions and on both row parities;
- group and leftover movement;
- friendly collision, bounce, follow-up attacks, and contested destinations;
- melee from all six adjacent positions;
- short and long archer shots in every direction, including after movement;
- aimed fire, suppression, moving targets, focus fire, and visibility;
- terrain blocking and bridge crossings;
- fog around edges and obstacles;
- deployment, objectives, withdrawals, and victory conditions;
- bot planning and bounded self-play;
- replay export, JSON round trip, deterministic verification, and tamper
  rejection;
- board clicks near every hex edge and corner, minimap navigation, zoom/pan,
  and order animation.

Finally, playtest map scale and numeric ranges. Hex radii cover more cells than
the current Manhattan-distance diamonds:

| Radius | Square cells | Hex cells |
|---:|---:|---:|
| 1 | 5 | 7 |
| 2 | 13 | 19 |
| 4 | 41 | 61 |

That makes short-range archers threaten six neighbours instead of four, the
distance-two ring contain twelve targets instead of eight, and the current
vision radius expose substantially more ground. Revisit archer range, vision
range, movement allowances, board dimensions, formation count, and terrain
density after the system is correct. Preserve the meaning of a step first;
retune the numbers from playtest evidence second.

## Recommended delivery sequence

1. Interaction/rendering spike and orientation decision.
2. Tested `HexGrid` utility.
3. Headless engine topology conversion.
4. Board rendering, hit testing, minimap, and controls.
5. Scenario/objective re-authoring.
6. Bot and batch tooling audit.
7. Replay/API version bump and fixture regeneration.
8. Full automated, visual, and balance validation.

Keep each stage independently reviewable. Do not combine this migration with
the combat-resolution rewrite: both change archer outcomes, and landing them
together would make regressions and balance shifts difficult to attribute.

## Definition of done

- All gameplay systems use the same six-neighbour distance contract.
- Archer range previews and legal targeting agree in all directions.
- Every rendered hex selects the same engine cell the cursor indicates.
- All shipped scenarios have been deliberately rebuilt and visually checked.
- The bot completes bounded matches without invalid orders or topology-specific
  errors.
- New-format replays reproduce exact final state; old formats fail clearly.
- The complete automated suite passes, visual checks pass, and fresh balance
  runs show no unexplained starting-side advantage.
