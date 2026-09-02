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

**Hold-out windows must close near when the result settles, not a dozen rounds
later.** Ashweir Bridge ran 28 rounds; the crossing had broken and the outcome
was decided by roughly round 18. The last ten rounds were a won battle still
being made to play itself out, with two enemy survivors that couldn't force
anything declining to fight. A `survive` objective's turn limit is the whole
lever on how a defensive battle *feels*, and this one was set far too long. Next
defensive battle: materially shorter window. Answers question 7 more bluntly
than Battle 1 — set the clock by when doubt ends, not by generosity. (Battle 2)

**The bot cannot fight a multi-lane chokepoint.** Two failures at Ashweir, both
the opponent AI's: it fed only one of the bridge's two lanes and left the second
idle, collapsing a "two-wide" decision into "one-wide with a spare"; and when the
direct push jammed it kept pushing the same square instead of manoeuvring around.
`bot_policy.gd` has no notion of splitting an assault across parallel approaches
or switching lanes when one stalls. Fix before another chokepoint scenario is
trusted — until then, a human commanding the attacker is the only fair test of a
chokepoint. (Battle 2)

**In a chokepoint, ranged fire into the gap outvalues bodies in the gap.** The
intent doc built Ashweir to make Heavy Infantry matter and worried the bottleneck
would swallow the game. It half-did: the bottleneck was the game, but the
deciding pieces were the two archers firing into it, not the Heavy plug standing
in it. The recruitment trade — a second bow taken over the last cavalry slot — is
the direct, traceable cause of the win. Bears on question 3: what a formation is
worth depends on the battle's shape, and a chokepoint is an archer's battle.
(Battle 2)

**A pyrrhic win is a valid outcome that branches the campaign, not a balance
bug.** Blue won Ashweir down to its last formation. That's a genuinely different
result from a clean win, and it triggers the rules' own "decisive result leads to
a different *kind* of battle" branch: Blue can't field an army, so Battle 3 has to
be a rebuild scenario, not a rematch. Outnumbered-behind-terrain is *supposed* to
risk exactly this. Bears on question 5 and 6 — asymmetry and permanence together
produced a story branch neither would alone. (Battle 2)

**The promised veteran reroll is now a written rule.** Outstanding since Battle 1,
finally defined in `roster.json` → `rules.veteran_reroll` and awarded to Stonewatch
for holding the bridge alone: one reroll per battle, GM-applied, no engine support
yet. Engine hook remains a separate task. (Battle 2)

**Verify a scenario is winnable before handing it over.** The Fen Road (Battle 3)
shipped without a bot-vs-bot check and turned out to be unwinnable — Blue's two
formations were destroyed in three rounds. Ashweir was verified before play and
was fair; the Fen Road was not verified and was not. Non-negotiable from here:
every scenario gets at least one bot-vs-bot resolution before a human plays it,
and a scenario whose fairness depends on a commanded opponent gets extra scrutiny,
not less. (Battle 3)

**A withdrawal needs standoff distance and a real chokepoint, or it is just a
footrace the slow side loses.** With Heavy Infantry at 1 square/round and cavalry
at 3–4, a pursuit in the open always catches the anchor. The Fen Road gave Blue
neither a head start nor terrain that forced the pursuit to engage one at a time,
so four fast formations swarmed two. The withdrawal/pursuit objective pair is
still effectively untested, because the one attempt was broken. (Battle 3)

**Combat roles, recorded because I got them backwards:** attacking Cavalry gets
+3 (charge); defending Infantry gets +3 (brace); defending Cavalry gets +3;
attacking Infantry gets +0. So charge and brace cancel in Cavalry-attacks-Infantry
— Heavy Infantry wins most 1-on-1 *defences* on Strength, and its real weakness is
being attacked by several formations in one round, not any single matchup.
Infantry should defend, never attack cavalry. (Battle 3)

**A won battle must fund a viable rebuild.** The rebuild after Ashweir Bridge — a
victory — allowed one Strength-4 Medium Cavalry, which put two formations on the
Fen Road against four. A campaign that leaves the winner unable to field a real
force is punishing victory, and it cascaded directly into an unwinnable battle.
Supply from a battle must scale to the outcome and the losses so a costly win
still fields an army. This is now a standing rule (`roster.json` →
`rules.recruitment_economy`). (Battle 3)

## The turning point

Battles 1–3 are the fall of the Ashmere Line: it won at the Toll Road, won at
Ashweir Bridge at ruinous cost, and was annihilated on the Fen Road. Permanent
death was honoured all the way to an empty roster — Blue is gone, not rebuilt. The
campaign continues as the wider war against Vare, taken up by a new power. The
open question the Line leaves behind is the spine of what follows: a frontier
could *beat* Vare and still lose to arithmetic — can anyone actually stop them?

## The Red Tide begins (Halgate)

**Hold-the-centre, lost on the objective while won on casualties — delivered in a
played human game at last.** Cassewick (Battle 4): Halgate killed 4 of 5 and kept
3 of 6, and lost, because Vare held the granary the three rounds that decide a
hold and Halgate never did. The commander was "doing well" and lost at the last
second to a single Strength-2 unit on the square. This is the outcome hold-the-
centre was built to make possible and the campaign had not yet produced against a
human. Questions 1 and 2: answered yes, together, in one battle. (Battle 4)

**The objective resolves after the reposition/leftover phase.** A late leftover
move can step onto the square and take the round; clearing it in the main phase is
not holding it. Defending a hold objective means watching the leftover phase, not
just the main one. This is how Cassewick was won and lost. (Battle 4)

**The company/treasury structure passed its first test.** Halgate lost a battle
and absorbed it: one company bled, the other untouched, the treasury earning. The
same casualty ratio would have ended Blue. The fix for Blue's fatal flaw — a
faction that is more than one army — works as designed. (Battle 4)

**Verify-before-handover works, and correctly could not predict the loss.** The
bot-vs-bot check (Halgate 47/13) confirmed the scenario was winnable and fair; it
could not foresee a human losing it on the objective, because the bot can't
defend a point. That's the right division of labour: verification rules out
impossible/broken, not "hard." (Battle 4)

**A static ranged defence is near-unloseable for a human against this bot.** The
Weirgate (Battle 5): three bows on a defended causeway destroyed Vare's whole
heavy host for one loss, round 11. Verification said 60/40 to the defender; the
human turned it into a wipe because the bot attacks piecemeal and passively and
defends worse than a person. Verification bounds "winnable," not "hard." Real
difficulty against this bot comes only from an objective the bot can win by
passively occupying under a clock (Cassewick), or from a commanded Red. Static
defence behind bows is a solved problem. (Battle 5)

**Pacing note.** Ashmere's arc was tragedy (win, win, wipe). Halgate's is turning
into a proper campaign shape: absorb a loss it survives (Cassewick), then a
decisive win that closes the oldest enemy thread (the Weirgate, Bulwark dead). The
company/treasury structure is what makes that rhythm possible — losses and wins
both leave a faction still standing. (Battles 4–5)
