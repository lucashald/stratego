# Battle 4 — Cassewick

Scenario: `battles/04_cassewick.json` · Replay: _pending_

First battle of the Halgate campaign ("The Red Tide"), and the first under the new
company system: Halgate committed one company to this fight and kept the rest, so
whatever happens here, the faction survives it.

## The deployment choice (turn 1)

Intelligence in `dispatch_01.md`: Vare's fast vanguard — no heavies — riding to
seize the Cassewick granaries before Halgate could. The commander sent the
**Charter Company** (the speed counter to a raid) and hired a **Medium Archer,
Vellum**, from the reserve (8 crowns; treasury 15 → 7).

Deployed force (six formations, and crucially **two bows** to Vare's one):
Argent (MC 7), Errant (LC 6), Ferrule (LI 6), Ingot (LI 5), Quill (LA 5),
Vellum (MA 6). Against Escheat (MC 7), Warrant (LC 6), Distress (LI 6), Summons
(LI 6), Quarrel (LA 5).

## Intent, written before play

**What it is.** A race for a town. Both forces are fast; the granary yard at the
centre is the prize, held for three consecutive rounds to win. Vare starts a step
closer — they crossed ahead — so Halgate is not racing from even, it is racing
from behind, and the reason it can race at all is that it sent horse to answer
horse. The stone warehouses (impassable, at the yard's four diagonals) make the
centre a defensible knot approached down four lanes, so taking it and holding it
is a real fight, not a footrace to an empty square.

**Why this shape.** It is the counter-battle to the choice the commander made. A
raid's whole advantage is arriving first; the answer to it is a force that can
arrive at all, which is why the Charter Company and not the Gate Guard. The
scenario is built to reward that read — and to punish it if the town is stormed
carelessly, because Vare's vanguard is only a little weaker, not harmless.

**Where the hired bow earns out.** Two archers into a defended yard is the lever.
A single bow (Ashmere's problem, twice) can chip; two can clear a holder off the
square and cover the formations moving up to take it. The MA was hired precisely
for this, and whether it reads as worth eight crowns is part of what the battle
answers.

**What I am testing.**
- Whether the new company/economy system produces a battle that feels
  well-matched because the commander prepared it well — the reward loop working.
- Whether a hold-the-town race is a real decision against terrain, or collapses
  into a mid-field scrum that ignores the objective.
- Whether two bows meaningfully change how a defended point is taken.

**The honest caveat about the opponent.** This was verified bot-vs-bot, and the
bot cannot defend a position — it abandons the yard to attack and dies for it. So
the objective bites far harder for a human Red than for the bot, and this battle,
played against the bot, favours Halgate more than the numbers alone suggest.
Difficulty in this campaign will come from tougher strikes and from me commanding
Red, not from pretending the bot is a defender it isn't.

## Verification

Run bot-vs-bot, 60 games (the Fen Road rule — no unverified scenario ships again):
**Blue (Halgate) 47, Vare 13, avg 5.2 rounds, 15 of 60 decided by holding the
yard.** Winnable and then some, with the objective genuinely in play and Vare
taking roughly one in five off the bot — a real contest, the opposite of the Fen
Road. A human commanding the Charter Company should win, but can lose formations
doing it, and can lose the battle by mishandling the town.

## Outcome

**Vare won. Round 4, held the granary.** A successful raid, and a ruinous one for
them: Vare kept **one** formation of five. Halgate kept three of six — and still
lost, because the battle was never about the body count.

Blue's dead (3 of 6): **Argent** (MC), **Ferrule** (LI), **Ingot** (LI).
Blue's survivors: **Errant** (LC, down to 1), **Quill** (LA, 5), **Vellum** (MA, 6).
Vare's dead (4 of 5): Escheat, Warrant, Summons, Quarrel.
Vare's survivor: **Distress** (LI, down to 2) — the lone raider that seized the
yard on a reposition and held it to the end.

The shape of it: Halgate won nearly every exchange. Errant killed Warrant; Vellum
shot Summons off the board; Ferrule and Quarrel destroyed each other; Argent
killed Escheat, the enemy's heavy lance — and was then cut down by Distress, the
cheapest thing Vare had. While Halgate was winning that fight, it never controlled
the granary square for three clean rounds, and Vare did, slipping a holder onto it
during the reposition phase and clinging on with its last unit. Casualties: a
Halgate win. Objective: a Vare win. The objective is the one that counts.

## Debrief

**"Won the fight, lost the yard" — the exact thing hold-the-centre tests, this
time as a real human loss.** The Toll Road's design note warned that you can go
well on casualties and still lose on the objective clock. Cassewick delivered it:
the commander was "doing well," took the better of the fighting, and lost at the
last second to a single unit holding the square. Question 1 (does the objective
create a decision?) and question 2 (is the outcome ever in doubt?): both answered
yes, decisively, and by a played game rather than a bot run. This is the battle
the campaign has been trying to produce since Battle 1.

**The reposition-phase seize is a real, teachable tactic.** The hold streak is
checked at the end of the round, *after* leftover/reposition moves. Clearing the
yard in the main phase is not holding it — a fast unit can step onto the square in
the reposition phase and take the round. Holding the centre means holding it
through the leftover phase, and defending it means watching that phase, not just
the main one. Bears on how every future hold objective should be read.

**The system worked.** Halgate lost a battle and is not wiped. Only the Charter
Company was on the field; the Gate Guard is untouched at the city; the treasury is
intact and earning. Three formations came home. This is the whole point of the
company structure, and its first real test passed: a defeat is a setback the
faction absorbs, not an extinction. Contrast Blue, for whom this same casualty
ratio would have been the end.

## Design log entries this earns

Promoted to `design_log.md`:
- Hold-the-centre can be lost on the objective while won on casualties — now
  proven in a played human game, not just a design note.
- The objective is checked after the reposition phase; a late leftover move can
  steal a round. Holding means holding through leftover, not just main.
- The company/treasury structure did its job: a lost battle cost a company blood,
  not the faction. The fix for Blue's fatal flaw is validated.
