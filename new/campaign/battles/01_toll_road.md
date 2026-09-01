# Battle 1 — The Toll Road

Scenario: `battles/01_toll_road.json` · Replay: `replays/01_toll_road.json`

**Played against the bot, not me** — I hit a usage limit mid-battle before I
could take the field as Vare. So this baseline is contaminated in a different
way than the one I was guarding against: not by me being clever, but by the
opponent being a scoring function instead of a commander. Worth remembering
when reading the outcome below, and worth deciding whether to replay it with
me actually seated across the board.

The export also surfaced two real bugs in the replay system, both now fixed:
it couldn't reconstruct a campaign battle's actual army at all, and separately
couldn't reproduce a match played with "Cavalry always repositions" on. This
file's outcome was recovered by hand, from the original scenario plus the
recorded orders and dice — not read directly off a working replay, since the
one exported that night predates both fixes.

## Intent, written before play

**What it is.** Nine formations a side, identical rosters, symmetric deployment
across the gap at Oxfell. Hold the centre square for three consecutive rounds,
22-round limit.

**Why it opens the campaign.** A baseline. The rosters are mirrored so nothing
about the result can be blamed on the matchup, which makes it the one battle in
the campaign where the variable being tested is the commanding rather than the
composition. Everything after this is deliberately lopsided in one direction or
another, and I want one honest reading of an even fight first.

**What I am testing.**

- Whether hold-the-centre generates a real decision about *when* to commit, or
  whether both sides simply walk to the middle and the dice decide.
- Whether nine a side is too many to keep track of. My suspicion is that it is
  slightly too many, and that the campaign's more interesting battles will be
  smaller, but suspicion is not evidence.
- How long it takes before the outcome stops being in doubt. The 22-round limit
  is generous on purpose so that the natural length shows itself rather than
  being imposed.

**What I expect to go wrong.** The centre is equidistant, so both sides arrive
at once and the first contact is a scrum rather than a manoeuvre. If that reads
as a coin toss rather than a fight, the objective needs to be somewhere that
rewards approaching it well, not merely early.

**How I will play Red.** Straight. No tricks in the first battle, because a
baseline contaminated by me doing something clever is not a baseline. Vare's
commander has not met this army before and has no reason to be careful.

## Outcome

**Blue held the crossing. Round 7 of 22.**

A rout, not a grind. Red lost seven of nine formations; only the two Heavy
Infantry anchors (Vare First, Vare Second) never engaged. Blue lost three —
Kestrel, Ferrant, Ash — all speed: the light archer and both cavalry.

The shape of it: Ferrant (Medium Cavalry) fought four separate melees in one
battle — lost the first to Reeve, came back and won the rematch, beat
Toll-taker, beat Tally, then died in a three-way clash where Toll-taker
finally broke both her and Marrow. Two rounds later Thistle killed that same
Toll-taker and beat Scrip in the same round, the two hardest fights of the
battle back to back. Harrow's archery accounted for two kills on its own —
a chip shot on Whistle, then a clean kill on Coin. Oakhand and Gatewright
settled it with a straight fight, one on one.

Full account: `campaign/roster.json` → `fallen` and each survivor's `history`.

## Debrief

_To be written together — Lucas played this one against the bot rather than
me, which changes what it can tell us. Worth talking through:_

- The result was fast and lopsided (round 7, 7-of-9 losses on one side) against
  a mirrored army. Is that the matchup, the bot, or the objective rewarding a
  particular kind of aggression once real fighting starts?
- Ferrant's four-melee run and Thistle's revenge kill are the most interesting
  things that happened. Did committing cavalry hard into repeated fights feel
  like a real decision at the time, or did the toggle (cavalry always
  repositions) make that choice cheaper than it should have been?
- Nine a side, predicted borderline-too-many going in — with the bot playing
  Red, was tracking nine formations actually the friction, or did it not come
  up because the bot moves fast and doesn't need reading?
- Whether this counts as the honest baseline reading I wanted, or whether Vare
  needs a rematch with an actual commander before the campaign trusts this
  result.
