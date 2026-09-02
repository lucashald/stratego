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
4. The top-level **Cancel All Orders** button removes every Blue order; the same action remains available as **Clear Orders** in Settings. **Undo** or `Ctrl+Z` restores the previous complete order state, including movement, group, and cancel-all changes.
5. After the main clash resolves, every eligible formation receives one post-clash action. Move one adjacent hex, or select an Archer and right-click for **Attack** or **Volley**. Attack follows a targeted formation through reposition; Volley aims at a fixed hex. Both have a maximum range of two hexes.
6. Choose **End Planning** when planning is complete.

Use the mouse wheel or the `+`/`-` controls to zoom the battlefield. Middle-drag pans the map, clicking or dragging on the minimap centres the main battlefield on that location, and **Fit** restores the default view. Zoom and pan remain available during battle resolution.

The contextual movement-help panel can be dismissed with its **X** button. Dismissing it also hides the selected-formations inspector and Move Selection pad. Use **Help** beside the zoom controls to restore the contextual panels together.

Resolution is presented event-by-event on the battlefield. In a human game, every combat, consequential retreat, and opposing-side tie remains on screen until **Next** is clicked; harmless friendly congestion is applied without adding a click-through card. **Order Reposition** on the final main-resolution event opens the post-clash action phase. Every eligible formation may hold or move one adjacent hex; an Archer instead may Attack a visible formation or Volley a visible hex within range two. Click **End Reposition** to reveal all choices. Reposition movement, its battles, and retreats resolve first, followed by all surviving Archer attacks. **Next Round** after that review starts the next round. First, Previous, and Last allow review without dismissing the sequence. Four-bot spectator battles still advance automatically. The active-battle card shows the revealed formations, rolls, final scores, damage, remaining Strength, and result. The phase banner shows the current event number, and the bottom timeline tracks impulses, battles, retreats, reposition, and ranged attacks.

The game rejects orders from one player that would make friendly formations occupy or swap through the same empty hex on the same impulse. During reposition, Cavalry may deliberately enter an enemy-held hex; Infantry and Archers may enter only empty or friendly hexes. Opposing formations that simultaneously reposition into the same empty hex still fight, with every arrival counted as an attacker. Friendly congestion and bounce rules still handle formations converging on a quiet friendly-held hex, but a friendly hex with a fight pending on it is joined as support rather than bounced off.

**Withdraw** is available during planning. It immediately concedes the scenario while preserving every surviving formation at its current Strength. It does not revive destroyed units. There is no automatic material-collapse rule yet.

**Export Replay** is available between rounds, during the click-through combat review, while waiting for post-clash actions, and after battle. It writes a timestamped JSON file to this project's `replays` folder and updates `replays/last_replay.json` for the **Replay Last** slot. An in-progress export includes the current round through the resolved main clash, so an odd result can be saved before continuing. The versioned file records scenario setup, seed, orders, the exact dice stream, and verification digests. **Replay Last** rebuilds the saved state through the authoritative engine and rejects any divergence.

## Round sequence

1. Main movement resolves simultaneously in three impulses: Light moves on 1, 2, and 3; Medium moves on 2 and 3; Heavy moves only on 3. Only movement steps actually attempted are spent, including an attempted entry that ends in a bounce. Entering a contested hex commits a formation to the fight standing there and ends its movement for the round, but nothing is rolled yet.
2. Once all three impulses have moved, every melee resolves in a single pass, followed by all retreats simultaneously. Holding the dice until movement is finished is what lets formations that arrive on different impulses fight the same battle together.
3. The game pauses for post-clash actions. Every surviving formation that did not lose, suffer an opposing-side tie, or reach the two-melee limit may hold or reposition one hex. An Archer may shoot instead of repositioning.
4. Reposition movement resolves simultaneously. Cavalry may deliberately attack an occupied enemy hex; other roles cannot. Opposing formations that meet in a formerly empty hex fight as attackers.
5. Reposition battles and retreats finish, then every still-eligible Archer attack resolves simultaneously. The shot's final range determines its accuracy: range 1 adds one Archer die and range 2 does not.
6. Victory is checked at the end of the round.

Committing to a main-phase melee stops the unit's remaining main path at the moment of contact, whatever the fight later decides. Winning still leaves it free to take its post-clash action. Losing, or tying with an opposing side, ends the unit's actions for the round. An Archer that chooses to shoot loses that shot if it is defeated or tied in a reposition battle before ranged fire resolves.

## Combat

A melee is fought between sides rather than between formations. Each side rolls
a pool of d6 and keeps its single highest die. Score is that die plus the current
Strength of the strongest formation on that side, so Strength is damage rather
than a cap on the roll. There is no Armor stat.

Numbers are paid out in dice and nowhere else. Bringing a second formation gets
you another die and a better chance at a high one, not a second Strength added
into the score, so a gang wins more often without the win being a foregone
conclusion. A side of one rolls exactly the pool a lone formation has always
rolled, which leaves single combat unchanged.

A side's pool is one die per formation it has in the fight, plus one for each of:

- being the **stronger** side, comparing the best current Strength each side can
  field. Comparative, so evenly matched sides give each other nothing, and chip
  damage that drops a side's leader below its enemy costs it this die as well as
  the score.
- fielding the **uniquely heaviest** formation present. A Heavy facing Mediums
  earns it. A Heavy facing another Heavy does not, however many Mediums stand
  behind either one.
- each **Cavalry attacking**, and each **Infantry defending**.

### Who is defending

Whoever reached the contested hex first is defending. Everyone who arrived later
is attacking, whichever side they are on. A formation already standing there
arrived before the round began and defends against all comers.

Arrival impulse works out to `3 - unused movement`, so a formation that spends
its whole allowance always arrives on impulse 3, and one that holds a step back
arrives sooner. Bracing is not sprinting. A Light stepping a single hex arrives
on impulse 1 and out-braces nearly anything, while a Heavy that moves at all
arrives on impulse 3 and can only defend ground it was already holding.

A formation is braced only if it reached the hex before any enemy did. Landing on
the same impulse as an enemy means neither of you had time to set, so neither is
braced. That covers crossing-path enemies, who are both attacking, so both
Cavalry dice can apply and neither Infantry defense die does. Allies who arrive
together are all braced, because the race that earns the die is against the enemy
rather than against each other. A reinforcement that shows up no sooner than the
enemy is attacking as well, and adds no defense die.

### Joining a fight

Moving onto a hex where a fight is already pending joins that fight instead of
bouncing off it. An enemy joins as another attacker and a friend joins as
support. A crossing fight involves both of the hexes its participants are
trading, so entering either one joins it.

Committing to a fight vacates the hex behind you, so an ally queued there can
advance into it on the same impulse and a winning line does not tear itself
apart as it moves.

### Damage

Damage has two independent sources:

- **The score margin**, paid by every formation on the losing side. A tie costs
  nobody a margin.
- **Surviving 6s.** Every 6 a side rolls is one extra damage to the other side,
  but 6s cancel across the two sides one for one; a 6 each is worth nothing to
  either, and one side's own two 6s do not cancel each other. Unlike the margin
  these land whatever the scores did, so a side being overrun can still put one
  through the winner on its way down, and a draw can still draw blood. Because
  they cancel, at most one side is ever owed crit damage in a single clash.

Because only the leading formation's Strength scores, the margin stays inside the
range a formation can absorb, and a healthy one cannot be destroyed in a single
melee however many enemies it faces. Attrition is still the only way through one.
What numbers buy is consistency: extra dice mean a side keeps a good die far more
often, so a gang wins most exchanges and takes its target apart across several
rounds rather than deleting it in one.

### Holding the hex

The higher score wins the hex for its side. Equal scores are a bounce, and every
surviving participant returns to its previous hex and is done for the round.

Each survivor on the winning side then takes the hex it was ordered into, if that
hex is still free when it is placed, and otherwise returns where it started. If
the square it started from has been filled too, normally by the ally that
advanced into the gap behind it, it falls back to whichever neighbouring hex
leads most directly away from the contested one. All six are tried before a
formation that never lost its fight is destroyed for standing in traffic, which
is more forgiving than the three options a retreat gets.
Claims are settled in arrival order, so a defender that held its ground keeps it
and its own reinforcements cannot shove it off. In an ordinary fight every
attacker was ordered into the same hex, so one takes it and the rest come home.
In a crossing fight the participants were ordered into different hexes, so an
advancing line can take both and stay together.

Every formation on the losing side retreats.

Retreats first use the neighbouring hex most directly away from the strongest opposing formation, measured by current Strength now that score belongs to the side rather than to any one formation, with an earlier arrival breaking a tie. If that exact hex contains a friendly formation, the loser shunts into the adjacent left-hand retreat hex, or the right-hand one if left is unavailable. An enemy in the direct retreat hex still destroys the loser without allowing a shunt; the same is true of water, lake terrain, the board edge, or all three friendly-blocked destinations being unavailable. Retreats are evaluated together, once the round's melee pass has resolved every battle. Enemy retreats entering the same previously empty hex fight a retreat battle. The comparative Weight and Strength dice still apply, but no role die does: nobody there is charging or braced. The loser is destroyed and a tie destroys both, with no further retreat.

A shot is a contest, not a threshold. The Archer rolls a base die plus the
heavier and stronger dice, plus one more for a **short** shot; the target rolls
the base die plus its own heavier and stronger dice, and never gets a role or
range die. The Archer wins the contest only if its score is strictly higher,
which is worth the margin. Surviving 6s are added on top and land either way,
so an Archer that loses the contest outright still chips for any 6 the target
failed to match - a hopeless shot is never fired for literally nothing, and the
target's own 6s are its only answer. A miss that still drew blood is reported
as a graze rather than a hit. Range-1 fire is more accurate, while firing from
range 2 keeps only the advantage of distance.

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

## Highfield

Two asymmetric armies fight for one central hill, the same hold-the-hex objective as the meeting, but the forces are built to opposite theories of war. **Red, the Wardens** are seven heavy formations — heavy foot and two Heavy Archers around a Heavy Cavalry, with a medium pair — that win by attrition and by holding the hill as an intact wall, but are slow and few and lose if they advance piecemeal into numbers. **Blue, the Outriders** are nine faster formations — a medium core with light horse on the wings and two bows behind — that win by reaching the hill first, flanking, and massing on the objective, and lose any straight slug. Blue commands the Outriders.

Every formation on both sides starts at the same Strength. The armies differ in Weight, Role, and numbers, not in a strength total, which makes this the standard scenario that most directly tests those levers. It is tuned to a near-even bot-vs-bot result (~51/49 over 200 games) with no dead weight in either list; because the bot underplays the faster, flanking army, a human commanding the Outriders should find them a touch stronger than the bot does.

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

Every faction has its own complete banner set, including Flags and an
information-safe unknown banner. The cloth identifies the faction, while the
border and equipment artwork communicate Weight and Role and the large live
numeral shows current Strength. A visible but unidentified enemy uses its
faction's unknown banner without leaking Role or Strength.
