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

## Outcome

**Halgate held the Weirgate. Round 11, Vare's host destroyed to the last
formation.** Halgate lost one: Bastion (HI), to Assize's heavy-archer fire. Five
of six walked off the causeway.

Blue's dead (1 of 6): Bastion (HI). Survivors: Portcullis (HI 8, untouched),
Halberd (MI 5), Sable (HA 7), Sterling (MA 6), Merlon (MA 6).
Vare's dead: all six — Sessions, Bulwark, Amerce, Assize, Mandate, Sergeant.

The shape of it: a slaughter down a lane. Vare came on piecemeal and the three
bows erased them a formation at a time before they reached the wall — Sterling and
Merlon opened Mandate and Sergeant, then the whole gunline turned on the Heavies.
**Bulwark** — the campaign's oldest enemy thread, who saw Ashmere break and
carried the tide south — was shot dead on the causeway by Sable, Sterling and
Merlon without landing a blow. Assize, the enemy's own Heavy Archer, was the only
Vare formation to do real damage, killing Bastion before Sable and Merlon put it
down. Amerce tried the flank and Halberd killed it. Nothing crossed.

## Debrief

**The Gate Guard's battle, and it read exactly as designed: slow, hard, and
lethal at range on ground it didn't have to leave.** After Cassewick punished
being slow, the Weirgate rewarded it completely. Three bows on a defended causeway
is a killing floor. Whether that's *too* dominant is the open question — see below.

**The bot cannot press an assault, and a ranged defence curb-stomps it.** The
commander's own read: "the bot played too passively; my ranged attackers ripped
them apart." Correct, and it is the same class of weakness already logged for
chokepoint attacks and pursuit — the bot won't commit weight to force a defended
point, so it fed itself into the bows a piece at a time. The bot-vs-bot
verification said 60/40 to the defender; the human defended far better than
bot-Blue and the result was a wipe. That gap is the finding: **against this bot, a
ranged defensive scenario will always play easier for a human than verification
suggests, because the bot both attacks passively and defends worse than a person.**

**Design consequence for what comes next.** Static defence behind bows is a solved
problem versus this bot. The battles that actually challenge a human are the ones
where the bot can win by passively occupying an objective under a clock — Cassewick
was hard for exactly that reason, the Weirgate easy for the lack of it. Future
strikes should lean that way, or be commanded by me as Red, if they are to be a
contest rather than a shooting gallery.

## Design log entries this earns

Promoted to `design_log.md`:
- Three bows on a defended chokepoint is dominant against the bot; a static ranged
  defence is close to unloseable for a human, whatever the bot-vs-bot split says.
- The bot attacks passively and defends worse than a person, so verification bounds
  "winnable," not "hard." Difficulty must come from objective-and-clock pressure
  the bot can satisfy passively, or from a commanded Red.
