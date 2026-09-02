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
