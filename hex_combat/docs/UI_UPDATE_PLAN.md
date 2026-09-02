# UI Update Plan

Target: replace the current floating-panel HUD with a framed, four-region layout
in the style of the approved mockups — dark navy panels, thin gold borders and
corner flourishes, serif small-caps headers.

Regions:

```
┌──────────────────────── TOP BAR ────────────────────────┐
│ crest · battle name │ objective · progress │ actions     │
├──────────┬───────────────────────────────┬──────────────┤
│ LEFT BAR │            BOARD              │  RIGHT BAR   │
│ (orders) │                               │ (resolution) │
├──────────┴───────────────────────────────┴──────────────┤
│                    PHASE BAR (7 steps)                   │
└──────────────────────────────────────────────────────────┘
```

Left and right bars are mutually exclusive by phase: the left bar is present
while giving orders, the right bar while watching them resolve.

---

## 1. Phase model and naming

Phases are **renamed for display only**. `PHASE_PLANNING`,
`PHASE_LEFTOVER_PLANNING`, `PHASE_RESOLVING` and `PHASE_GAME_OVER` are written
into replay files and the state serializer and must not change.

| # | Display name | Engine source | Sub-steps |
|---|---|---|---|
| 1 | ORDERS | `PHASE_PLANNING` | — |
| 2 | MARCH | movement events, batches `impulse_1..3` | **3 dots** |
| 3 | MELEE | `melee`, `crossing_battle`, and the `retreat` / `retreat_battle` events that follow from them | **3 dots** |
| 4 | MISSILES | `ranged` / `ranged_fizzle` events | — |
| 5 | REPOSITION | `PHASE_LEFTOVER_PLANNING` + `leftover` events | — |
| 6 | END TURN | round rollover | — |

MARCH and MELEE each carry three dots, one per impulse, because there really are
three of each and they alternate. The rest take a single state dot rather than
pretending to sub-steps they do not have.

**Rout is not a phase.** `_resolve_movement_batch` resolves a melee batch and
then the retreats caused by that batch, so a retreat belongs to a specific
battle rather than to a step of its own. It is already reported where it
belongs: the `RETREAT DESTINATION` row of the battle that caused it.

### A mismatch to resolve before building this

The engine does **not** resolve melee and retreats as separate global phases.
`_resolve_movement_batch` runs moves, then battles, then retreats *within each
impulse*, so a round interleaves March → Melee → Rout → March → Melee → Rout.

A strictly left-to-right bar therefore misrepresents the round. Two
options:

**Settled: the bar is a legend, not a progress track.** Whichever step owns the
current event lights up, so highlighting moves MARCH -> MELEE -> MARCH -> MELEE
as the impulses play, and the paired dot rows make that legible: three marches,
three melees, one melee for each march. The bar is allowed to jump backwards.

The alternative — regrouping so all melee is shown after all movement — was
rejected. It reads more tidily left to right but stops reflecting the order
things actually happen in, and simultaneity is the point of the game.

### Auto-advance and skipping

- **Enter** advances the current phase. This is the primary control.
- **Enter advances everything** — one event, then the next, then through the
  phase boundary into the following phase. A player should be able to press
  Enter a handful of times and arrive at the next turn without ever reaching for
  the mouse. This makes keyboard-only play the default path rather than an
  accessibility afterthought.
- Phases where the local player has **no decision to make** play through without
  stopping. A phase with no events visible to the viewing player and no order to
  give is skipped.
- **REPOSITION auto-advances when nothing is eligible.** If no formation can take
  a leftover step there is nothing to decide, so the phase does not stop. When it
  does stop, arrow keys issue the moves, so even that stays on the keyboard.
- ORDERS always stops.
- The **END TURN** chevron is clickable and jumps to the end of the round,
  resolving whatever remains without pausing.

---

## 2. Top bar

Replaces the current objective panel, phase banner and top-right button cluster
with a single framed strip.

Left: faction crest, then the battle name in gold serif small-caps.
Centre: `OBJECTIVE: <text>` with progress pips (filled = rounds held).
Right: the action buttons.

The primary button is **`END <PHASE>`** and relabels with the current phase:
`END ORDERS`, `END REPOSITION`, and so on. Then `UNDO`, then `CANCEL ALL` in
red. Enter triggers the primary button.

Objective text and pip count come from `describe_objectives()`, which already
returns a one-line `summary` plus progress, so this needs no new engine work.

---

## 3. Sidebars

**Both sidebars are present in every phase.** Only their contents change. This
is the layout's core rule: a region never disappears and never changes job, so
the user learns one place to look for each kind of question and it is always
right.

Each side owns a channel:

- **Left is the list channel.** What exists, and what has happened. Always a
  scrolling list of many items.
- **Right is the detail channel.** One thing, examined closely. Always a single
  subject in depth.

| | Left (list) | Right (detail) |
|---|---|---|
| ORDERS | your formations, with the event log on a toggle | the selected formation, or an examined enemy |
| MARCH / MELEE / MISSILES | the event log for this round | ACTIVE BATTLE |
| REPOSITION | formations still able to act | the selected formation |

The phase changes what fills a panel, never which panel to look at. A player who
learns "unit details are on the right" during orders finds battle details on the
right during resolution, because those are the same question.

### Left, order phase — formation list

Every formation you command, not only the selected ones, so the panel is never
empty and doubles as a roster. Selected entries are highlighted, and clicking one
selects it on the board. Each row:

- banner thumbnail, name in serif small-caps, current strength on a shield glyph
- `MOVEMENT` pips: one per point, filled for unspent, hollow for spent
- a small marker when the formation already has orders

**Tabs** at the top switch to the **event log** without leaving the phase. Tabs
cost the roster some vertical space, and that is the right trade: the log should
always be *reachable* even though it is rarely the thing you want to look at, and
a tab makes it a glance away rather than a mode change.

### Left, resolution — event log

The round's events in order, the current one highlighted, scrolling as playback
advances. Clicking an entry jumps playback to it, which subsumes the battle-queue
idea from the earlier mockup: a battle is just an event worth jumping to, and a
single list handles moves, battles and shots without a separate queue panel.

**Granularity: where a formation ended up, and every battle.** An impulse in
which nothing happened is not worth a row, and a formation's march is one entry
naming its destination rather than one row per square.

Filtering and search come later but should be designed for now, because they
decide the row format. The range runs from battle results only, through
movement and battles, to everything including dice rolls — so a row needs a
type, an owning formation, and a detail payload that can be shown or withheld.

### Right, order phase — inspector

The selected formation in full: banner, name, weight and role with what each
does, current and maximum strength, armour, movement remaining, and its current
orders in words. This is also where **Examine** lands, so inspecting an enemy
fills the same panel with what the player is entitled to know about it — which
for an unidentified enemy is honestly little, and showing that emptiness is
itself informative.

With nothing selected, show the formation under the cursor, and failing that the
terrain of the hovered square.

### Right, resolution — active battle

As specified in section 4 below.

---

## 4. Active battle panel

Header `ACTIVE BATTLE`, then:

- two facing unit banners, blue left and red right, with `STARTING STRENGTH`
  beneath each and a crossed-swords glyph between them
- a result line in large coloured caps — `BLUE CAVALRY WINS`
- a consequence line beneath — `Red Infantry retreats north`
- the comparison table
- `PREVIOUS` and `NEXT BATTLE` buttons

### Table rows

| Row | Source |
|---|---|
| ROLL | `raw_rolls` |
| ROLE BONUS | `role_bonuses` |
| FINAL SCORE | `scores` |
| RAW DAMAGE | opponent's final score |
| ARMOR | shown negative; doubled for the winner |
| DAMAGE TAKEN | `damage` |
| REMAINING STRENGTH | piece strength after resolution |
| RETREAT DESTINATION | arrow glyph, loser's column only |

Add a **NATURAL 10** row when a raw roll is 10, showing `+1`. Score is capped by
current Strength, so a weakened formation can roll 10, score 4, and deal 5 — the
single most confusing thing in the game without this row.

`role_bonuses` and `capped_rolls` were added to combat events for this. A
`CAPPED BY STRENGTH` row is optional but explains the gap between ROLL and
FINAL SCORE directly.

Multiway battles do not fit two columns. Keep the existing stacked list for
three or more participants.

When the current event is not a battle — a move, a fizzled shot — the panel
shows that event's detail rather than emptying. The region always has a subject.

---

## 5. Phase bar

Six right-pointing chevrons across the bottom. Each carries a circled numeral,
a gold icon, a name in small-caps, and state dots. The active chevron is filled
blue with a brighter gold border. Completed dots are green, pending are hollow.

Clicking a completed step reviews it; clicking END TURN skips to the end.

---

## 6. Unit banners

Replace the procedurally drawn banner. New design, from the approved art:

- pentagon banner, square top with a pointed bottom
- **frame material carries Weight**: wood = Light, silver = Medium, gold = Heavy
- field is the player's colour
- role emblem centred, tinted lighter than the field
- unit name in two lines of serif caps above the emblem
- **current strength** as a large numeral below it

This replaces the wood/mail/plate frames currently drawn in code — same idea,
but wood/silver/gold reads more clearly and matches the art.

Composite in code rather than exporting eighteen images: three frame PNGs with
transparent centres, three role emblems, field colour and text drawn per side.
Six assets cover all nine unit types in both colours.

Banners are roughly two cells tall and sit above the grid rather than inside one
square. At low zoom the name drops and only the emblem and numeral remain.

---

## 6b. Board rendering, viewport and minimap

The board no longer tries to fit the window. Banners are sized to stay legible
and carry two lines of text, so a 20x20 board is larger than the viewport and
**scrolls**. A minimap is what makes that navigable, and it settles the sizing
question that was previously open.

**Terrain is painted art, not computed fills.** Grass with texture variation,
worn dirt patches, scattered rocks and shrubs, tiled from the terrain sheets.
The current per-cell colour-plus-noise fill is what makes the board read as a
spreadsheet rather than ground.

**A treeline frames the play area** on all four edges, outside the grid. This
replaces the bokeh circles in `_draw_surroundings`.

**Grid lines** are thin and gold, drawn over the terrain at low opacity — present
enough to count squares, faint enough not to dominate.

**Coordinate strips** are dark navy bars along the top and left edges with gold
numerals, part of the board frame rather than text floating over the field.
Engine numbering 0-19, matching logs, replays and the command bridge.

### MAP OVERVIEW panel

Bottom-right, framed like every other panel:

- **the same board, drawn smaller.** Not a schematic or a second representation:
  the same draw path at a reduced scale. Fog is then inherited rather than
  reimplemented, since the existing code already refuses to draw formations the
  viewing player cannot see. A parallel schematic could drift out of step with
  the real visibility rules and silently leak positions; this cannot.
- a blue rectangle marking the current viewport, draggable to pan
- zoom controls beneath: `-`, current percentage, `+`, `FIT`

`FIT` zooms out far enough to show the whole board, which is the mode the
current build is permanently stuck in. The zoom floor should rise well above
today's 0.9 now that panning exists; being unable to read a banner is worse than
being unable to see every square at once.

Clicking anywhere on the minimap centres the viewport there.

---

## 7. Right-click context menu

Replaces the current `PopupMenu` with a framed panel: gold icons, serif labels,
and a chevron notch on the highlighted row.

| Item | Icon | Shown when |
|---|---|---|
| INSPECT | eye | always, on any visible formation |
| ATTACK | crossed swords | an Archer is selected and the target is a legal shot |
| VOLLEY | arrow spread | an Archer is selected and the square can be suppressed |

`ATTACK` is aimed fire at a formation, `VOLLEY` is suppressing fire at a square.
`declared_shot_type_for()` already gates both, so the menu shows only what the
engine would accept.

---

## 8. Assets

Have: terrain grass/forest/river, riverbank props, wooden bridge, blank banner,
role emblems, faction crests, combat icons, timeline icons, combat effects,
panel texture, lake tile.

Needed:

- three banner frames — wood, silver, gold — with transparent centres
- six phase icons: shield/star, boot, crossed swords, bow, flag, hourglass
- three context-menu icons: eye, crossed swords, volley
- panel corner flourishes, header dividers and the chevron notch
- shield glyph for the strength readout
- small event-type glyphs for the log: move, clash, shot, retreat, fizzle
- filled and hollow movement pips
- a treeline border to frame the play area

Existing sheets are multi-icon and need slicing plus black-to-alpha keying.

---

## 9. Order of work

1. **Phase model.** Display names, the six-step mapping, Enter to advance,
   auto-advance on empty phases, END TURN to skip. No art, fully testable.
2. **Layout regions.** Reserve top bar, left sidebar, board, right sidebar and
   phase bar so nothing floats over the board. Everything else depends on this.
3. **Viewport and minimap.** Board scrolls instead of fitting; raise the zoom
   floor. Do this before the banners, because it decides how much room a banner
   has.
4. **Phase bar.**
5. **Top bar.**
6. **Right sidebar**, both states: inspector during orders, active battle during
   resolution.
7. **Left sidebar**, both states: formation list during orders, event log during
   resolution.
8. **Banner art**, once the frames exist.
9. **Context menu restyle.**
10. **Painted terrain and treeline**, replacing the computed fills.

Steps 1 to 3 are structural. Steps 4 to 7 are independent of each other and can
each be checked by screenshot. Steps 8 and 10 are the art swap and can land last
without blocking anything.

---

## 10. Open questions

Most of this section has been settled and folded into the sections above: phase
bar semantics, REPOSITION skipping, Enter behaviour, minimap fog and fidelity,
the sidebar toggle, and log granularity.

Still open:

- **Do MELEE dots skip empty impulses?** If impulse 2 produced no battles, does
  its dot stay hollow while 1 and 3 fill, or does the row compact? Hollow is
  more honest and keeps the dots aligned with the MARCH row above.
- **Event log row format**, in enough detail to support the eventual filters
  without a rewrite: type, formation, and a withheld detail payload.
- **Heavy Cavalry still does not reach the fight** even after the deployment
  change, and it is a bot pathing problem rather than a UI one. Noted here only
  so it is not lost.
