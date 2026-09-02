# Battle 6 — Cassewick Again

Scenario: `battles/06_cassewick_again.json` · Replay: _pending_

Turn 3. The first battle of the campaign where Halgate is the attacker, and the
first built deliberately to be *hard*.

## The deployment choice (turn 3)

Intelligence in `dispatch_03.md`: with Vare's host broken, Halgate counterattacks
to retake Cassewick before a relief column reaches it. The commander sent the
**Charter Company**, rebuilt: reinforced **Errant** (1 → 6) and hired a Medium
Archer, **Ledger**. Treasury 13 → 0 (Errant 5, Ledger 8) — the whole chest.

Deployed force (four fast formations, three of them bows): Errant (LC 6, Veteran),
Quill (LA 5), Vellum (MA 6), Ledger (MA 6). Against a thin garrison — Distress
(LI 2), Cess (LI 5) — and a three-formation relief column: Writ (MC 7), Chattel
(LC 6), Forfeit (LI 6).

## Intent, written before play

**What it is.** A race to retake and hold the granary yard. Halgate must take the
town off the garrison and hold it three rounds while a Vare relief column rides to
break the hold. Halgate is outnumbered five formations to four and is the one
attacking — the harder posture, and the point.

**Why this is built hard, and how.** The commander asked me to make the bot a real
opponent. The honest fix was not to rewrite the AI but to hand it the one thing it
does well. The bot is a poor attacker — it feeds a defended point piecemeal, which
is why the Weirgate was a shooting gallery. But it *defends an objective*
competently: it was the bot holding the Cassewick yard that beat the commander in
Battle 4. So this scenario puts Halgate on offence against the bot defending, with
a relief clock, which is the matchup where the bot is genuinely dangerous and the
human's skill is tested rather than a passive opponent's absence exploited.

**The trap in the force.** The Charter Company is fast and has three bows, which
is exactly right for shooting a thin garrison off a square — and exactly wrong for
a melee once the relief's heavier horse and foot arrive. The whole battle is a
timing problem: shoot the garrison off the yard, establish the hold, and be gone
or dug in before Writ's lance and Forfeit's foot turn it into a brawl three
archers lose. Take too long and the relief catches a company that cannot slug.

**What I am testing.**
- Whether Halgate on offence plays as a genuinely harder, different problem than
  its two defences.
- Whether a mobile gunline can win a seize-and-hold, or whether archers are the
  wrong tool the moment the objective forces you to *stay*.
- Whether the relief clock makes the objective bite the way Cassewick's did, from
  the attacker's side this time.

## Verification

Run bot-vs-bot, 60 games (the Fen Road rule): **Blue (Halgate) 18, Vare 42, avg
4.3 rounds** — deliberately tuned to the hard end. An earlier cut with the garrison
sitting on the yard was 12% and near-unwinnable; pulling the garrison off the
square and trimming the relief put it at ~30% for the *bot* attacker. Since a human
attacks far better than the passive bot, that should net a genuinely hard but
winnable offensive — the challenge the commander asked for, with a real chance of
losing the company's whole rebuild if it goes wrong. Treasury is at 0, so this one
is played without a net.

## Outcome

**Vare held Cassewick again. Round 4, held the yard.** The same shape as Battle 4
from the other side: Halgate won the fighting — killed Distress, Cess, and Writ
(the relief's lance) — and lost the town, because when the lance died there was
nothing left that could stand on the square. Forfeit (LI) held the yard to the
end. Blue lost Errant and Quill; Vellum and Ledger (the two rear bows) walked off.

Blue's dead (2 of 4): Errant (LC), Quill (LA). Survivors: Vellum (MA 6), Ledger
(MA 6). Vare's dead: Distress, Cess, Writ. Vare survivors: Chattel (LC 2),
Forfeit (LI 6).

## Debrief

**The force trap closed exactly as the intent doc warned.** Three bows and one
lance is a company that wins every exchange and holds nothing. Errant died and the
Charter Company had no body left to put on the objective, so the archers shot a
held yard they could not take. Halgate has now lost two seize-and-hold battles the
same way — you cannot hold ground with archers, and the campaign has proven it
twice. The Charter Company is spent as an offensive force: two Medium Archers left.

**The round-1 collision, answered (it is working as designed).** Errant advanced
onto the objective (10,9) and met Distress there, which had come out of fog, and
Distress fought as the defender. Why: movement resolves in three impulses, and a
formation moves one step per impulse. Distress started two squares from the yard
and arrived on impulse 2; Errant started three squares away and arrived on impulse
3. So Distress was standing on the square when Errant moved in — the stationary
occupant is the defender. It did *not* cost the fight, though: Errant's cavalry
charge (+3) and Distress's infantry brace (+3) cancel exactly, so it was a straight
Strength-and-dice contest Errant (6) should have won against Distress (2). It
didn't because Errant rolled a 2 and the scores tied (5-5) into a bounce — bad
luck, not the bonus. The fog was legitimate: Distress was five squares away at
planning, past the vision range of four, so it was invisible when the order was
given. WeGo commits both sides blind to hidden movers; that is the game, but it
can feel like an ambush.

**A real scenario miss: the relief clock didn't read.** The relief column started
only ~5 rows back and, being fast, arrived almost on the garrison's heels — Writ
killed Errant in the first round's leftover phase. So there was no visible window
of "fight the garrison, then the relief hits," which was the whole intended
texture. If a relief/clock scenario is run again, the relief must start far enough
back that its arrival is a distinct, felt beat, not a second wave one round later.

## Design log entries this earns

Promoted to `design_log.md`:
- An archer-heavy company cannot win a seize-and-hold: it takes every fight and
  holds no ground. Proven twice (Battles 4 and 6). Offensive objectives need a
  body that can stand on the square.
- Movement resolves per-impulse (one step each), so the closer formation reaches a
  contested square first and defends it; charge and brace cancel in cav-vs-inf, so
  the collision is decided by Strength and dice, not the bonus. (Rules clarity.)
- A relief/clock must start far enough back to read as a distinct arrival, or the
  clock texture is lost and it plays as one massed force.
