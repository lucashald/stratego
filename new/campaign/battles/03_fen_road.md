# Battle 3 — The Fen Road

Scenario: `battles/03_fen_road.json` · Replay: _pending_

## Intent, written before play

**What it is.** A fighting withdrawal. Ashmere came out of Ashweir Bridge as one
Heavy Infantry formation and a supply pool. The whole pool went to remounting
Ferrant's surviving riders — Ember, Medium Cavalry, under-strength. Before the
Line can become an army again, Vare sends a fast column to run it down while it
is at its weakest. Blue has to get south down the Fen Road to the muster ground;
Vare has to catch them before they get there.

**Why this shape, specifically.** It comes straight out of the last debrief and
one correction from the commander.

The rebuild choice was to bring the horse back. But the honest observation was
that one cavalry formation and one Heavy Infantry survivor is *not* a fast band —
it is a split-speed pair. Stonewatch moves one square a round; Ember moves three
or four. They cannot be in the same place, and they cannot cover for each other
the way a matched force can. Rather than design around that, the battle is built
*on* it. A withdrawal is the one scenario where a slow anchor and a fast screen
have genuinely different jobs and both are essential: the heavy is the thing that
has to get out, the horse is the only thing that can buy her the road to do it.

It is also the first time the campaign runs the withdrawal/pursuit objective
pair, which the design log has been flagging as untested since the objective
system shipped. Blue's objective is a `reach` on its own home edge — the engine
already treats a reach toward your own side as a fighting withdrawal. Vare's is a
`survive`: if Blue is not out by round 14, the pursuit has run them down. Reach is
declared first, so getting Stonewatch to the muster on the final round beats the
clock, exactly the way the bridge breakthrough beat the survive-clock at Ashweir,
mirrored.

**The turn limit is the headline fix.** Ashweir ran 28 rounds and was decided by
18 — ten rounds of a won battle playing itself out. This one is 14, and it is
meant to be genuinely tight: Stonewatch needs nine clear rounds of movement to
cover the distance, which leaves only a few rounds of slack for everything the
pursuit does to slow her. The clock should stop being generous the moment the
outcome is no longer in doubt.

**The terrain is a single decision, not a maze.** One marsh at the neck of the
road (row 12), impassable, with a four-square gap in the middle. Everything
funnels through it — Blue going out, Vare coming after. That gap is the natural
place to make Ember's stand: hold it a round or two and Stonewatch gains the road
south; leave it and the fast column pours through and gets in front of her. The
rest of the field is open on purpose, because open ground is where speed wins,
and the whole tension is a slow formation crossing open ground it cannot cross
fast enough alone.

**The cost of the rebuild is on the board.** Bringing back the horse meant no
replacement for the archers. Blue has no ranged formation at all, and Vare's
column has one — Quarrel, a light archer that can chip Stonewatch from a distance
she cannot answer. Eight Strength is a lot to whittle with one bow, but it is the
first time the missing bows are a hole the enemy can actually reach into, and
that is the deferred price of the recruitment choice coming due.

**What I am testing.**

- Whether withdrawal/pursuit plays as a real, different question from hold or
  breakthrough, or whether it collapses into a footrace the slow side just loses.
- Whether a split-speed force is interesting to command or just frustrating —
  whether "the horse buys time the heavy can't" is a decision or a chore.
- Whether 14 rounds is the right length, now that length is being treated as a
  design lever rather than a default. Watch the round the result settles.
- Whether "no bows" reads as a felt consequence of the recruitment choice.

**What I expect to go wrong.** Two risks. If the pursuit can't get in front of
Stonewatch, the withdrawal is trivial and the clock is a formality — that means
Blue starts too close to the muster and the next version starts them deeper. If
the pursuit swarms Ember off the board in two rounds and then walls Stonewatch,
it's unwinnable — that means the gap should be narrower or Ember a little
stronger. The window and the start line are the two dials.

**How I will play Vare.** Personally, and this scenario needs it. A pursuit is
only tense against a pursuer that actually cuts the line off rather than chasing
from behind, and the bot has already shown it can't do that — it fed one lane at
Ashweir and never manoeuvred. So this is explicitly a Claude-commands-Red battle;
a bot-vs-bot verification run will *under*-threaten and shouldn't be read as a
balance check. Outrider leads the column — the same Outrider that rode Harrow
down at the bridge and got away — which makes this the enemy thread coming back
to finish the job it started.

## The recruitment choice

Made already, in the aftermath of Ashweir: bring back the horse. Ember is the
result — Ferrant's remounted survivors, and the entire supply pool spent on them.
The cost is a roster with no bows and no second body, going into a battle where
both of those absences can be felt. That the choice pays for itself or doesn't is
part of what this battle answers.
