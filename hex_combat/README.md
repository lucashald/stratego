# WEGO Formations: Hex + Combat

Master reference for the `hex_combat` prototype. Everything here was read out of
the code at commit `a8986c8` and checked by running the suite and the batch
runner. Where an older document in this repo disagrees with this file, this file
is right and the older one is stale.

A Godot 4 tactics game. Two or four armies write orders at the same time, then
the engine resolves everything simultaneously: movement in three impulses, then
melee, then a post-clash action phase, then archery. Combat is d6 pools where a
side keeps its single highest die.

## Contents

- [Orientation](#orientation)
- [Running it](#running-it)
- [The board](#the-board)
- [Formations](#formations)
- [Roads](#roads)
- [A round, end to end](#a-round-end-to-end)
- [Planning and orders](#planning-and-orders)
- [Movement resolution](#movement-resolution)
- [Melee](#melee)
- [Retreats](#retreats)
- [The post-clash phase](#the-post-clash-phase)
- [Ranged fire](#ranged-fire)
- [Fog and information](#fog-and-information)
- [Objectives](#objectives)
- [Scenarios](#scenarios)
- [Deployment](#deployment)
- [How a battle ends](#how-a-battle-ends)
- [Replays](#replays)
- [Campaign battles](#campaign-battles)
- [The bot](#the-bot)
- [Command bridge](#command-bridge)
- [Balance tooling](#balance-tooling)
- [Interface](#interface)
- [Code map](#code-map)
- [Current status](#current-status)

## Orientation

`C:\stratego` holds several sibling Godot projects. They share a lineage and a
lot of copied code, and they are not kept in sync.

| Folder | What it is |
| --- | --- |
| `hex_combat/` | This project. Hex board plus the side-based dice combat. The active one. |
| `new/` | Square-grid predecessor. Older combat rules. |
| `hex/` | Hex board with the older combat rules. |
| `combat/` | Untracked working copy, not part of the repo. |
| `classic/` | The original turn-based Stratego with a trained policy. Unrelated to WEGO. |

Nothing in `hex_combat` imports from the siblings. Treat it as self-contained.

## Running it

Godot 4 is required. The launchers look for
`C:\situation-room\Godot_v4.3-stable_win64.exe` first, then a portable copy
beside the launcher, then `godot.exe` or `godot4.exe` on `PATH`. `project.godot`
records `config/features="4.7"` because a newer editor last wrote it; 4.3 still
runs it.

Play the game:

```bash
"C:/situation-room/Godot_v4.3-stable_win64.exe" --path .
```

Run the rules suite:

```bash
"C:/situation-room/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://tests/test_runner.gd
```

Run a bot-vs-bot batch:

```bash
"C:/situation-room/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://scripts/batch_runner.gd -- --games 120 --scenario highfield
```

Take a screenshot of the real interface without a person watching:

```bash
"C:/situation-room/Godot_v4.3-stable_win64.exe" --path . --script res://scripts/screenshot.gd -- --out shot.png --scenario meeting --reveal 1
```

The `.bat` files (`Play Stratego.bat`, `Test Stratego.bat`,
`Train Stratego Bot.bat`, `Evaluate Stratego Bot.bat`) wrap the same commands
and pause at the end. `Test Stratego.bat` first runs the editor for two frames
so Godot builds its script-class index on a fresh checkout, which matters
because the code leans on `class_name` globals.

Launching goes straight into the bridge scenario with the player commanding
Blue. Everything else is reached from the Settings drawer.

## The board

20 by 20 flat-top hexes in odd-column offset layout, identified in the engine as
`hex_odd_q_flat`. Coordinates are `Vector2i(column, row)`. Odd-numbered columns
sit half a hex lower than even ones. `HexGrid` owns every adjacency, distance
and pixel operation; nothing else should compute them.

North and south are straight lines, which is why this orientation was chosen.
The six directions are numbered:

| Constant | Value |
| --- | --- |
| `NORTH` | 0 |
| `NORTH_EAST` | 1 |
| `SOUTH_EAST` | 2 |
| `SOUTH` | 3 |
| `SOUTH_WEST` | 4 |
| `NORTH_WEST` | 5 |

One metric covers movement, vision and range: hex distance, computed by
converting to axial coordinates. A hex has 6 neighbours, radius 2 covers 19
cells, radius 4 covers 61.

Terrain is one of four kinds. Open is the default and is stored as the empty
string.

| Terrain | Passable | Used by |
| --- | --- | --- |
| open | yes | everywhere |
| `lake` | no | the four-lake map |
| `water` | no | the bridge river |
| `bridge` | yes | the four crossing hexes |
| `road` | yes | any scenario that lays one; see [Roads](#roads) |

`is_blocked_terrain` is true for lake and water. The lake map places four 2x2
blocks at columns 7-8 and 11-12, rows 7-8 and 11-12. The bridge map floods row
9 across the whole width and then marks columns 8, 9, 10 and 11 as bridge.

## Formations

Nine fighting types, one per combination of three roles and three weights, plus
a Flag.

| | Light | Medium | Heavy |
| --- | --- | --- | --- |
| Infantry | `LI` | `MI` | `HI` |
| Archer | `LA` | `MA` | `HA` |
| Cavalry | `LC` | `MC` | `HC` |

Weight sets movement and feeds one comparative combat die. Role decides which
combat die a formation can earn. Strength is both damage capacity and a term in
the combat score.

| Weight | Movement | First impulse it moves on |
| --- | --- | --- |
| light | 3 | 1 |
| medium | 2 | 2 |
| heavy | 1 | 3 |

The first impulse is `4 - movement`, so everything finishes moving on impulse 3
regardless of speed. A road adds a step on top of this without touching the
schedule; see [Roads](#roads).

Strength is 7 for every type in `PIECE_DEFINITIONS`. That uniformity is
deliberate. Weight, Role and dice decide a fresh fight; Strength differences only
appear once someone has been hurt, or when a scenario or campaign battle sets
explicit per-formation values. `add_piece` takes a `strength_override` for that.

A Flag has no role, no weight, strength 0, and never moves. It only exists in the
two four-corner scenarios. Archers cannot target it.

## Roads

A formation that **begins its round standing on a road** gets one extra movement
point. Roads are otherwise open ground: passable to everyone, no effect on
combat, vision or retreats.

The bonus is spent as a **fourth impulse**, after the shared three. Every Weight
keeps the first impulse its Weight alone gives it, so a road buys distance rather
than an earlier start.

| | Movement | Impulses it moves on |
| --- | --- | --- |
| Light | 3, or 4 from a road | 1, 2, 3, and 4 from a road |
| Medium | 2, or 3 from a road | 2, 3, and 4 from a road |
| Heavy | 1, or 2 from a road | 3, and 4 from a road |

Two things follow from that, both deliberate.

A road formation **arrives last and is therefore braced against nobody**. It
spent the round marching rather than forming up, and anything that reached the
contested hex on impulses 1 to 3 is braced against it. Reaching a fight by road
is a real trade, not free tempo.

The bonus could not have been folded into the existing schedule instead. The
first impulse is `4 - movement`; feed a boosted total into that and a road Heavy
starts on impulse 2, which is a different feature entirely, changing who is
braced against whom across the whole board. For a Light it does not even work:
`4 - 4` is impulse 0, one before the loop begins, so the fourth step the order
validator had already accepted would silently never be taken.

**"Begins its round" is a snapshot, not a live reading.** `road_bonus` is stored
on the formation and recomputed only where a formation can come to rest on new
ground: after setup, after a deployment change, at the start of resolution, and
at the end of a round. Reading the terrain under the formation as it moved would
withdraw the bonus the moment it stepped off the road, partway through a path
accepted at the longer length, and the last step would vanish with no event to
explain it. So a formation that starts on a road and immediately leaves keeps the
step, and one that ends its round arriving on a road is paid from the next round.

Roads are laid with `apply_road_terrain(cells)`, which takes **open ground only**.
Water and lake are refused for the obvious reason. A bridge is refused too, and
that one matters more: a bridge is passable, so nothing about movement would have
stopped it, but writing a road there would replace the terrain rather than
decorate it, and the hex would stop answering to `is_bridge` while still being,
to look at and to cross, a bridge.

No shipped scenario lays a road. The feature reaches the game through campaign
battles, which take a `terrain.road` list; see [Campaign battles](#campaign-battles).

On the board a road is dun ground carrying a rut drawn from the hex's middle out
to each neighbouring road hex, so a line of them joins into one track without any
hex needing to know the road's shape. An isolated road hex gets a patch instead,
because a spur to nowhere reads as a rendering fault. The inspector names the
road on any formation currently drawing the bonus, and credits the extra step to
the road rather than to the formation's Weight.

## A round, end to end

1. **Planning.** Every player writes orders for every formation at once. A path
   may be up to the formation's movement allowance.
2. **Main movement**, three impulses, plus a fourth only a road formation
   reaches. Light moves on 1, 2 and 3; Medium on 2 and 3; Heavy only on 3.
   Contact with an enemy opens a fight but rolls nothing: the formations
   involved stop moving and the fight is held open.
3. **Melee.** Once all three impulses are done, every fight opened during them is
   rolled in one pass, then all retreats from that pass resolve together.
4. **Post-clash planning.** The engine pauses. Every surviving formation that did
   not lose, did not bounce off an opposing tie, and has not already fought twice
   gets one action.
5. **Reposition.** Post-clash movement resolves as a single wave, with its
   battles and retreats.
6. **Archery.** Every surviving declared shot fires simultaneously.
7. **End of round.** Victory is checked, then the round number advances.

Holding fights until all three impulses have moved is the load-bearing detail. A
Light that made contact on impulse 1 and the Heavy that reached the same hex on
impulse 3 fight one battle together, which is impossible if contact resolves
where it happens.

Phases are `deployment`, `planning`, `leftover_planning`, `resolving` and
`game_over`. The engine calls the post-clash phase "leftover" throughout;
the interface calls it "reposition".

## Planning and orders

An order is a path of adjacent passable hexes, no longer than the formation's
movement allowance. Orders are stored per player, per piece, and each carries a
`sequence` number recording when the player issued it. That sequence is the
final tiebreak for who takes contested ground.

A player's own orders are validated against each other before being accepted.
The engine refuses a set of orders where two of your own formations would:

- occupy the same hex on the same impulse, when that hex is empty or holds an
  ally
- swap through each other
- end the round on the same hex

Two of your own formations *may* be sent at the same enemy-held hex, at any mix
of speeds. Committing a second wave against a defender the first attack might
not beat is a real decision. Because melee now waits for every impulse, both
attackers end up in the same fight whatever their speeds.

Walking into your own line is refused by default, because it is usually a
misclick. **Support** is the way to ask for it deliberately, and it is a real
order: `support` is stored on the order, not consumed by the validation that
lets it through, so the board and the resolver can both tell it from a march.

Two routes to it. A direction arrow pointing at a hex the selection could
reinforce is drawn as a gold shield rather than a chevron, and pressing it
issues the reinforcement. Right-clicking that hex opens the context menu, which
offers **Support** alongside Inspect and Cancel Order. A plain left-click still
refuses the step.

A standing reinforcement is drawn as a gold dashed ring on the ally's hex with a
bracket and shield running back to the relief. Deliberately unlike the march
ghost, which is a dashed blue run with an arrowhead and a numbered impulse
circle: the impulse number would be a lie here, because a relief that arrives
before the enemy bounces and retries rather than landing on the impulse shown.

Resolution is unchanged by the naming. If a fight is open on that hex when the
relief arrives it joins, and if the hex is quiet it bounces off its own line
without penalty and keeps its retry, so it is still trying on later impulses. A
relief ordered up before the attack lands therefore joins the fight anyway, at
the cost of a movement point per bounce.

What support actually buys the defending side, in dice:

- **one more die**, because a side rolls one per formation it brought
- **the comparative Weight or Strength die**, if the relief is heavier or
  stronger than anything the enemy has present and the holder was not
- **a charge die** if the relief is Cavalry, since it counts as unbraced

It does not buy a second braced-Infantry die. A relief can never be braced,
because its arrival is the impulse it actually lands on and it only lands once an
enemy is contesting the hex, so an enemy always arrived no later than it did.

Support is a commitment rather than a free die. Damage is paid per side, so a
relief that joins a fight its side then loses pays the same margin as the
formation it came to help, and can die for it.

`strict_friendly` is a parameter on the order calls. The bot passes strict so
that a rejection prunes its own colliding candidates. Permissive callers accept
that a projected collision may never happen, because the occupant can move, win
its fight and advance, or be killed.

## Movement resolution

Every proposed step costs one movement point whether or not it lands. A bounce
is charged. A Light gets three attempts in total, however it spends them.

Within one batch, proposals are classified in this order:

1. **Joining an open fight.** If the destination is a hex with a pending battle
   on it, the formation joins that battle, whichever side is standing there and
   whether or not anyone still is. Settled first, so a contested hex is never
   mistaken for open ground.
2. **Swaps.** Two formations trading hexes. Enemies fight a crossing battle;
   allies collide.
3. **Destination groups.** Everyone else, grouped by target hex. An occupant that
   is not leaving joins as a defender with arrival 0. More than one team present
   means a battle; one team means an allied collision.

A lone mover takes an empty hex and bounces off an occupied one
(`occupied_after_resolution`).

Allied collisions carry no round-status penalty. A stationary formation keeps its
own path. A mover may retry on a later impulse only when it queued behind that
stationary formation; converging movers stop this path so they do not repeat the
same collision every impulse.

Two cases make an allied collision into something else, decided after the
ordinary moves have been placed, because only then is it known whether the hex's
holder actually got away:

- The holder was expected to leave, and did, leaving the hex empty. The first
  claimant by placement order takes the ground rather than everyone bouncing off
  an attack that was merely dodged. The rest bounce.
- The holder was expected to leave and failed, so an enemy is still standing
  there. The formations booked as congestion are attacking it after all, and a
  battle opens.

## Melee

A fight is scored by **side**, not by formation. Each side rolls one pool and
keeps its single highest die.

### Pool size

A side's pool is one die per formation it brought, plus:

- **+1 if its Strength is the highest**, comparing the strongest single formation
  on each side. Comparative, so equals give each other nothing.
- **+1 if its Weight is the highest**, comparing the heaviest formation on each
  side. A Heavy earns nothing against another Heavy however many Mediums stand
  behind either of them.
- **+1 per formation** that is Cavalry and not braced, or Infantry and braced.

Numbers pay out in dice here and nowhere else. That is the whole reason Strength
scores off the leading formation alone: stacking both would let a gang open a
margin wide enough to delete a healthy formation on contact.

### Braced

A formation is braced when no enemy reached the contested hex before it or
alongside it. Arrival 0 is the stationary occupant, so it is braced against
everyone. An early arrival is braced against whatever follows it in. Two enemies
landing on the same impulse are both unbraced. Allies arriving together are all
braced: the die is earned by beating the enemy there, not each other.

Braced is not the same as `is_attacker`, which only records whether a formation
moved into the fight. `is_attacker` still decides where a loser falls back to,
and a formation can have moved and still be braced.

### Score and outcome

Score is the kept die plus the side's highest current Strength. There is no
Armor stat, and no cap on the roll beyond the die itself: the most any pool ever
scores off the dice is 6, so extra dice buy reliability rather than a bigger
ceiling.

The unique highest-scoring side wins. A tie across opposing sides is a bounce:
nobody took the hex, every survivor returns to where it came from and is done for
the round.

Two experimental toggles, both off by default, break that tie instead. Both
require exactly one of the tied sides to be braced.

| Flag | Behaviour |
| --- | --- |
| `defender_wins_ties` | The braced side wins any tie. |
| `defender_resists_charge_ties` | The braced side wins only when everything that came at it was Cavalry, the matchup where both role dice cancel. |

The batch runner exposes them as `--defenderties 1` and `--chargeties 1`.

### Damage

Two independent sources, and every formation on a side takes the same amount.

- **The margin**, paid only by the losing side. A tie costs nobody a margin.
- **Surviving 6s.** Every 6 rolled is one extra damage, but 6s cancel across the
  two sides one for one. A 6 each is worth nothing to either; your own two 6s do
  not cancel each other. These land whatever the scores did, so a side being
  overrun can still put one through the winner on its way down, and a level fight
  can still draw blood. Because they cancel, at most one side is ever owed crit
  damage in a single clash.

Strength at or below zero destroys the formation.

### Taking the ground

The winning side claims the hex in **placement order**:

1. A formation already standing there beats everything. Its own reinforcements
   cannot shove it off.
2. Then current Strength, so among formations that moved in, the strongest takes
   the ground. Arrival is Weight rather than intent, so ordering by arrival left
   a won hex garrisoned by the formation least able to hold it.
3. Then arrival.
4. Then the order the player issued, by `sequence`.

Each winner in turn tries to reach its own intended destination. In an ordinary
fight everyone wanted the same hex, so one claim lands and the rest come home. In
a crossing fight the destinations differ and an advancing line keeps its shape.

A winner that cannot take its destination returns to where it came from. If that
hex was filled in the meantime, normally by the ally that advanced into the gap
behind it, it falls back to a free adjacent hex chosen by how directly it leads
away from the contested ground, and is only destroyed if nothing at all is free.
A formation that did not lose its fight should not die of traffic.

The losing side retreats. Winning ends a formation's main path but not its
post-clash action. Losing, or bouncing off an opposing tie, ends its round.

## Retreats

A loser's direct retreat hex is:

- the hex it came from, if it was an attacker in a non-crossing fight
- otherwise the neighbour most directly away from the strongest surviving
  opposing formation, with the earlier arrival breaking a tie. Formations
  destroyed in the same clash are only considered if nothing on that side is
  left standing.

If that hex is off the board, blocked terrain, or enemy-held, the loser is
destroyed. No shunt is allowed past an enemy.

If it holds a friendly formation, the loser shunts. Treating directly away as 6
o'clock, it tries in order: left (7 o'clock), right (5 o'clock), wide left, wide
right, and backward. If none of the five is free, it dies of friendly congestion.

Retreats from one batch resolve together, so two of them can want the same hex:

- **Two or more allies** into one hex: one takes it and the rest look again. The
  claim goes to whoever's straight line of retreat it was, then to the stronger,
  then to the order the player issued. Everyone displaced re-runs the same
  widening search from its own anchor, and only a formation with nowhere left at
  all is lost.

  This used to destroy every formation in the pile, which made an ally standing
  in your retreat hex *safer* than an ally arriving at it: a formation already
  there is a blocker you shunt around, while one landing at the same moment
  killed you both. Reinforcing a defender could therefore get the pair of them
  killed, because the relief vacated the very hex both were about to be pushed
  into. The widening search above exists because of the standing-blocker version
  of that complaint; the simultaneous-arrival version was simply never covered.
- **Two enemies** into one hex fights a retreat battle. This is still scored
  per formation rather than per side, with the comparative Weight and Strength
  dice but no role die, because nobody there is charging and nobody is braced on
  ground they meant to hold. The loser is destroyed, a tie destroys both, and
  there is no further retreat.

## The post-clash phase

Every surviving formation gets one action, so long as it is movable, its round
status is `ready` or `won`, and it has fought fewer than two melees this round.

The action is one of:

- hold
- move one adjacent hex
- for an Archer, declare a shot instead of moving

Cavalry may deliberately reposition into an enemy-held hex. Infantry and Archers
may enter only empty or friendly hexes.

The same friendly-collision rules apply, with two exceptions. Any number of
friendly follow-ups may enter a hex their own stationary formation currently
holds. And two of your own may be sent at one enemy-held hex, exactly as the main
phase allows: reposition is a single wave, so they arrive together, neither is
braced, and they fight as one side. Two of your own swapping is still refused.

Reposition movement resolves as an ordinary movement batch, so its battles roll
where they happen rather than being held open. Its retreats follow. Then archery.

An Archer that chose to shoot loses the shot if it is defeated or tied in a
reposition battle before ranged fire resolves.

## Ranged fire

Only Archers, only at range 1 or 2, and only at something the player can see.
There is no blind fire into fog. An Archer cannot target its own hex, an ally, or
a Flag.

Three orders, all declared during the post-clash phase:

| Order | Targets | Notes |
| --- | --- | --- |
| Attack | a formation, by id | Follows it through reposition. Never pools. |
| Volley | a fixed hex | Hits whoever holds it after reposition resolves. |
| Join Volley | a hex an ally is already volleying | Pools into one contest. |

Range is judged when the arrow is loosed, not when the order is written. A
tracked target that closes to range 1 grants the same accuracy die as any other
adjacent target. A declared shot whose target is gone or out of range at fire time
is reported as a fizzle rather than silently dropped.

### A single shot

A shot is a contest, not a threshold. Both sides roll.

- **Archer**: one base die, plus heavier, plus stronger, plus one for a short
  (range 1) shot. Range 2 gets no accuracy die.
- **Target**: one base die, plus heavier, plus stronger. Never a role die and
  never a range die, because it is being shot at rather than shooting back.

Score is the kept die plus that formation's Strength. The Archer hits only if its
score is strictly higher, which is worth the margin. Surviving 6s are added on
top and land either way, so an Archer that loses the contest outright still chips
for any 6 the target failed to match. The target's own 6s are its only answer.
The Archer never takes damage back.

A miss that still drew blood is reported as a **graze**, not a miss.

### A massed volley

Allies who joined a Volley loose as one contest, scored the way a side is scored
in melee. Pool is one die per Archer, plus one more per Archer already at range 1,
plus the heavier and stronger dice earned by the best of them. Score is the kept
die plus the strongest Archer's Strength.

The trade runs both ways. Massing turns several weak contests into one strong
one, but it is a single contest paying a single margin, while firing separately
gives independent chances that can each draw blood and each graze on a surviving
6 even when they lose.

The lowest-numbered ally volleying on its own account leads a pool. Aimed shots
never join one: a pool of Archers tracking one moving target has no clean answer
when it moves out from under some of them but not others.

Focus fire is simultaneous. Every valid shot resolves against the target's
pre-fire state, damage is summed, and excess is lost.

## Fog and information

Vision is a radius of 4 hexes around every one of a player's own formations.
Sightings are recorded at setup, after every impulse, and after every phase, so
seeing an enemy at any point in a round records that it was seen even if it slips
out of sight before the round ends.

Two levels of knowledge are tracked per piece. `seen_by` is having observed the
hex it stood on. `revealed_to` is knowing what it actually is.

Meeting in melee reveals role, Weight and current Strength to everyone who could
see the fight. Trading fire does the same to both the shooter and its target: an
Archer that looses a shot has given itself away, and whoever it hit has been seen
closely enough to be named. Without that, a ranged duel could run all match with
neither side learning what it was shooting at, which melee never allows.

Observed speed reveals Weight on its own, and that is intended.

During the deployment phase a player sees exactly their own deployment zone and
nothing else. Ordinary piece-radius vision would leak a glimpse of a neighbouring
corner, because every army already exists on the board by then.

`private_battle_results` sends detailed combat results only to participating
players. Spectator view is omniscient.

## Objectives

Victory conditions are typed data, not per-scenario branches. A scenario lays its
terrain and declares one or more objectives.

| Type | Won by |
| --- | --- |
| `hold_square` | Holding one hex, alone, at the end of each of N consecutive rounds. Any round the holder is absent or an enemy is present resets that player's streak. Draw if nobody has by the turn limit. |
| `reach_area` | Having a given total Strength inside a rectangle at the end of a round. |
| `eliminate` | Destroying the other army. Draw if both survive to the turn limit. |
| `survive` | Still being in the game at a given round. |

Objectives resolve in declaration order, so a scenario sets its own precedence.
The bridge attacker breaking through on the final round beats the defender's
turn-limit win because it is declared first.

Losing an entire army loses the game regardless of the objective, in any
two-player objective scenario.

Every objective reports a one-line summary of its win condition alongside its
current progress through `describe_objectives`, so a bot or an external
controller can play a new scenario without special-casing it.

## Scenarios

Every army below starts at Strength 7 per formation, so totals are just seven
times the formation count.

### Bridge (the default)

Blue attacks, Red defends. Twelve formations each, 84 Strength each. There is no
deployment phase: Blue is scattered at random along its own board edge (row 19)
and Red at random anywhere north of the river (rows 0 to 8), seeded from the
setup seed. The four bridge hexes are passable and the rest of row 9 is not.

Blue wins by ending a round with at least 20 current Strength north of the river.
Red wins if Blue has not managed it by the end of round 20. The turn limit is
explicitly a testing value.

### Meeting

Both armies field the identical twelve-formation roster, 84 Strength each, so a
result reflects play and unit design rather than an army list. Hold the centre
hex alone at the end of three consecutive rounds to win. Losing it for a single
round resets the count. Draw at round 20.

Deployment rows are placed symmetrically about the objective rather than on rows
0 and 19. On an even board the centre is not equidistant from the two back ranks,
and that one row of advantage was worth roughly 65/35.

The battle line is shaped rather than shuffled: heavy foot holds the centre with
an archer shooting over it, mediums form the second line, light troops screen the
wings. That also fixes arrival timing, since slow formations take the short
central path while fast ones travel the long way round the flanks.

### Highfield

Two asymmetric armies fight for one central hill at (10, 10), using the same
hold-the-hex objective, on deliberately bare ground.

- **Red, the Wardens.** Seven formations, 49 Strength. Heavy foot and two Heavy
  Archers around a Heavy Cavalry, with a medium pair. Wins by attrition and by
  holding the hill as an intact wall. Slow and few, and beaten if it advances
  piecemeal into numbers.
- **Blue, the Outriders.** Nine formations, 63 Strength. A medium core with light
  horse on the wings and two bows behind. Wins by reaching the hill first,
  flanking and massing. Loses a straight slug.

Both sides start at the same per-formation Strength, so the difference is Weight,
Role and numbers. Blue is two bodies up, and faster, which is the edge. See
[Current status](#current-status) for what this actually measures now.

### Crossroads

A 2v2 team battle on the four-lake map. Red and Green are allied, Blue and Yellow
are allied, on adjacent corners. That pairing is point-symmetric: rotate the board
180 degrees and Team Red becomes Team Blue exactly.

The win condition is the same `hold_square` primitive, and nothing about it is
two-player specific, because the objective check loops every active player and
scores by alliance. Either teammate holding the centre builds the team's streak.

This is the only scenario that opens in the deployment phase.

### Four-player

Four independent armies, one per corner, 13 pieces each (12 fighting formations
at 84 Strength, plus a Flag). Capturing a Flag eliminates that army. The last
army or team standing wins. The engine supports assigning several colours to one
team here as well.

### Skirmish

A deliberately dull control scenario for measurement. Bare board, no terrain, no
positional objective, two facing lines `separation` rows apart, win by destroying
the other army.

Separation is the important dial. At 2 or 3 every formation is in contact
immediately regardless of Weight, so the result reflects combat maths alone.
Widen it and travel time re-enters. Rosters are parameters, so one matchup can be
isolated at a time.

The split is computed around the board's true centre. Truncating to
`BOARD_SIZE / 2` compounded into a full extra cell favouring Blue at every odd
separation, which was strong enough on its own to decide about 90% of games.

### Campaign

Loaded from JSON. See [Campaign battles](#campaign-battles).

## Deployment

Only Crossroads uses the deployment phase. The others place their armies during
setup and start in planning.

A deployment zone is that player's own corner: 4 hexes deep from their board edge
and 11 wide from the edge's centreline, 44 cells in all. The four zones do not
touch at that depth.

Every army starts already placed at a recommended formation, which is a hand-tuned
shape for a 4-deep corner: heavy line innermost so the slowest formations travel
least, mediums behind, lights on the flanks at the shallowest rank, Flag at the
literal edge. A player who deploys nothing gets exactly that.

`redeploy_piece` moves one formation to another empty cell inside the zone, and is
refused once the player has marked ready. `reset_deployment` restores the whole
recommended layout, which is what auto-deploy does before locking in. Once every
active player is ready, `resolve_deployment` records where everything actually
ended up, records first sightings from those positions, and hands off to planning.

Deployment placements are stored separately in the replay, because the seed alone
reproduces the recommended formation rather than whatever a player dragged it to.

## How a battle ends

At the end of each round, in order:

1. Flag captures eliminate that army (four-corner scenarios only).
2. In a two-player objective scenario, an army with zero Strength loses.
3. Objectives are checked in declaration order.
4. In a four-corner scenario, one surviving team wins.

`withdraw_player` is available during planning. It concedes immediately while
preserving every surviving formation at its current Strength, which is what makes
it usable as a campaign action. It does not revive destroyed formations. There is
no automatic material-collapse rule.

End reasons that can appear: `bridge_breakthrough`, `turn_limit`,
`held_objective`, `objective_contested`, `escaped`, `held_out`, `stalemate`,
`army_destroyed`, `flag_captured`, `last_team_standing`, `mutual_destruction`,
`withdrawal`.

## Replays

Format `wego-formations-replay`, version 9. `build_replay_document` can be called
during planning, during the post-clash phase, or after the game.

A document records:

- **setup**: scenario, seed, player count, grid, board size, privacy, vision
  range, every scenario parameter, teams, actual deployment placements, and the
  verbatim campaign battle data if there was one
- **rounds**: per round, the encoded main orders, the exact dice stream, an event
  digest and a state digest, then the same for the post-clash phase
- **partial_round**: the current round through the resolved main clash, so an odd
  result can be saved mid-review
- **battle_history**: every combat inline, so reading what happened does not
  require a second engine to recompute it
- **terminal** and **final_state_digest**

Replaying rebuilds the state through the authoritative engine and rejects any
divergence from the recorded digests. Exports land in `replays/` with a timestamp
and also update `replays/last_replay.json` for the Replay Last slot. `replays/`
is gitignored apart from a `.gitkeep`.

Because verification depends on the exact dice stream, the dice for a round are
decided when the round resolves, well before any of it is drawn. The presentation
reads the result out; it does not produce it.

## Campaign battles

`CampaignScenario` builds a battle from a JSON description instead of a hardcoded
setup, which is what lets an army carry its dead and its damage between battles.
Everything goes through the ordinary engine calls, so a loaded battle is not a
special case once it starts.

The interface loads `campaign/current_battle.json` from the Settings drawer, and
writes `campaign/last_battle_report.json` and `campaign/last_battle_replay.json`
when the battle ends. It reads the file fresh every time, so the next battle
appears simply by the campaign writing it.

A battle file looks like this:

```json
{
  "name": "Battle 1 — The Toll Road",
  "grid": "hex_odd_q_flat",
  "briefing": ["..."],
  "turn_limit": 22,
  "private_battle_results": true,
  "terrain": { "lakes": true, "open": [[10, 10]], "road": [[10, 11], [10, 12]] },
  "objective": { "kind": "hold", "square": [10, 10], "rounds": 3 },
  "armies": {
    "blue": [{ "name": "Oakhand", "type": "HI", "at": [9, 17], "strength": 8 }],
    "red":  [{ "name": "Vare First", "type": "HI", "at": [9, 3], "strength": 8 }]
  }
}
```

The `grid` field must equal `hex_odd_q_flat` or the load is refused. Objective
kinds are `eliminate`, `hold`, `reach` and `survive`, and an `also` key layers a
second objective, which is how one side racing for an edge and the other trying
to stop them becomes a single battle.

`terrain` takes `lakes` (a boolean for the four-pond map) and lists of cells
under `open`, `water`, `bridge` and `road`. They are applied in that order, so a
`road` written across water, a lake or a bridge is refused rather than paving
over it. This is currently the only route roads have into a playable battle.

`apply` returns a map from the scenario's own formation names to engine piece ids,
which is what lets a campaign follow one formation across several battles.
`build_battle_report` turns the finished `battle_history` into a named debrief.

`campaign/` holds the written battles, their replays, a roster, a chronicle and
design notes. Those markdown files are campaign fiction and working notes, not
rules documentation.

## The bot

`StrategoBotPolicy` writes complete simultaneous orders and goes through the real
collision validator rather than taking privileged sequential actions.

Orders are chosen per formation rather than per army, because the joint action
space of twelve formations each with a multi-step path is far too large to
enumerate. Each formation picks its own best order in turn and the validator
prunes anything that collides with an earlier choice. Candidates are scored
before being submitted, because validation is the expensive part.

Scoring is a weighted sum. Current weights, several of which were set by sweeps
recorded in the source comments:

| Weight | Value | What it scores |
| --- | --- | --- |
| `objective_progress` | 5.0 | closing on the scenario's aim point |
| `objective_occupy` | 20.0 | standing on the hex a scenario is won by |
| `fight_advantage` | 2.2 | expected melee edge when entering an enemy |
| `losing_fight` | 0.0 | scaled penalty for attacking at a disadvantage |
| `defend_in_place` | 1.2 | standing firm once contact is made |
| `infantry_receives` | 0.0 | extra for Infantry |
| `cavalry_charges` | 3.0 | extra for Cavalry |
| `support` | 0.5 | ending next to a friendly formation |
| `archer_exposure` | -0.8 | ending within shot of an enemy Archer |
| `ranged_damage` | 1.6 | expected damage from a declared shot |
| `finish_target` | 2.0 | preferring targets a shot can kill |
| `idle` | -1.2 | holding for no reason |
| `unknown_risk` | -1.5 | flat caution about fighting the unidentified |

Against an unidentified enemy the bot substitutes an assumed profile: Medium
Infantry at Strength 3. That 3 was measured under the older rules and is an
untested carry-over. The dice-pool rewrite changed what an assumed Strength is
worth twice over, since it now feeds a comparative bonus die as well as the
score.

`omniscient` makes the bot read true stats instead of guessing. It changes the
bot, not the fog state, which is what makes cheater-vs-honest comparisons
meaningful.

`training/self_play.gd` and `training/evaluate_models.gd` run heuristic self-play
diagnostics. No champion model is persisted; the simultaneous-order action space
is still moving.

## Command bridge

`StrategoMCPBridge` is a newline-delimited JSON server on 127.0.0.1, default port
8791. One JSON object per line in, one per line out, paired by `id`. It owns no
rules: every command forwards to `StrategoGame` and hits exactly the validation
the interface does.

Commands: `ping`, `get_state`, `legal_steps`, `new_game`, `set_order`,
`clear_orders`, `set_player`, `commit`, `end_planning`, `auto_deploy`,
`get_events`, `get_history`, `save_replay`.

Two ways to run it:

- Headless, via `scripts/mcp_host.gd`, which serves a bridge-scenario game with
  the bot defending.

  ```bash
  "C:/situation-room/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://scripts/mcp_host.gd -- --port 8791 --seed 7
  ```

- Attached to the real app, by launching with `--remote`. A second commander
  connects and plays Red while the window plays Blue.

`observed_state` is currently full-truth and omniscient. The `player` argument is
the viewer and is unused, kept so the signature survives a later fog-limited
variant.

## Balance tooling

`scripts/batch_runner.gd` plays bot against bot so results reflect unit design and
scenario shape rather than one player's mistakes. It tracks more than damage,
because damage alone cannot detect a formation whose job is to stand on an
objective and still be there at the end: it also reports objective occupancy, how
quickly each Weight reaches the contested ground, and melees won while braced.

Useful arguments:

| Argument | Effect |
| --- | --- |
| `--games N`, `--seed N` | how many games, from which seed |
| `--scenario` | `meeting`, `highfield`, `skirmish`, `crossroads`, `meeting_inverted`, `meeting_heavycav` |
| `--sep N` | skirmish line separation |
| `--blue`, `--red` | rosters like `LC:4,LA:4` |
| `--formation-strength N` | normalize every formation's Strength, diagnostic only |
| `--defenderties 1`, `--chargeties 1` | the two tie-breaking toggles |
| `--w key=value,...` | override bot scoring weights |
| `--assume`, `--assumeblue`, `--assumered` | what a bot pretends an unknown enemy is |
| `--cheater blue\|red` | that side reads true stats |
| `--sweep field=v1,v2,...` | with `--cheater`, find the assumption that costs the honest bot least |
| `--sweepweight field=v1,...` | direct head-to-head over one scoring weight |
| `--result-file` | machine-readable output, so batches can run concurrently |

`tools/melee_model.py` is a standalone Python simulator for comparing resolution
rules in a vacuum, without the positioning and initiative confounds a real game
carries. It is decoupled from the engine on purpose, and its unit stats mirror an
older version of the rules.

## Interface

Blue is the human player in every scenario. Settings offers New Bridge, New
Meeting, New Highfield, New 4-Player, New Crossroads, Watch 4 Bots, and Campaign
Battle, plus clear orders, withdraw, replay export and import, and toggles for
Archer target mode, private battle details and field reports.

### Planning

Select a formation, shift-click to add, or drag a selection rectangle. Select All
and `Ctrl+A` take every movable formation. Alt-click selects a formation instead
of stepping into its hex.

Six on-map direction arrows are real controls in their own right, sitting on the
boundary between hexes so banners stay readable. A click on one belongs to the
arrow rather than to whichever hex the pixel falls in; right-clicking one still
reaches the board underneath. The inspector has a six-direction Move Selection
pad that does the same thing.

An arrow pointing at a hex the selection could reinforce inverts: a filled gold
disc carrying a dark shield, rather than a dark disc carrying a pale chevron.
Inverted rather than merely reshaped, because at the size these sit on the board
a shield outline and a chevron are the same smudge, and what has to read at a
glance is that this one does something else.

Keyboard directions:

| Key | Direction |
| --- | --- |
| `W`, `Up` | north |
| `E` | north-east |
| `D`, `Right` | south-east |
| `X`, `S`, `Down` | south |
| `Z` | south-west |
| `Q`, `A`, `Left` | north-west |

With several formations selected, a direction applies to every member that still
has unused movement. Ghosts numbered 1 to 3 show the hex each formation intends
to occupy on each impulse.

Cancel All Orders removes every order this phase. Undo, or `Ctrl+Z`, restores the
previous complete order state, including group and cancel-all changes.

Right-click a hex for the context menu: Inspect, Cancel Order, Support, and for a
selected Archer during the post-clash phase, Attack, Volley and Join Volley. Join
Volley appears only once an ally has actually declared a Volley on that hex.

### Resolution

Presented event by event on the board. In a human game every combat, consequential
retreat and opposing-side tie waits for Next; harmless friendly congestion is
applied without a click-through card. A fight shows itself as it arrives: each
side's dice land on the contested hex, damage follows, and anything the fight
killed is drawn where it fell rather than having already vanished.

The battle card is built around sides, because a side rolls once. Banners are
grouped with the blades between the sides rather than between every pair, and the
pool, kept die, Strength, score, surviving 6s and damage appear once per side.
Strength still standing is listed per formation, and only for a side holding more
than one.

Order Reposition on the final main event opens the post-clash phase; End
Reposition reveals every choice at once. The whole reposition is a single card
listing who went where, with its battles and retreats getting their own. Next
Round starts the next round. First, Previous and Last allow review without
dismissing the sequence. Four-bot spectator battles advance automatically.

The phase banner shows the current event number, and the bottom timeline tracks
impulses, battles, retreats, reposition and ranged attacks.

Mouse wheel or the `+` and `-` controls zoom; middle-drag pans; clicking or
dragging the minimap centres the main view; Fit restores the default. Zoom and pan
stay available during resolution. The contextual help panel can be dismissed with
its X, which also hides the inspector and Move Selection pad, and Help restores
them together.

### Field reports

An optional prose after-action report, written by a model from the round's
visible log. It reads the log and writes to the log, touches no game state, and
needs a local bridge on port 8787. Flavour only. A model that is slow, unreachable
or absent costs nothing but the report.

### Banners

Every faction has a complete banner set, including Flags and an
information-safe unknown banner. The cloth identifies the faction, the border and
equipment art communicate Weight and Role, and a large live numeral shows current
Strength. A visible but unidentified enemy uses its faction's unknown banner
without leaking Role or Strength. `UnitIconCatalog` is the single place a
(player, type) pair becomes a texture.

## Code map

| Path | Role |
| --- | --- |
| `scripts/stratego_game.gd` | The engine. All rules, state, objectives, replays. ~3760 lines and authoritative. |
| `scripts/hex_grid.gd` | Hex topology: neighbours, distance, ranges, pixel conversion. |
| `scripts/board_view.gd` | Board rendering, selection, direction arrows, context menu, undo. |
| `scripts/main.gd` | Interface, scenario launching, resolution playback, campaign hooks. |
| `scripts/campaign_scenario.gd` | JSON battle loading and battle reports. |
| `scripts/bot_policy.gd` | Heuristic WEGO bot. |
| `scripts/batch_runner.gd` | Bot-vs-bot measurement harness. |
| `scripts/mcp_bridge.gd`, `scripts/mcp_host.gd` | JSON command server, and its headless host. |
| `scripts/llm_client.gd` | Field-report client. |
| `scripts/unit_icon_catalog.gd` | Texture lookup. |
| `scripts/screenshot.gd` | Headless interface capture. |
| `scripts/self_play_trainer.gd`, `training/` | Self-play diagnostics. |
| `tests/test_runner.gd` | The rules suite. |
| `tools/*.py` | Asset preparation, and the standalone melee model. |
| `docs/*.md` | Older plan documents. Historical. |
| `campaign/` | Campaign battles, replays, chronicle, notes. |

## Current status

Everything below was measured at commit `a8986c8`.

**The suite passes.** 664 checks, 0 failures. Two assertions in it used to depend
on open dice and failed roughly one run in a hundred each; both are now pinned
with forced rolls, and the suite was run twelve consecutive times to confirm it.

**Replays recorded before the retreat change will not verify.** Converging allies
now make room for each other instead of being destroyed, so any saved replay
whose rounds contain one of those pile-ups replays to a different state than the
digest it was written with. That is the rules change showing up, not corruption. Coverage includes hex topology,
fog, impulse timing, movement and collisions, the side-based pool, bracing,
placement order, crit cancelling, retreat widening, support, massed volleys,
reposition, objectives, deployment, replay round trips and tamper rejection,
four-bot rounds, and the LLM client's parsing.

**Support was verified end to end** and works on every path: ordered before the
attack arrives, arriving on the same impulse as it, arriving after it, from a
Heavy with a single movement point, from two reliefs at once, and during
reposition. Measured effect on a Medium Infantry holding against a Medium Cavalry
charge, 400 seeded trials each way: the hex was held 240 times unsupported and
273 times supported. The holder survived all 400 either way, because one melee
cannot destroy a healthy formation, so what support buys is winning the ground
rather than surviving the fight.

**Roads are inert on a map without them.** Highfield over the same 120 games from
seed 1 returns exactly what it did before roads existed, down to the outcome
split: Blue 86, Red 34, 5.5 rounds, 103 held-objective and 17 army-destroyed. The
fourth impulse is reachable only by a formation a road paid for, so on a roadless
map every formation has spent its allowance by the third and proposes nothing.

**Bot-vs-bot balance, 120 games per scenario from seed 1.** Note these are the
bot's results, and the bot underplays fast flanking armies.

| Scenario | Result | Mean length | Before the retreat change |
| --- | --- | --- | --- |
| Highfield | Blue 81, Red 39 | 5.7 rounds | Blue 86, Red 34, 5.5 rounds |
| Meeting | Blue 47, Red 73 | 7.9 rounds | Blue 49, Red 71, 8.2 rounds |
| Skirmish | Blue 50, Red 69, 1 draw | 10.9 rounds | Blue 56, Red 62, 2 draws, 11.1 rounds |

Letting converging allies live moved Highfield about four points back toward even
and left Meeting where it was. Skirmish moved about six points to Red, which is
roughly one standard deviation at this sample size and so is not separable from
noise without a longer run. Battles also run marginally longer, and Highfield now
ends by destruction slightly more often (20 games rather than 17), which is what
you would expect from formations surviving traffic to go on fighting.

**Highfield is no longer near-even.** The source comment on `HIGHFIELD_WARDENS`
and the previous README both claim roughly 51/49 over 200 games. It now runs 72%
to the Outriders. That measurement predates the rewrite that moved scoring from
per formation to per side, which is exactly the change that would favour the side
bringing more bodies: numbers now buy dice. The comment is stale, not the code.

**Meeting skews to Red** by 71 to 49 despite identical rosters and deployment
placed symmetrically about the objective. At this sample size that is about two
standard deviations from even, so it is suggestive rather than settled. Skirmish
at 62 to 56 is within noise.

**Battles are short.** Highfield averages 5.5 rounds and resolves on the
objective 103 times out of 120 rather than by destruction.

**Known inconsistencies in the code, stated as they are:**

- Retreat battles still score per formation, using `_combat_dice_count` and
  `_opposing_comparators`, while ordinary melee scores per side. The two paths
  have not been unified.
- `calculate_melee` and `calculate_ranged` are the older per-formation helpers.
  They remain for isolated resolution and for the bot's expectations, and are not
  what `_resolve_battle` uses.
- `observed_state` is omniscient despite taking a viewer argument.
- The bot's unknown-enemy Strength assumption of 3 was tuned under the previous
  rules.
- `docs/UI_UPDATE_PLAN.md`, `docs/HEX_MAP_MIGRATION_PLAN.md` and
  `docs/UNIT_ICON_REPLACEMENT_PLAN.md` are plan documents from earlier work.
  Treat them as history.
