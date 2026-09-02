# Handoff: combat resolution rewrite

Status as of 2026-09-02. **The variant below is implemented in the combined
`hex_combat/` project.** The sibling `new/` project remains the square-grid
control, while `combat/` and `hex/` retain the earlier isolated experiments.
The combined build uses flat-top hexes, replay version 9, universal post-clash
actions, movement-before-ranged resolution, and friendly-blocked retreat
shunts.

What landed here:

- `scripts/stratego_game.gd` resolves melee, retreat battles and ranged fire
  with comparative d6 pools. `ROLE_BONUS` and `ARMOR_BY_WEIGHT` are gone, and
  so is the `armor` field on the piece record.
- `scripts/main.gd` shows the pool, the bonus-die count, the kept die and the
  surviving 6s instead of roll/capped/role/armour/natural-10.
- `scripts/bot_policy.gd` scores fights through the rewritten heuristics and
  now prices short versus long shots differently.
- `tools/melee_model.py` gained `baseline_v1`, `archer_baseline_v1_short` and
  `archer_baseline_v1_long`, cross-checked against the engine to within Monte
  Carlo noise over 200k trials per matchup.
- 445 checks pass in `tests/test_runner.gd`.

Two readings of the spec had to be settled to build it; both are called out in
"Judgment calls" at the bottom of this document.

## Why we're doing this

Hidden Strength wasn't mattering. Under the current rules a formation's roll is
`min(1d10, current_strength) + ROLE_BONUS`, so Strength only ever bites when the
die would have exceeded it — for a Strength-6 vs Strength-8 unit, that's only
rolls of 7 or 8. The die decides the fight and Strength nudges it, which makes
"do I know this enemy's Strength" a nearly irrelevant question. Most real
decisions in the game were coming from role and objective instead.

Design constraint the user stated, and which the new rules honor:
**Strength is damage.**

## The variant, as built

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
  0 *margin* damage by construction. (Superseded in part: see "Judgment calls"
  - crits now land on losses and ties too, by the user's later call.)
- **No armor stat at all.** The extra die for being heavier *is* the armor.
- Crits: every 6 rolled is +1 damage, and 6s **cancel cross-side one-for-one**.
  Both sides rolling a single 6 → neither gets a bonus. Your own two 6s do NOT
  cancel each other; only an opponent's 6 cancels yours.

### Ranged

Same shape, minus the role die.

- Archer: 1d6 base, +1d6 if stronger, +1d6 if heavier, +1d6 for a **short shot**.
- Defender: 1d6 base, +1d6 if stronger, +1d6 if heavier. No role die, no
  short-shot die (archer-only).
- Defender takes damage equal to the margin, plus any 6s that survived
  cancelling - and those land even when the shot loses the contest.

Every eligible formation receives one post-clash action regardless of spent
main movement. Infantry may reposition into empty or friendly hexes; Cavalry
may also deliberately enter an enemy-held hex. Opposing Infantry that choose
the same empty hex still meet as attackers. An Archer chooses either the
one-hex reposition or a ranged order with a maximum range of two. Reposition
movement, battles, and retreats resolve first, followed by all surviving
Archer attacks. The final range sets accuracy: range 1 gets +1d6, while range 2
keeps only its standoff distance.

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

The specced variant is now in the model as **`baseline_v1`**, and the ranged
pair as `archer_baseline_v1_short` / `archer_baseline_v1_long`. Its nearest
older relative, `comparative_dice_marginmax`, is kept for comparison but
differs in damage rule (marginmax vs pure margin) and still subtracts armor.

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

## Suggested implementation shape — NOT taken, and why

**Deliberately skipped.** The rules are written straight into
`scripts/stratego_game.gd`, with no `MeleeRule` base class and no registry.

The registry existed to make "purge a failed experiment" a file deletion. That
job is now done a level up: `combat/` is itself a whole-project fork, sibling
to the untouched `new/` control and to `hex/`. Purging this experiment is
deleting this directory, and comparing variants is running two forks against
each other. Adding a per-variant class registry inside a per-variant fork would
be the same mechanism twice, and would have left the engine carrying an
indirection with exactly one live implementation behind it.

If several rules ever need to be live in the *same* build - a per-battle
setting, say, or an A/B inside one campaign - the original sketch below is
still the right shape. Nothing about the current code blocks it; the pool
construction is already isolated in `_combat_dice_count` and `_roll_dice_pool`.

The original sketch, kept for that case. Each variant as its own file so
purging a failed experiment is a file deletion:

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

`campaign/design_notes_combat_rewrite.md` has been rewritten for the shipped
variant: no armor, pure margin, zero tie damage, and the short shot as the
archer's extra die. It no longer describes the old
`comparative_dice_marginmax` + `archer_v4_armordice` pair. `README.md`'s
Combat section is updated to match.

## Related engine bug fixed this session

`setup_skirmish` used `BOARD_SIZE / 2` (10) as the board centre when the true
centre of rows 0-19 is 9.5, then added `(separation + 1) / 2` on top. At odd
separations (the default is 3) this compounded into a full extra cell of depth
for Blue, strong enough to decide ~90% of bot-vs-bot games regardless of army
composition. Fixed at `scripts/stratego_game.gd:392`; all 303 tests pass. Any
skirmish A/B data generated before that fix is confounded and should be
discarded.


## Judgment calls made while implementing

Two places where the spec above admitted more than one reading. Both were
settled toward the literal text; reopen either if the play testing argues for
it, but don't re-derive them as bugs.

**Crits fire on wins, losses and ties alike.** *(Settled by the user after the
first implementation shipped the opposite reading. This is the current rule;
don't revert it to the earlier one.)*

The first pass read the spec conservatively: damage is framed as something
*the loser takes*, so crits only enlarged a blow that already landed, and
"ties therefore do 0 damage by construction" was exact. The user's call is the
additive reading instead, for two stated design reasons: a weak archer should
still be able to do damage, and a losing army should be able to take one of the
enemy with it.

So damage now has two independent sources. The **margin** is still paid only by
the loser. **Surviving 6s** are paid by whoever failed to match them, whatever
the scores did. Because 6s cancel one for one, at most one side is ever owed
crit damage in a single clash, so this cannot turn into a mutual bloodbath.

A tie is therefore free of *margin* damage but not of crits. The isolating
baseline is slightly less clean than it was; that was the explicit trade.

**A ranged miss chips.** Same reversal, same reason. A shot that loses the
contest still lands whatever 6s the target failed to match, which is the
`archer_v4_armordice` behaviour restored. `hit` still means the archer won the
contest; a miss that drew blood is reported as the new `ranged_graze` result,
because logging non-zero damage beside "miss" reads as a bug.

Concretely: a Strength-3 Light Archer shooting a Strength-12 Heavy Infantry
wins the contest 0% of the time and still averages ~0.20 damage per shot.

Two smaller generalizations the spec did not cover, both documented at their
call sites:

- **Multiway comparatives.** With more than one enemy on the square, the
  heavier and stronger dice are earned against the opposing side's *best*
  claim on each dimension - you have to out-mass and out-fight every enemy
  present. Reduces exactly to the spec at 1v1. The alternative would hand a
  Heavy its weight die for out-massing one Light while a second Heavy stood
  next to it.
- **Multiway crits.** The margin still comes from the single highest-scoring
  opponent, but a 6 counts from *any* enemy on the square. The two differ on
  purpose: the margin is a won contest, a crit is a lucky blow. Taking crits
  from the top scorer only would have defeated the whole point of the rule in
  exactly the situation it exists for - being outnumbered and going down.
- **Retreat battles** keep the comparative dice but get no role die. Nobody
  in a retreat collision is charging, and nobody is braced on ground they
  meant to hold.

## Consequences worth knowing before tuning

- **Nothing healthy dies in one melee any more.** Damage is bounded by the
  margin plus a point or two of crits, roughly 5-8 against Strengths of 5-8. Every kill is now
  attrition or a finish on something already hurt. Several engine tests had to
  be rebuilt around this; it is the single biggest behavioural change, larger
  than the tie rule.
- **Strength is load-bearing twice**, as score and as a comparative die. Chip
  damage that drops a formation below its enemy costs it a die as well as a
  point, so fights tilt faster than the raw numbers suggest.
- **The bot's assumed-enemy Strength of 3 is now untuned.** Its sweep predates
  the rewrite and the assumption feeds a bonus die it never used to. Re-run it
  before trusting the number - see the caveat in `bot_policy.gd`.
- **Short shots got an accuracy dimension.** At Strength parity the short shot
  hits about 58% against a long shot's 41%, for roughly 55% more expected
  damage per shot. Long range now buys standoff and nothing else.
