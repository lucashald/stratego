# WEGO Formations — New Rules Prototype

This Godot project is the development version of the Stratego-like formation game. It preserves the 20×20 board, four player colors, four-square fog of war, private combat information, Flags, bots, and spectator play while replacing sequential formation turns with simultaneous WEGO rounds.

The stable classic game remains in `../classic/`.

## Play

Run **Play New.bat** from the repository root, or open this directory in Godot 4.3 or newer.

The default game is the two-player bridge scenario. You command the Blue attacker; Red is controlled by the bot. The screen can also start a four-player fog battle or a four-bot exhibition.

During planning:

1. Select one of your formations.
2. Click adjacent squares to draw its main path. Ghosts numbered 1–3 show the square it intends to occupy on each impulse.
3. For an Archer, enable **Archer target** and click an adjacent visible enemy to schedule a shot.
4. Enable **Set leftover move** and click one adjacent square to schedule the unit's post-ranged move.
5. Right-click to remove the selected unit's last main-path impulse. **Clear My Orders** removes every Blue order.
6. Choose **Ready & Resolve** when planning is complete.

The game rejects orders from one player that would make friendly formations occupy or swap through the same square on the same impulse. Multiple friendly attackers may still converge on a known enemy for a multiway battle. Hidden orders from a separately controlled ally can collide during resolution; those formations bounce without combat and are done for the round.

**Withdraw** is available during planning. It immediately concedes the scenario while preserving every surviving formation at its current Strength. It does not revive destroyed units. There is no automatic material-collapse rule yet.

## Round sequence

1. Main movement resolves simultaneously in up to three impulses: Light 3, Medium 2, Heavy 1.
2. Every melee batch resolves, followed by all retreats from that batch simultaneously.
3. Eligible Archer attacks resolve simultaneously. A shot costs one unused movement point.
4. Eligible units may make a simultaneous leftover move of at most one square.
5. Victory is checked at the end of the round.

Winning the main melee stops the unit's remaining main path, but it may still shoot or use its one-square leftover move if it has movement available. Losing or bouncing ends the unit's actions for the round. This permits at most one main-path melee and one intentional leftover melee.

## Combat

Every participant rolls a d10 capped by current Strength.

- Cavalry receives +3 when attacking.
- Infantry receives +3 when defending.
- Crossing-path enemies are both attackers: both Cavalry bonuses can apply and neither Infantry defense bonus applies.
- Each formation takes damage from the highest opposing battle score, reduced by Armor.
- A unique highest scorer wins the square. Its Armor is doubled for that combat: Light 0, Medium 2, Heavy 4.
- A natural 10 adds one damage after Armor and always chips.
- A score tie is a bounce, not a defender win or a loss. Bounced formations return to their previous squares, receive no winner benefit, and are done for the round.

Multiway battles allow several attackers, including several formations from one side. Opposing losers retreat. Friendly non-winning attackers bounce. If same-side formations tie for the highest score while beating the enemy, the enemy retreats, the tied friendly leaders bounce, and the contested square is left empty. If opposing sides tie for the highest score, there is no unique winner and the tied leaders bounce.

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

## Four-player mode

Four-player mode retains the symmetric twelve-formation, 80-Strength armies plus Flags. Each color normally begins as its own side, while the engine supports assigning multiple colors to one team. Capturing a Flag eliminates that army; the last remaining army/team wins.

## Tests

Run **Test New.bat**, or:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

The deterministic suite covers setup, fog, impulse paths, order rejection, allied and combat bounces, crossing attacks, doubled winner Armor, natural 10s, multiway battles, highest-opponent damage, focus fire, ranged eligibility, leftover melee, blocked retreats, retreat battles, transient sightings, bridge victory, withdrawal, the absence of automatic collapse, and four-bot round resolution.

## Piece codes

Revealed formations display `weight + role + current Strength`:

- Weight: `L` Light · `M` Medium · `H` Heavy
- Role: `I` Infantry · `A` Archer · `C` Cavalry
- Example: `HI8` is Heavy Infantry at Strength 8; `MA3` is Medium Archer reduced to Strength 3.
