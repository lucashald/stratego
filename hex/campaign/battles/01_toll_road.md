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

**Not a single clean playthrough.** Lucas replayed this several times against
the bot while testing things, so the recorded result carries an advantage a
one-shot baseline wouldn't have. Worth remembering when weighing how decisive
"round 7, 7-of-9" actually is as a read on the matchup.

**The map has a real timing requirement, separate from the rout.** Winning by
objective here means arriving at the crossing *fast* — an earlier test battle
went well on casualties but still lost on the objective clock. That's the map
doing real work: hold-the-centre isn't just "walk to the middle," it's "get
there before the window closes," which is a genuine decision the intent
doc hoped for and got. Lucas's read on the lopsided casualty count itself,
though, is that it came from outplaying the bot in this specific game, not
from the scenario forcing it. Fair, and consistent with playing it more than
once — an opponent this refined only shows up with practice.

**Two squares of approach starved the heavies of time, not of purpose.**
Oakhand and Stonewatch could not reach the fight fast enough to matter here.
That's not a case for reworking Heavy Infantry — it's a case for not asking
them to sprint. They want a longer battle, or one where the objective comes to
them instead of the other way around. Design note for what comes next.

**Verdict on the baseline:** keep it. It answered its question — the objective
creates a real decision — even if the specific score isn't a clean read on
"commander vs. commander." That question gets its real test the next time I'm
actually seated across the board, not by discarding this fight.

## Design log entries this earns

Promoted to `design_log.md`:
- Hold-the-centre works: it demands early arrival, not just eventual
  presence, which is a real decision rather than a walk.
- Heavy Infantry needs a battle shaped for it — long, or defending — not a
  race. Confirmed by design intent, not merely observed once.
- Casualty asymmetry in a mirrored matchup can come from play skill, not
  scenario bias. Worth a genuine rematch before trusting the score as a
  balance signal.

## Ferrant

*Ruling, since the campaign asked for one: a destroyed formation's death
toll isn't automatically total.*

Ferrant fought four engagements in one battle and only broke on the fourth,
caught between two enemies at once rather than beaten clean. That's not an
annihilation. The formation — the standard, the drilled cohesion that let her
beat Reeve twice and Toll-taker and Tally in a single afternoon — is finished
regardless. It doesn't reform, and nothing restores it to the active roster.
That rule stays absolute, because it's the rule that makes losses mean
something.

But some of her riders made it off that field. Not enough to hold the
Ferrant name, or fight as Ferrant fought — but enough that Ashmere's next
levy of horse will have a few veterans in it who know which end of a lance
to hold, and who remember exactly how it ended. `roster.json`'s fallen entry
reflects that. Whatever unit picks up that thread later in the campaign
inherits nothing mechanical — no bonus, no reroll — just the fact that it
isn't starting from nothing.
