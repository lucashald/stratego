# Campaign design log

The campaign is also an experiment: which battles are actually fun to play, and
why. Every scenario is archived under `battles/` exactly as it was played, with
its replay under `replays/`, and every battle gets a debrief.

The point of writing intent **before** the battle is that it stops the debrief
from being a story about why whatever happened was what I meant. If a battle is
dull in the way I predicted, that is a finding. If it is dull in a way I did not
predict, that is a better one.

## How a battle is recorded

| File | What it holds |
|---|---|
| `battles/NN_name.json` | the scenario as played, never edited afterwards |
| `battles/NN_name.md` | intent written before, outcome and debrief written after |
| `replays/NN_name.json` | the engine's own replay, exact dice included |

`current_battle.json` is a copy of whichever battle is live, because the
CAMPAIGN BATTLE button reads that fixed path.

## Questions the campaign is trying to answer

These are the ones worth holding across battles rather than judging one at a
time. A single battle can be fun for reasons that do not generalise.

1. **Does the objective create decisions, or just a destination?** Hold-the-centre
   asks a real question of when to commit. Destroy-the-army may only ask you to
   walk forward.
2. **Is the outcome ever genuinely in doubt?** A battle whose result is settled
   by round three is a cutscene with extra clicking.
3. **Which formations feel worth having?** Heavy Cavalry has historically
   arrived too late to matter. Watch whether the campaign's smaller armies
   change that.
4. **Does size change the character of a fight?** Nine a side against four a
   side is not the same game scaled down; it may be a better one.
5. **Do asymmetric objectives play better than mirrored ones?** A withdrawal
   against a pursuit gives the two sides different questions.
6. **Does permanence change how you play?** Losing a formation for good should
   make committing it feel different from committing a replaceable one.
7. **What length is right?** Watch the round the result stopped being uncertain,
   not the round the game ended.

## Findings so far

**Hold-the-centre creates a real decision, not just a destination.** Winning
by objective requires arriving *early*, not just eventually — an earlier test
of this same map went well on casualties but still lost on the objective
clock. Question 1 from the list above: answered, at least for this shape of
map. (Battle 1)

**Heavy Infantry needs a battle shaped for it.** Two squares of approach to
the objective meant Oakhand and Stonewatch never reached the fight in time to
matter, not because anything is wrong with them, but because nothing asked
them to be fast. They want a long battle, or a defensive one where the
objective comes to them. Bears on question 3. (Battle 1)

**A lopsided score in a mirrored matchup isn't automatically a balance
signal.** Battle 1 was replayed several times against the bot before the
recorded result, so "round 7, 7-of-9 losses" may be a skilled commander
against a fixed opponent rather than the matchup itself. Worth a genuine
single-shot rematch, commander against commander, before trusting a score
like that again.

**Permanent loss produces a real ruling, not just a stat change.** The first
formation death (Ferrant, Battle 1) needed an actual decision about what
"destroyed" means for the story, not just the roster. Ruled: the formation
is gone for good, no exceptions, but a destroyed unit's death toll isn't
automatically total — survivors can persist as a narrative thread even when
the formation itself never returns. Bears on question 6, and is now the
standing precedent for every future loss.
