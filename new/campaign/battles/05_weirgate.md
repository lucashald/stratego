# Battle 5 — The Weirgate

Scenario: `battles/05_weirgate.json` · Replay: _pending_

Turn 2 of the Halgate campaign. The mirror of Cassewick: where the raid rewarded
speed, the causeway rewards a wall that does not move.

## The deployment choice (turn 2)

Intelligence in `dispatch_02.md`: Vare's heavy main host — Bulwark leading, two
Heavies, a Heavy Archer, two Medium Infantry, a cavalry escort, ~44 Strength —
marching on the Weirgate causeway. The commander sent the **Gate Guard** (its
battle) and hired a **Medium Archer, Merlon**, topping off the two under-strength
formations. Treasury 15 → 5 (Merlon 8, reinforcement 2).

Deployed force (six formations, **three bows** on the wall): Portcullis (HI 8),
Halberd (MI 7), Bastion (HI 8), Sable (HA 7), Sterling (MA 6), Merlon (MA 6).
Against Bulwark (HI 8), Sessions (HI 8), Assize (HA 7), Mandate (MI 7), Sergeant
(MI 7), Amerce (MC 7).

## Intent, written before play

**What it is.** A defence of a fortified crossing. The millwater guards both
flanks; the causeway is a three-span gate, the only way across. Halgate plants two
Heavies and a Medium at the gate mouth with three bows on the parapet behind, and
holds for twelve rounds. Vare wins by forcing 19 Strength through the gate into
Halgate's rear — a real breakthrough, most of their army across a defended pinch,
not a lucky runner.

**Why this shape.** It is the Gate Guard's whole reason to exist, and the answer
to the question Cassewick asked from the other side. At Cassewick, being slow lost
the yard to a fast raid. Here, being slow costs nothing, because the Guard is not
going anywhere — the fight comes to it, down a lane one wall can hold, under three
bows it cannot cross without being shot. This is "become the harder thing" given a
board to be hard on.

**Where the three bows earn out.** A causeway assault is archer food: the enemy
has to cross open, funnelled ground to reach the wall, and every step of it is in
range. Sable, Sterling and Merlon are the difference between a wall that merely
holds and a wall that thins the host before it ever arrives. The extra MA was
hired for exactly this geometry.

**The risk.** Vare is heavier than the Guard (44 to 42) and brings its own Heavy
Archer, Assize, to trade fire, and a cavalry escort to try the flank the water is
supposed to protect. Hold the gate poorly — let the line be pulled out of shape,
or lose a Heavy early — and the pinch opens and the host pours through. The
reposition phase matters here too: Vare only needs to be *past* the wall when the
round ends.

**What I am testing.**
- Whether a broad-gate line-hold plays differently from Ashweir's pinhole
  chokepoint, or collapses into the same thing.
- Whether three bows on a defended causeway is dominant, fair, or still not enough
  against heavier weight.
- Whether the Gate Guard's identity — slow, hard, ranged — reads as strong when
  finally given the battle it wants.

## Verification

Run bot-vs-bot, 60 games (the Fen Road rule): **Blue (Halgate) 36, Vare 24, avg
11.5 rounds, every game decided by the objective (36 holds, 24 breakthroughs).**
A near-even contest that leans to the defender — which for a human commanding the
wall (a better defender than the bot) should read as a winnable but genuinely
tense hold, where a careless line loses the gate and a disciplined one keeps it.
Tuned here deliberately: an earlier cut had Vare breaking through 70%, another had
the wall impregnable at 95%; the breakthrough bar (19 Strength) is the dial that
put it in the doubt zone.
