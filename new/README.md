# WEGO Formations — New Rules Prototype

This Godot project is the development version of the Stratego-like formation game. It preserves the 20×20 board, four player colors, four-square fog of war, private combat information, Flags, bots, and spectator play while replacing sequential formation turns with simultaneous WEGO rounds.

The stable classic game remains in `../classic/`.

## Play

Run **Play New.bat** from the repository root, or open this directory in Godot 4.3 or newer.

The default game is the two-player bridge scenario. **New Meeting** starts the symmetric centre-square battle instead. You command the Blue attacker; Red is controlled by the bot. Open **Settings** to start a four-player fog battle, watch a four-bot exhibition, clear orders, withdraw, or manage replays.

During planning:

1. Select a formation, Shift-click additional formations, or drag a selection rectangle. **Select All** and `Ctrl+A` select every movable formation.
2. Click one of the large on-map direction arrows, use the inspector's **Move Selection** buttons, or press an arrow/WASD key to draw the main path. With several formations selected, that direction is applied to every member that still has unused movement. Exhausted Heavy or Medium formations are skipped while faster formations continue. Terrain, off-board, or friendly-collision failures still reject the resulting group step.
3. Ghosts numbered 1–3 show the square each formation intends to occupy on each impulse.
4. Right-click a square for **Examine**, and, with an Archer selected, **Shoot** or **Suppress Square**. Shoot aims at that formation and follows it if it moves; Suppress aims at the ground and hits whoever is standing there when the shot resolves. Aiming costs one movement point during main movement, spent whether or not the shot finds a target. Movement already ordered restricts what may be declared: a formation that has moved may only target an adjacent square, while a stationary one may also declare a long shot, including overwatch on a target further than two squares away that fires only if it closes. A long shot that fires consumes everything the Archer had left.
5. The top-level **Cancel All Orders** button removes every Blue order; the same action remains available as **Clear Orders** in Settings. **Undo** or `Ctrl+Z` restores the previous complete order state, including movement, ranged, group, and cancel-all changes.
6. Choose **End Planning** when planning is complete.

Use the mouse wheel or the `+`/`-` controls to zoom the battlefield. Middle-drag pans the map, clicking or dragging on the minimap centres the main battlefield on that location, and **Fit** restores the default view. Zoom and pan remain available during battle resolution.

The contextual movement-help panel can be dismissed with its **X** button. Dismissing it also hides the selected-formations inspector and Move Selection pad. Use **Help** beside the zoom controls to restore the contextual panels together.

Resolution is presented event-by-event on the battlefield. In a human game, every combat, consequential retreat, and opposing-side tie remains on screen until **Next** is clicked; harmless friendly congestion is applied without adding a click-through card. **Order Leftover** on the final main-resolution event opens a dedicated **Leftover Movement** order phase after ranged attacks. Select one or more eligible formations, choose one direction, and then click **End Leftover**. Exhausted selections are skipped. The simultaneous leftover moves and any resulting battles then receive their own click-through review; **Next Round** after that review starts the next round. First, Previous, and Last allow review without dismissing the sequence. Four-bot spectator battles still advance automatically. The active-battle card shows the revealed formations, rolls, final scores, damage, remaining Strength, and result. The phase banner shows the current event number, and the bottom timeline tracks impulses, battles, retreats, ranged attacks, and leftover movement.

The game rejects orders from one player that would make friendly formations occupy or swap through the same empty square on the same impulse. During reposition, one or more formations may instead move into a square held by a stationary friendly formation: an enemy arrival makes everyone there part of one multiway battle, while no enemy arrival produces harmless congestion. Multiple friendly attackers may also converge on a known enemy for a multiway battle. Hidden orders from a separately controlled ally can collide during resolution; those formations return to their previous squares without a round-status penalty.

**Withdraw** is available during planning. It immediately concedes the scenario while preserving every surviving formation at its current Strength. It does not revive destroyed units. There is no automatic material-collapse rule yet.

**Export Replay** is available between rounds and after battle. It writes a timestamped JSON file to `C:\stratego\replays` and updates `replays/last_replay.json` for the **Replay Last** slot. The versioned file records scenario setup, seed, orders from both order phases, the exact dice stream, and verification digests. **Replay Last** rebuilds the match through the authoritative engine, rejects any divergence, and then lets you click through every consequential recorded result before showing the reproduced final battlefield.

## Round sequence

1. Main movement resolves simultaneously in three impulses: Light moves on 1, 2, and 3; Medium moves on 2 and 3; Heavy moves only on 3. Only movement steps actually attempted are spent, including an attempted entry that ends in a bounce.
2. Every melee batch resolves, followed by all retreats from that batch simultaneously.
3. Eligible Archer attacks resolve simultaneously. Aiming has already cost one movement point during main movement; a long shot that finds its target consumes the Archer's remaining movement, while a short shot or a shot that fizzles costs only the aim point.
4. The game pauses for new orders, then eligible units may make a simultaneous leftover move of at most one square.
5. Victory is checked at the end of the round.

Winning the main melee stops the unit's remaining main path, but it may still shoot during the ranged phase or use its one-square leftover move if it has movement available. Losing, or tying for the highest score with an opposing side, ends the unit's actions for the round. Friendly congestion and returning as a friendly non-winner carry no separate status penalty. This permits at most one main-path melee and one intentional leftover melee.

## Combat

Every participant rolls a d10 capped by current Strength.

- Cavalry receives +3 when attacking.
- Infantry receives +3 when defending.
- Crossing-path enemies are both attackers: both Cavalry bonuses can apply and neither Infantry defense bonus applies.
- Each formation takes damage from the highest opposing battle score, reduced by Armor.
- A unique highest scorer wins the square. Its Armor is doubled for that combat: Light 0, Medium 2, Heavy 4.
- A natural 10 adds one damage after Armor and always chips.
- A highest-score tie across opposing sides is a bounce. Every surviving participant returns to its previous square and is done for the round.

Multiway battles allow several attackers, including several formations from one side. Opposing losers retreat. Friendly non-winning attackers return without a status penalty. If same-side formations tie for the highest score while beating the enemy, their side still wins: the enemy retreats, the tied friendly leaders return, and the contested square is left empty. If opposing sides tie for the highest score, there is no winning side; every surviving participant returns and is done for the round.

Retreat destinations are evaluated after every battle in the batch. Off-board, water, lake, or occupied retreat destinations destroy the loser. Enemy retreats entering the same previously empty square fight a retreat battle with no posture or role bonuses; the loser is destroyed and a tie destroys both, with no further retreat.

Ranged focus fire is simultaneous. All valid shots resolve and excess damage is lost.

## Fog and information

Fog remains four-square Manhattan vision. Seeing an enemy during any impulse records that it was seen even if it leaves sight before the round ends. Observed speed intentionally reveals Weight. Combat reveals role, Weight, and current Strength while the target remains in sight. With private combat information enabled, detailed results go only to the participating players; spectator view is omniscient.

## Bridge scenario

- Blue attacker: twelve formations, 82 starting Strength, deployed on its board edge.
- Red defender: twelve formations, 82 starting Strength, deployable anywhere north of the river but never on the bridge.
- The four bridge squares are normal squares; the other river squares are impassable.
- Blue wins by ending a round with at least 20 current Strength north of the river.
- Red wins if Blue has not done so by the end of Round 20. The turn limit is explicitly a testing value.

## Meeting engagement

Both armies field the same twelve formations and deploy on their own back rank, so neither side starts near the objective and arriving first is actually possible. The centre square is the objective: hold it alone at the end of three consecutive rounds to win. Losing it for a single round resets the count, and if neither side has consolidated it by round 20 the battle is a draw.

Unlike the bridge crossing, trading evenly does not favour either side: the win goes to whoever holds the ground, not to whoever survives the attrition.

## Scenarios and objectives

Terrain and victory conditions are data rather than per-scenario branches. A scenario lays its terrain during setup and declares one or more typed objectives:

- `reach_area` — a player wins with a given Strength inside a rectangle at the end of a round
- `hold_square` — a player wins by holding one square alone for a number of consecutive rounds
- `survive` — a player wins by still standing at a given round

Objectives resolve in the order declared, so a scenario sets its own precedence; the bridge attacker breaking through on the final round beats the defender's turn-limit win because it is declared first. Losing an entire army loses the game regardless. Each objective reports a one-line summary of its win condition alongside its current progress, so a bot or external controller can play a new scenario without special-casing it.

## Four-player mode

Four-player mode retains the symmetric twelve-formation, 80-Strength armies plus Flags. Each color normally begins as its own side, while the engine supports assigning multiple colors to one team. Capturing a Flag eliminates that army; the last remaining army/team wins.

## Tests

Run **Test New.bat**, or:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

The deterministic suite covers setup, fog, delayed weight-based impulse timing, actual movement spending, order rejection, allied and combat bounces, crossing attacks, doubled winner Armor, natural 10s, multiway battles, highest-opponent damage, focus fire, aimed and suppressing Archer fire, overwatch fizzles and their aim cost, leftover melee, blocked retreats, retreat battles, transient sightings, bridge victory, withdrawal, the absence of automatic collapse, replay JSON/file round trips, replay tamper rejection, and four-bot round resolution.

## Formation banners

Revealed movable formations use the shared Green banner set. The border and
equipment artwork communicate Weight and Role, while the large live numeral
shows current Strength. Until the other faction sets are produced, every army
uses the same Green art with a small faction-colour marker for battlefield
identification. Hidden enemy identities and Flags retain the information-safe
procedural banner.
