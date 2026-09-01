# Handoff: combat resolution rewrite

Status as of 2026-09-01. Nothing in this document has been implemented in the
engine yet — this is design work plus a standalone model. The engine still runs
the current (d10-cap) rules.

## Why we're doing this

Hidden Strength wasn't mattering. Under the current rules a formation's roll is
`min(1d10, current_strength) + ROLE_BONUS`, so Strength only ever bites when the
die would have exceeded it — for a Strength-6 vs Strength-8 unit, that's only
rolls of 7 or 8. The die decides the fight and Strength nudges it, which makes
"do I know this enemy's Strength" a nearly irrelevant question. Most real
decisions in the game were coming from role and objective instead.

Design constraint the user stated, and which the new rules honor:
**Strength is damage. Weight is armor and speed only.**

## The variant to build first

Deliberately the stripped-down baseline — no armor stat, no tie damage, no
positional modifiers. The point is to isolate variables, so that when tie
damage, armor, cover, or high-ground archer bonuses get added back later, each
one can be measured against this baseline instead of being buried inside a rule
that already does five things.

### Melee

- Base 1d6. Bonus dice, one each, all stacking:
  - +1d6 if you are the **heavier** of the two (relative, not an absolute tier
    bonus — two Heavies fighting each other both get nothing here)
  - +1d6 if you are the **stronger** of the two by current Strength (also
    relative)
  - +1d6 if you are **Cavalry attacking** or **Infantry defending**
- Keep the single highest die from your pool, add your Strength → score.
- Higher score wins. **Winner/loser retreat mechanics are unchanged.**
- Damage: loser takes the **margin** (score difference). Ties therefore do
  0 damage by construction.
- **No armor stat at all.** The extra die for being heavier *is* the armor.
- Crits: every 6 rolled is +1 damage, and 6s **cancel cross-side one-for-one**.
  Both sides rolling a single 6 → neither gets a bonus. Your own two 6s do NOT
  cancel each other; only an opponent's 6 cancels yours.

### Ranged

Same shape, minus the role die.

- Archer: 1d6 base, +1d6 if stronger, +1d6 if heavier, +1d6 for a **short shot**.
- Defender: 1d6 base, +1d6 if stronger, +1d6 if heavier. No role die, no
  short-shot die (archer-only).
- Defender takes damage equal to the margin. Same cross-cancelling 6s rule.

Short/long shots already exist in the engine (`SHOT_SHORT` = range 1,
`SHOT_LONG` = range 2). Today the only difference is movement cost: a **long**
shot that connects burns the formation's remaining movement (expensive), a
short shot only costs the aim action (cheap). This rule adds an accuracy
dimension that doesn't exist today — short shots also get +1d6. So short
becomes cheap *and* more accurate; long keeps only its standoff range.

## Correction carried forward — read this before describing tie behavior

Earlier in the session I repeatedly described "ties do no damage" as the
engine's current behavior. **That was wrong.** In `_resolve_battle`
(`scripts/stratego_game.gd`, ~line 1837), the damage loop runs unconditionally
for every participant regardless of tie or decisive win:
`damage = max(0, opposing_score - effective_armor) + crit`. A tie
(`unique_winner_id == EMPTY`) only means nobody gets the winner's doubled
armor and nobody takes the contested square — **both sides still take damage
today.**

That means the new variant above is a genuine *change* to tie behavior (from
"ties hurt both sides" to "ties do nothing"), not parity with the status quo.
This was chosen deliberately as the isolating baseline. Don't re-derive it as
a bug.

## The model tool

`tools/melee_model.py` — standalone Python, no Godot. Simulates isolated 1v1
clashes many times and prints win/damage grids. Decoupled from the engine and
bot AI on purpose, so rules can be compared without positioning/initiative
confounds.

```bash
python tools/melee_model.py --rule <name> --trials 20000 --seed 1
python tools/melee_model.py --mode ranged --rule archer_v4_armordice
```

Adding a rule = one function `(attacker, defender, rng) -> ClashResult` plus a
line in the `RULES` dict. Ranged rules use `RANGED_RULES` and return
`RangedResult`.

`make_unit(role, weight, strength=None)` takes an **optional strength override**
— strength defaults to the weight tier table but should be passed explicitly
whenever testing, since coupling them confounds every result (see below).

### Rules already in the model

| name | verdict |
|---|---|
| `current` | baseline, mirrors `_resolve_battle` for the 1v1 case |
| `d6str_lossgap` | superseded — zero tie damage was a regression, not a fix |
| `d6str_rawdie` | fine, but raw-die damage doesn't match the ranged margin shape |
| `2d6role_rawdie` | good stepping stone |
| `2d6role_rawdie_chip` | adds loser's-crit chip damage; small effect |
| `marginmax` | max(margin, raw die); safe incremental pick |
| `marginfallback` | **broken** — ties can out-damage a narrow win |
| `weightscore_marginmax` | drops Strength from score; cuts against "Strength is damage" |
| `weightdice_str_marginmax` | flat per-tier dice; weight dominated Strength too hard |
| `comparative_dice_marginmax` | closest to the target variant, but uses marginmax damage + armor |
| `archer_v1` … `archer_v4_armordice` | ranged progression; v4 is the armor-dice + crit-cancel one |

**The variant specced above is not yet in the model.** `comparative_dice_marginmax`
is its nearest relative but differs in damage rule (marginmax vs pure margin)
and still subtracts armor. Worth adding as its own entry before engine work.

## Key findings from the sweeps

- **Comparative bonuses are shift-invariant.** In `comparative_dice_marginmax`,
  only the *difference* in Strength matters, not absolute level — the
  equal-Strength diagonal sits at a constant win rate whether that's 4v4 or
  12v12. Good property for a campaign where veterans push Strength up over time.
- **Crossover points (comparative dice, with armor):** LI attacking HI needs
  roughly +4 Strength to break even (weight die + defend die stack against it);
  LC attacking HI needs ~+1; LC attacking HC is near-even at parity (~39%)
  because one bonus die each cancels out. User confirmed LI-vs-HI getting
  smoked is *intended*, not a flaw.
- **Weight and Strength are currently coupled in the stat table**
  (light=6/medium=7/heavy=8), so "heavier" and "stronger" bonus dice almost
  always fire for the same side and double-count. Always decouple via the
  `strength=` override when testing, or results are meaningless.

## Suggested implementation shape

Discussed but not built. Each variant as its own file so purging a failed
experiment is a file deletion:

- `class_name MeleeRule extends RefCounted` base with
  `func resolve(attacker, defender, rng) -> Dictionary`, one subclass file per
  variant; or plain `static func` per file, called as `MeleeRuleX.resolve(...)`.
- A hand-maintained registry dict mapping variant name → class, in one small
  file. Preferred over directory-scanning: the extra one-line edit is cheap and
  an explicit list of live experiments is greppable, with a loud
  unresolved-class error if you forget to clean up.
- Note the Godot gotcha this project has hit repeatedly: a newly added
  `class_name` isn't resolvable from other scripts until a headless editor pass
  (`--editor --quit-after 400`) repopulates
  `.godot/global_script_class_cache.cfg`.

A JSON config layer (following the `CampaignScenario` / `campaign/battles/`
precedent) is only worth adding if numeric knobs start needing rapid iteration
without touching GDScript. Not needed yet.

## Also wanted, explicitly later

Cover, and a bonus for archers firing from a hill. Deferred on purpose — the
whole reason for the stripped baseline is so these can be added and measured
one at a time.

## Player-facing explanation

`campaign/design_notes_combat_rewrite.md` has a new-player write-up, but it was
written for the **`comparative_dice_marginmax` + `archer_v4_armordice`** pair
(margin-max damage, armor subtraction, armor-dice defense). It does **not**
describe the simplified no-armor / pure-margin / zero-tie-damage variant specced
above. Rewrite it when the real variant lands.

## Related engine bug fixed this session

`setup_skirmish` used `BOARD_SIZE / 2` (10) as the board centre when the true
centre of rows 0-19 is 9.5, then added `(separation + 1) / 2` on top. At odd
separations (the default is 3) this compounded into a full extra cell of depth
for Blue, strong enough to decide ~90% of bot-vs-bot games regardless of army
composition. Fixed at `scripts/stratego_game.gd:392`; all 303 tests pass. Any
skirmish A/B data generated before that fix is confounded and should be
discarded.
