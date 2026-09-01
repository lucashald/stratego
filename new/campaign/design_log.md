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

**Battle 1 played, debrief pending.** Blue held the crossing at round 7 of 22,
losing 3 of 9 formations against Red's 7 of 9 — fast and lopsided for a
mirrored army. Played against the bot rather than me, since I hit a usage
limit mid-battle, so it isn't yet the clean commander-vs-commander baseline
the battle was meant to be. Full outcome in `battles/01_toll_road.md`; nothing
gets promoted from there to here until we've actually talked about it.
