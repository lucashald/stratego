# Battle 2 — Ashweir Bridge

Scenario: `battles/02_ashweir_bridge.json` · Replay: `replays/02_ashweir_bridge.json`

## Intent, written before play

**What it is.** Vare does not fold after the Toll Road. Word of the rout
reaches their garrison at Ashweir, and rather than send another toll company
they call up a real muster — a heavier, larger force, and a commander who has
heard exactly how the last one died. Blue holds the near bank of the river at
Ashweir Bridge. Vare has to force the crossing to reach Ashmere at all.

**Why this shape, specifically.** Two findings from Battle 1 point straight
here.

First: two squares of approach starved Oakhand and Stonewatch of the time
they needed to matter. A bridge is the opposite problem on purpose — Blue
doesn't go anywhere. The heavies plant themselves at the bridgehead and the
fight comes to them, which is exactly the "defending something" case the
debrief said they needed.

Second: `hold_square` has now been played once, and `reach`/`survive` — the
attacker/defender pair — never have, despite being built and ready since the
scenario loader shipped. This is that pair's first real outing: Vare needs to
get enough Strength across the river into Blue's territory to count as a
breakthrough; Blue only has to still be standing at the bridgehead when the
turn limit runs out. Neither side is racing a clock toward the same square,
which is a genuinely different question from Battle 1's.

**The terrain is the whole design.** A river band with a single two-wide
bridge is a chokepoint that punishes exactly what made Vare dangerous at the
Toll Road — numbers and speed — and rewards exactly what Blue has left after
it: two Heavy Infantry who don't need to be anywhere else, and an archer who
can shoot into a bottleneck all day. Vare has to feed formations into a
two-wide gap one exchange at a time. That is a defender's fight.

**Why Vare is bigger this time.** A decisive win should have consequences
beyond the battlefield it was won on. Vare escalates because losing badly to
a smaller force is the kind of thing a garrison commander answers for, and
because Blue winning easily once is not a reason for the campaign to keep
being easy. Expect more Heavy Infantry and Heavy Archer in Vare's muster than
the mirrored Toll Road force had, and fewer of the fast skirmish types that
got picked apart trying to force an open field.

**What I am testing.**

- Whether a chokepoint actually makes the heavies matter, or whether the
  bottleneck itself becomes the whole game and nothing else does.
- Whether `survive` reads as a real objective to defend, or just as "outlast
  the turn limit," which is a duller thing to ask a player to do.
- Whether being outnumbered behind good terrain feels fair or just feels
  outnumbered. Vare's muster is meant to be a real threat, not a formality.

**What I expect to go wrong.** A single two-wide gap risks becoming a meat
grinder that both sides feed formations into without much decision-making
beyond "who's next." If it plays that way, the fix is probably a second,
worse crossing point Vare can also try — a ford upstream that's passable but
costs more to use — so defending becomes about where to commit, not just
whether to.

**How I will play Vare.** Not straight this time. Vare's commander has now
watched the Toll Road happen and gets to have learned something from it —
probing before committing the main body, feeding the bottleneck in a
considered order rather than however the roster happens to be listed. Still
not adversarial toward the player personally, but no longer naive.

## The recruitment choice

**Light Archer, chosen.** Wren joins the roster — the archer the fight in
front of Blue actually rewards, at the cost of leaving cavalry as the one
piece the roster still doesn't have. That's a deliberate trade for this
battle over the long run of the campaign, and worth watching whether it
reads as a mistake once Blue needs to reach somewhere fast again rather than
hold in place.

## The battle

Full roster deployed, terrain built, played once bot-vs-bot before being
handed over to confirm it actually resolves rather than deadlocking or
breaking: Vare forced the crossing at round 14 of a 28-round window, losing
4 of 11 formations to do it and leaving Blue at 5 of 7. Neither a curbstomp
nor a stalemate — a real fight either side could plausibly have won,
which is what a fair chokepoint battle should look like before a human sits
down to either side of it.

## Outcome

**Blue held the bridge. Round 28 of 28 — the full window ran out.** Winner:
Blue, by `survive`. Vare never got 18 Strength across the water; the crossing
objective was never close.

It is a win the way a field surgeon calls an operation a success. Blue went
into Ashweir with seven formations and walked away with **one**. Vare came with
eleven and kept **two**, one of them limping. Nineteen formations stood on the
field at first light; three were standing at the end.

**Blue's dead (6 of 7):** Oakhand, Marrow, Thistle, Coldbrook, Harrow, Wren.
**Blue's survivor:** Stonewatch (HI, Strength 8), without a wound.

**Vare's dead (9 of 11):** Vare First, Vare Second, Siegewright, Warden,
Bailiff, Tithe, Levy, Picket, Fletch. **Vare's survivors:** Bulwark (HI 8,
never engaged) and Outrider (LI, down to 3).

The shape of it: **the two archers won the bridge and paid for it with their
lives.** Wren — the recruit chosen over cavalry precisely for this fight —
killed Tithe, Warden, and Bailiff and chipped Vare First and Siegewright before
Siegewright's return shot killed her outright. Harrow killed Fletch, both Vare
Heavies, shared Bailiff, and finished Siegewright, then was ridden down in the
last melee of the battle by Outrider. Between them the two archers accounted for
essentially every Vare formation that died. Stonewatch threw Picket off the
bridge in the one crossing fight she was given and then simply outlived the
whole battle at the bridgehead, untouched. Oakhand and Levy destroyed each other
in a bounce. Coldbrook was cut down by Siegewright at the bridge mouth.

The archer gamble from the recruitment choice is the finding of the battle:
trading the last cavalry slot for a second bow is the direct cause of the win.
Two bows into a two-wide gap is a kill rate the gap could not survive.

## Debrief

Lucas's read, and mine.

**The turn limit was too long, and it changed the character of the win.**
28 rounds against a superior force was only ever going to end in a loss or in
catastrophic casualties — and it delivered the catastrophe. The actual fight was
decided somewhere around round 18; Vare's crossing had already broken and its
two survivors had nothing left to force. Rounds 19–28 were dead air, a won
battle still being made to play itself out. **A hold-out objective should end
near the round the outcome stops being in doubt, not a dozen rounds later.** For
the next defensive battle, the window wants to be materially shorter — long
enough that holding is hard, short enough that the tail isn't spent watching two
survivors decline to fight. This is the sharpest single lesson so far. (Bears on
question 7, and answers it more bluntly than Battle 1 did: watch the round the
result settled, not the round the clock stopped.)

**The bot cannot fight a two-wide chokepoint.** Two concrete failures, both the
bot's, both worth fixing before a chokepoint battle is trusted again:

1. *It never used the second lane.* The bridge is two squares wide by design —
   the whole point was a defender's decision about *where* to commit. The bot
   fed one column and left the other lane idle, so the "two-wide" was really
   "one-wide with a spare." It has no notion of splitting an assault across
   parallel approaches, or of switching lanes when the first stalls.
2. *It doesn't go around.* When the direct push jammed, it kept pushing the same
   square instead of manoeuvring. There was no flank in it.

**The late-game passivity was partly correct and partly not.** Lucas noticed
Vare refused to attack his infantry for the last several turns and wondered if
that was smart. Half of it was: the survivors were Bulwark (HI 8) and Outrider
(LI, at 3). Outrider throwing itself at Stonewatch (HI 8) is suicide and
declining it is the right call. Bulwark (HI 8) vs Stonewatch (HI 8) is a coin
flip with nothing behind it — a commander might hold too, with no support and a
survive-clock that's already lost. So the *inaction* reads as defensible. What
doesn't read as defensible is everything that led there: had the bot used both
lanes and manoeuvred, it wouldn't have arrived at the endgame with two
formations and no plan.

**A chokepoint does make the heavies matter — but archery mattered more.** The
intent doc worried the bottleneck would become the whole game and nothing else
would. Half-right: the bottleneck *was* the game, but the deciding piece in it
wasn't the Heavy Infantry plug, it was the two bows firing into the plugged gap.
Stonewatch's contribution was one crossing fight and then survival. That's not a
knock on the design — it's the archer-trade finding again from the other side:
in a chokepoint, ranged into the choke is worth more than bodies in it.

**Pyrrhic victory is a legitimate campaign outcome, and this one earns its
narrative.** Winning down to your last formation is a *different* result than
winning clean, and the campaign rules already anticipated it: a decisive
result — even a winning one — leads to a different *kind* of battle next, never
a straight rematch. Blue cannot field an army now. That's not a failure of the
scenario; it's the scenario doing exactly what "outnumbered behind good terrain"
should risk. What comes next has to be a rebuild, not Battle 3-of-the-same.

## Design log entries this earns

Promoted to `design_log.md`:
- Hold-out windows should close near when the result settles, not a dozen rounds
  later. 28 was far too long; the fight was over by ~18.
- The bot can't fight a multi-lane chokepoint: it uses one lane, never the
  second, and won't manoeuvre around a jam. Fix before trusting another
  chokepoint scenario.
- In a chokepoint, ranged fire into the gap outvalues bodies in the gap. The
  cavalry-for-archer recruitment trade is the direct cause of the win.
- A pyrrhic win is a valid outcome that forces a rebuild scenario, which is the
  intended "different kind of battle" branch, not a balance problem.
