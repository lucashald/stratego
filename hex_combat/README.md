# WEGO Formations — Hex + Combat Prototype

This isolated Godot project combines the flat-top hex battlefield with the comparative-dice combat rewrite. North and south are straight movement directions, movement and range share one six-neighbour metric, and battles use d6 pools, comparative Weight and Strength dice, role dice, margin damage, and cancelling critical 6s.

The stable square-grid development game remains in `../new/`.

## Play

Run this folder's **Play Stratego.bat**, or open this directory in Godot 4.3 or newer.

The default game is the two-player bridge scenario. **New Meeting** starts the symmetric centre-hex battle instead. You command the Blue attacker; Red is controlled by the bot. Open **Settings** to start a four-player fog battle, watch a four-bot exhibition, clear orders, withdraw, or manage replays.

During planning:

1. Select a formation, Shift-click additional formations, or drag a selection rectangle. **Select All** and `Ctrl+A` select every movable formation.
2. Click one of the six on-map direction arrows or use the inspector's six-direction **Move Selection** pad to draw the main path. Keyboard shortcuts are W for north, X/S for south, Q/A for northwest, E for northeast, Z for southwest, and D for southeast. With several formations selected, that direction is applied to every member that still has unused movement.
3. Ghosts numbered 1–3 show the hex each formation intends to occupy on each impulse.
4. Right-click a hex for **Examine**, and, with an Archer selected, **Shoot** or **Suppress**. Shoot follows a targeted formation if it moves; Suppress aims at the chosen hex. A moved Archer may target an adjacent hex. A stationary Archer may declare a long shot; distance one is short range and distance two is long range, with farther declarations serving as overwatch until the target closes.
5. The top-level **Cancel All Orders** button removes every Blue order; the same action remains available as **Clear Orders** in Settings. **Undo** or `Ctrl+Z` restores the previous complete order state, including movement, ranged, group, and cancel-all changes.
6. Choose **End Planning** when planning is complete.

Use the mouse wheel or the `+`/`-` controls to zoom the battlefield. Middle-drag pans the map, clicking or dragging on the minimap centres the main battlefield on that location, and **Fit** restores the default view. Zoom and pan remain available during battle resolution.

The contextual movement-help panel can be dismissed with its **X** button. Dismissing it also hides the selected-formations inspector and Move Selection pad. Use **Help** beside the zoom controls to restore the contextual panels together.

Resolution is presented event-by-event on the battlefield. In a human game, every combat, consequential retreat, and opposing-side tie remains on screen until **Next** is clicked; harmless friendly congestion is applied without adding a click-through card. **Order Leftover** on the final main-resolution event opens a dedicated **Leftover Movement** order phase after ranged attacks. Select one or more eligible formations, choose one direction, and then click **End Leftover**. Exhausted selections are skipped. The simultaneous leftover moves and any resulting battles then receive their own click-through review; **Next Round** after that review starts the next round. First, Previous, and Last allow review without dismissing the sequence. Four-bot spectator battles still advance automatically. The active-battle card shows the revealed formations, rolls, final scores, damage, remaining Strength, and result. The phase banner shows the current event number, and the bottom timeline tracks impulses, battles, retreats, ranged attacks, and leftover movement.

The game rejects orders from one player that would make friendly formations occupy or swap through the same empty hex on the same impulse. During reposition, one or more formations may instead move into a hex held by a stationary friendly formation: an enemy arrival makes everyone there part of one multiway battle, while no enemy arrival produces harmless congestion. Multiple friendly attackers may also converge on a known enemy for a multiway battle.

**Withdraw** is available during planning. It immediately concedes the scenario while preserving every surviving formation at its current Strength. It does not revive destroyed units. There is no automatic material-collapse rule yet.

**Export Replay** is available between rounds, during the click-through combat review, while waiting for reposition orders, and after battle. It writes a timestamped JSON file to this project's `replays` folder and updates `replays/last_replay.json` for the **Replay Last** slot. An in-progress export includes the current round through movement, melee, and missiles, so an odd result can be saved before continuing. The versioned file records scenario setup, seed, orders, the exact dice stream, and verification digests. **Replay Last** rebuilds the saved state through the authoritative engine and rejects any divergence.

## Round sequence

1. Main movement resolves simultaneously in three impulses: Light moves on 1, 2, and 3; Medium moves on 2 and 3; Heavy moves only on 3. Only movement steps actually attempted are spent, including an attempted entry that ends in a bounce.
2. Every melee batch resolves, followed by all retreats from that batch simultaneously.
3. Eligible Archer attacks resolve simultaneously. Aiming has already cost one movement point during main movement; a long shot that finds its target consumes the Archer's remaining movement, while a short shot or a shot that fizzles costs only the aim point.
4. The game pauses for new orders, then eligible units may make a simultaneous leftover move of at most one hex.
5. Victory is checked at the end of the round.

Winning the main melee stops the unit's remaining main path, but it may still shoot during the ranged phase or use its one-hex leftover move if it has movement available. Losing, or tying for the highest score with an opposing side, ends the unit's actions for the round.

## Combat

Every participant rolls a pool of d6 and keeps the single highest die. Score is
that die plus current Strength, so Strength is damage rather than a cap on the
roll. There is no Armor stat.

The pool is one base die plus one for each of:

- being the **heavier** of the two. Comparative, not a tier: two Heavies give
  each other nothing.
- being the **stronger** of the two by current Strength. Also comparative, so
  chip damage that drops a formation below its enemy costs it this die as well
  as the score.
- being **Cavalry attacking** or **Infantry defending**.

In a multiway fight, a comparative die has to be earned against every enemy on
the hex, not just the weakest one present.

- Crossing-path enemies are both attackers: both Cavalry dice can apply and
  neither Infantry defense die does.
Damage has two independent sources:

- **The score margin**, paid only by the loser. A tie costs nobody a margin.
- **Surviving 6s.** Every 6 rolled is one extra damage, but 6s cancel across
  the two sides one for one; a 6 each is worth nothing to either, and your own
  two 6s do not cancel each other. Unlike the margin, these land whatever the
  scores did, so a formation being overrun can still put one through the winner
  on its way down, and a draw can still draw blood. Because they cancel, at
  most one side is ever owed crit damage in a single clash.

In a multiway fight the margin comes from whoever beat you hardest, while a 6
counts from any enemy on the hex: a crit is a lucky blow, not a won contest.

Damage is still bounded by the margin plus a point or two, so a healthy
formation cannot be destroyed in a single melee. Attrition is the only way
through one.
- A unique highest scorer wins the hex.
- A highest-score tie across opposing sides is a bounce. Every surviving participant returns to its previous hex and is done for the round.

Multiway battles allow several attackers, including several formations from one side. Opposing losers retreat. Friendly non-winning attackers return without a status penalty. If same-side formations tie for the highest score while beating the enemy, their side still wins: the enemy retreats, the tied friendly leaders return, and the contested hex is left empty. If opposing sides tie for the highest score, there is no winning side; every surviving participant returns and is done for the round.

Retreats first use the neighbouring hex most directly away from the strongest opponent. If that exact hex contains a friendly formation, the loser shunts into the adjacent left-hand retreat hex, or the right-hand one if left is unavailable. An enemy in the direct retreat hex still destroys the loser without allowing a shunt; the same is true of water, lake terrain, the board edge, or all three friendly-blocked destinations being unavailable. Retreats are evaluated after every battle in the batch. Enemy retreats entering the same previously empty hex fight a retreat battle. The comparative Weight and Strength dice still apply, but no role die does: nobody there is charging or braced. The loser is destroyed and a tie destroys both, with no further retreat.

A shot is a contest, not a threshold. The Archer rolls a base die plus the
heavier and stronger dice, plus one more for a **short** shot; the target rolls
the base die plus its own heavier and stronger dice, and never gets a role or
range die. The Archer wins the contest only if its score is strictly higher,
which is worth the margin. Surviving 6s are added on top and land either way,
so an Archer that loses the contest outright still chips for any 6 the target
failed to match - a hopeless shot is never fired for literally nothing, and the
target's own 6s are its only answer. A miss that still drew blood is reported
as a graze rather than a hit. So a short shot is both cheaper and more
accurate, while a long shot keeps only its standoff range.

Ranged focus fire is simultaneous. All valid shots resolve and excess damage is lost.

## Fog and information

Fog uses a four-hex radius. Seeing an enemy during any impulse records that it was seen even if it leaves sight before the round ends. Observed speed intentionally reveals Weight. Combat reveals role, Weight, and current Strength while the target remains in sight. With private combat information enabled, detailed results go only to the participating players; spectator view is omniscient.

## Bridge scenario

- Blue attacker: twelve formations, 82 starting Strength, deployed on its board edge.
- Red defender: twelve formations, 82 starting Strength, deployable anywhere north of the river but never on the bridge.
- The four bridge hexes are passable; the other river hexes are impassable.
- Blue wins by ending a round with at least 20 current Strength north of the river.
- Red wins if Blue has not done so by the end of Round 20. The turn limit is explicitly a testing value.

## Meeting engagement

Both armies field the same twelve formations and deploy on their own back rank. The centre hex is the objective: hold it alone at the end of three consecutive rounds to win. Losing it for a single round resets the count, and if neither side has consolidated it by round 20 the battle is a draw.

Unlike the bridge crossing, trading evenly does not favour either side: the win goes to whoever holds the ground, not to whoever survives the attrition.

## Scenarios and objectives

Terrain and victory conditions are data rather than per-scenario branches. A scenario lays its terrain during setup and declares one or more typed objectives:

- `reach_area` — a player wins with a given Strength inside a rectangle at the end of a round
- `hold_square` — a player wins by holding one hex alone for a number of consecutive rounds
- `survive` — a player wins by still standing at a given round

Objectives resolve in the order declared, so a scenario sets its own precedence; the bridge attacker breaking through on the final round beats the defender's turn-limit win because it is declared first. Losing an entire army loses the game regardless. Each objective reports a one-line summary of its win condition alongside its current progress, so a bot or external controller can play a new scenario without special-casing it.

## Four-player mode

Four-player mode retains the symmetric twelve-formation, 80-Strength armies plus Flags. Each color normally begins as its own side, while the engine supports assigning multiple colors to one team. Capturing a Flag eliminates that army; the last remaining army/team wins.

## Tests

Run this folder's **Test Stratego.bat**, or:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

The deterministic suite covers flat-top odd-column neighbours, hex radius counts, coordinate and pixel round trips, fog, delayed Weight-based impulse timing, movement and collisions, comparative bonus dice, cross-side crit cancelling, multiway battles, margin-only damage, aimed and suppressing Archer fire, directional retreats, objectives, replay round trips and tamper rejection, and four-bot round resolution.

## Formation banners

Revealed movable formations use the shared Green banner set. The border and
equipment artwork communicate Weight and Role, while the large live numeral
shows current Strength. Until the other faction sets are produced, every army
uses the same Green art with a small faction-colour marker for battlefield
identification. Hidden enemy identities and Flags retain the information-safe
procedural banner.
