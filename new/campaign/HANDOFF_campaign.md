# Handoff: the campaign ("The Ashmere Line")

Status as of 2026-09-01. Battles 1–3 are played and debriefed. The **Ashmere Line
is annihilated** — Battle 3 (The Fen Road) was an unwinnable scenario (design
failure, recorded honestly) that the commander ruled stands as a real defeat: no
do-over. Blue has **zero formations left**. The campaign does not rebuild Blue; it
continues as the wider war against Vare under a **new faction**, pending the
commander's choice of which. The in-world story is in `campaign/chronicle.md`
(chapters I–V close the Ashmere Line).

**New faction chosen: Yellow / Halgate**, a rich walled city. The campaign is now
"The Red Tide." Structure redesigned so a single lost battle can't wipe the
faction (Blue's fatal flaw): Halgate fields multiple **companies**, commits one
per battle, keeps the rest, and rebuilds from a treasury. Turn loop and rules are
in `system.md`; state (treasury, two companies, reserve, economy) in `roster.json`;
Blue's closed record preserved in `ashmere_line.json`.

**Battle 4 — Cassewick: played and LOST** (Vare held the granary, round 4). Halgate
won the fighting (killed 4 of 5, kept 3 of 6) and lost the objective — the
hold-the-centre outcome the campaign had been chasing since Battle 1, delivered
against a human. Outcome + debrief in `battles/04_cassewick.md`; replay at
`replays/04_cassewick.json`. Losses applied (Argent, Ferrule, Ingot struck to
`fallen`); survivors Errant (LC 1, now Veteran), Quill (LA 5), Vellum (MA 6);
income banked (treasury 7 → 15); Distress added as an enemy thread. The faction
absorbed the loss — the whole point of the company system, validated. Chronicle
chapter VI written.

**Battle 5 — The Weirgate: played and WON decisively** (held the causeway; Vare's
heavy host destroyed to the last, round 11; Halgate lost only Bastion). The
three-bow Gate Guard curb-stomped a passive bot assault. **Bulwark killed** — the
oldest enemy thread, closed (moved to `roster.json` → `closed_threads`). Outcome +
debrief in `battles/05_weirgate.md`; replay `replays/05_weirgate.json`. Bastion →
`fallen`; Sable now Veteran; income banked (5 → 13); chronicle chapter VII written.
Finding logged: static ranged defence is near-unloseable for a human vs this bot;
verification bounds "winnable," not "hard."

**Battle 6 — Cassewick Again: played and LOST** (Vare held the yard, round 4). Same
shape as Battle 4: Halgate won the fighting (killed Distress, Cess, Writ), lost the
town — an archer-heavy company holds no ground once its lance dies. Errant + Quill
fell; Charter Company is now two MAs (Vellum, Ledger). Outcome/debrief in
`battles/06_cassewick_again.md` (includes the answer to the commander's rules
question — per-impulse movement decides who defends a contested square; charge and
brace cancel; fog+simultaneous planning); replay `replays/06_cassewick_again.json`.
Income banked (0 → 8); chronicle ch. VIII; findings in `design_log.md`.

**Turn 4 is live — `dispatch_04.md`, a strategic decision (no battle built).** The
war's shape is now clear: Halgate can defend (Weirgate) but cannot take ground
(Cassewick ×2) with archer-heavy companies that can't hold. Three directions
offered: (A) consolidate/bank income and build a combined-arms strike force; (B)
send the Gate Guard to take Cassewick as a *grind* (a no-relief-clock assault where
slow doesn't lose); (C) stay defensive and win the next Weirgate. Claude-as-Red
still on offer. Await the commander's direction, then build + verify.

---

**Superseded (Battle 6, now played):**
Commander rebuilt and sent the **Charter Company** (reinforced Errant 1→6, hired
Ledger MA; treasury 13 → 0), and chose to **play the bot** but asked me to make it
a real opponent. Files `battles/06_cassewick_again.{json,md}`, loaded to
`current_battle.json`. Halgate on **offence**: retake and hold the granary yard
(`hold` [10,9], 3 rounds, 14-round limit) off a thin garrison (Distress LI 2, Cess
LI 5) before a relief column (Writ MC 7, Chattel LC 6, Forfeit LI 6) breaks it.
**Verified bot-vs-bot: Halgate 18 / Vare 42** — deliberately tuned to the hard end
(a garrison-on-the-yard cut was 12%/near-unwinnable; pulling it off the square and
trimming the relief landed ~30% for the bot attacker → hard-but-winnable for a
human). Treasury 0 = no net if it's lost.

**Bot-difficulty decision (re the commander's "adjust it as you see fit"):** did
NOT modify `bot_policy.gd`. The bot defends a `hold` objective competently (it beat
the human that way in Battle 4) and only attacks passively; so the scenario puts
the human on offence against the bot defending, which is where the bot is actually
dangerous. Chose matchup design over a risky mid-campaign AI rewrite. If a future
turn wants the bot to *attack* well, that's the real `bot_policy.gd` work
(piecemeal-feeding / won't-commit), still unaddressed. Note: `objective_occupy`
(20.0) and `objective_progress` (5.0) weights already make it contest `hold`
squares — its gap is pressing an assault, not holding.

Verification harness note: throwaway-script method (crib `batch_runner.gd:_play_one`,
load via `CampaignScenario.apply`, tally `game.winner`). Run from **`C:\stratego\new`**
(not `C:\stratego`): `Godot_..._console.exe --headless --path . --script res://scripts/<tmp>.gd`.
Objective JSON kinds: `eliminate`/`hold`/`reach`/`survive` (`hold`, not `hold_square`).

Verification method (reusable): a throwaway `SceneTree` script loads the scenario
via `CampaignScenario.apply`, runs `StrategoBotPolicy` both sides through the
`plan_round`/`resolve_main_and_ranged`/`plan_leftover`/`resolve_leftover_phase`
loop (cribbed from `batch_runner.gd:_play_one`), and tallies `game.winner`. Run
with `Godot_..._console.exe --headless --path . --script res://scripts/<tmp>.gd`.
Objective JSON kinds are `eliminate` / `hold` / `reach` / `survive` (note: `hold`,
not `hold_square`).

## The premise

Claude GMs a persistent RPG/strategy campaign using the game engine. The user
commands Blue in the app; Claude commands the enemy over the MCP server. Claude
has full authority to invent new rules, scenarios, and features as the campaign
goes.

Rules the user set, verbatim in intent:

- **Permanent death is permanent**, and should be narrated so it feels real.
- **Survivors accumulate history**, and can earn a veteran advantage — the
  discussed one is *reroll one combat roll per battle*.
- Survivors **gain Strength between battles** when resting/recruiting.
- **Fresh recruits between battles, but the choice must cost something** —
  e.g. only affording one unit and picking between two options.
- **No individual battle should be totally one-sided.** A decisive defeat leads
  to a *different kind* of battle (a retreat scenario, a small skirmish because
  you can't field a full army), never an unwinnable rematch.
- **"Your only goal is to make it fun."**

Secondary standing goal: figure out which battles are actually fun to play. So
every scenario is archived, and **each one gets a real conversational debrief
after it concludes** — not written solo by Claude. That's what
`campaign/design_log.md` is for.

## Current state

`campaign/roster.json` is the source of truth. Aftermath after Battle 2, supply 3.

**Alive:** Stonewatch (HI, 8, unwounded, **Veteran**) — the sole survivor of
Ashweir Bridge and the entire remaining Ashmere Line.

**Fallen:** Kestrel (LA), Ferrant (MC), Ash (LC) at the Toll Road; then Harrow
(MA), Wren (LA), Oakhand (HI), Coldbrook (LI), Marrow (MI), Thistle (MI) at
Ashweir Bridge. The two archers (Harrow, Wren) did nearly all of Vare's killing
and both died for it; see `chronicle.md` and each `fallen` entry.

**Enemy threads (new):** Outrider (Vare LI, survived at Strength 3 having killed
Harrow) and Bulwark (Vare HI, never engaged, carried word home). Both live in
`roster.json` → `enemy_threads`.

File convention: a dead formation is *struck from* `formations` and moves to
`fallen`. It never lingers at Strength 0 in the live list.

### The Ferrant ruling

The user left this to Claude's judgment: does a destroyed formation mean every
soldier died? The ruling recorded in `roster.json` — some of Ferrant's riders
got off the field, but not enough to hold the name or fight as she fought. **The
formation does not return. The riders might turn up again.** That's a live
narrative thread, deliberately left open.

## Battle 1 — The Toll Road (played, won, debriefed)

Files: `campaign/battles/01_toll_road.json` + `.md`, replay at
`campaign/replays/01_toll_road.json`.

Blue won decisively. Three formations lost.

**The user's own debrief, which matters more than my read of it:**

- She'd replayed it a few times against the bot while testing, so she had an
  advantage going in.
- The scenario requires getting to the objective *fast* to win — that's real
  design, not a flaw.
- The rout was mostly her outplaying the bot, **not** scenario bias. (In an
  earlier test she did well on casualties but still lost on the objective.)
- Only two squares of approach made it hard to get heavies into position.
- **Heavies weren't broken** — they just couldn't reach the objective in time.
  They need longer battles or something to defend, not a race.
- Verdict: "keep this one around — it was fun."

Note: Claude did **not** get to play Vare for this one. The user hit a usage
limit mid-battle and finished against the bot.

## Battle 2 — Ashweir Bridge (written, verified, NOT played)

Files: `campaign/battles/02_ashweir_bridge.json` + `.md`. Copied to
`campaign/current_battle.json`, so it's the active loadable battle.

Blue (7 formations) defends the near bank of a river against an 11-formation
Vare muster. Rows 9-11 water, cols 9-10 a two-wide bridge gap. Paired
asymmetric objectives: Blue `survive` until round 28; Vare `reach` area
`[0,15,20,5]` with Strength 18.

Designed directly from Battle 1's debrief: a chokepoint the heavies can plant
themselves in, so the fight comes to them. Also the first outing for the
`reach`/`survive` attacker/defender objective pair.

**Verification playthrough (bot vs bot):** Vare forced the crossing at round 14
of 28, losing 4 of 11 to Blue's 2 of 7 (Blue ended at 5 alive). Neither a
curbstomp nor a stalemate.

**Recruitment choice:** offered Light Cavalry vs Light Archer; user chose
Light Archer ("I think i want more archers") → Wren. Leaves the roster with no
cavalry at all, which is a deliberate trade worth watching when Blue next needs
to reach somewhere fast.

## How to actually play it

Play mode 1: user in the app, Claude commanding Vare over MCP.

Launch (PowerShell):

```bash
& "C:\situation-room\Godot_v4.3-stable_win64.exe" --path C:\stratego\new -- --remote
```

(Same without the `&` in cmd.exe. Bridge listens on port 8791 — `Test-NetConnection`
to confirm it's up.)

**Use the `commit` MCP tool, not `end_planning`.** `commit` marks only the
caller's side ready and lets the running app resolve once the human finishes
their own planning. `end_planning` marks *every* unready side ready, bot-plans
for them, and resolves inside the bridge — which silently plays the human's turn
and skips the app's own presentation/animation. `commit` was added to
`mcp/server.js` specifically for this.

## Outstanding

- **The faction decision (above) is the next thing.** Nothing else proceeds until
  the commander picks Blue-again / Green / Yellow. Then: build that faction's
  starting roster with a *properly-sized* army (see the recruitment-economy
  finding — do not repeat the two-formation mistake), give it an identity, and
  design its first battle against Vare.
- **`current_battle.json` still holds the broken Fen Road** — replace it when the
  next battle is built; don't hand it to anyone as-is.
- **Recruitment economy is now a rule** (`roster.json` → `rules.recruitment_economy`):
  a won battle must fund a viable rebuild. Apply it to the new faction's starting
  strength and to every future between-battle supply.
- **Verify winnability (bot-vs-bot) before handover.** This is the process fix from
  the Fen Road and it is not optional going forward.
- Standing engine gaps unchanged: veteran-reroll engine hook, between-battle
  Strength-gain mechanic, and the bot chokepoint/pursuit weaknesses in
  `bot_policy.gd` (it cannot run a pursuit either — Fen Road confirmed).
- **Veteran reroll is now a written rule** (`roster.json` → `rules.veteran_reroll`),
  awarded to Stonewatch, but **GM-applied only — no engine support**. Building the
  engine hook (let the app offer a reroll on a veteran's combat die) is still
  outstanding.
- **Between-battle Strength gains** are now a written rule
  (`rules.strength_gain`) but likewise unimplemented in engine; applied by hand
  during the rebuild.
- **Turn-limit lesson for the next defensive battle:** shorten the `survive`
  window hard. Ashweir's 28 was decided by ~18. See `design_log.md`.
- **Bot chokepoint fix** (`bot_policy.gd`: use both lanes, manoeuvre around a
  jam) before another chokepoint scenario is trusted with the bot on the
  attacker.

Done this pass: Battle 2 recorded (`battles/02_ashweir_bridge.md` outcome +
debrief), replay archived (`replays/02_ashweir_bridge.json`), roster updated,
findings promoted to `design_log.md`, chronicle started (`chronicle.md`).

## Engine work done in service of the campaign

- `CampaignScenario` (`scripts/campaign_scenario.gd`) — loads a battle from
  JSON, applies terrain/rosters/objectives, and builds a name-annotated battle
  report straight from `game.battle_history` with no re-simulation.
- `SCENARIO_CAMPAIGN` + persisted `campaign_battle_data`, so a campaign battle's
  replay reconstructs the actual army instead of silently falling back to
  `MEETING_ROSTER`.
- Replay format gaps fixed: `cavalry_always_leftover` is now captured in the
  replay setup (it never was, for *any* scenario), and replay application passes
  `strict_friendly=false` — a recorded order is a fact to reproduce, not a
  proposal to re-judge.
- Battles now auto-export to `campaign/last_battle_report.json` and
  `campaign/last_battle_replay.json` on game end.
- `cavalry_always_leftover` is now the **default on**, per the user liking the
  rule.

## Melee tie-break investigation — closed, no change shipped

A long A/B sweep asked whether defenders should win melee ties. Outcome: **no.**
The blanket `defender_wins_ties` softened Infantry-vs-Infantry attacks (which
were already the attacker's worst matchup) while barely affecting
Cavalry-vs-Infantry, which was the case it was meant to help. A narrower
`defender_resists_charge_ties` was built and is provably inert on
Infantry-vs-Infantry, but the data didn't justify shipping it either. Both flags
exist in `stratego_game.gd`, both default off.

Two things worth carrying forward from that work:

1. **A real bug was found and fixed:** `setup_skirmish` mis-centred deployment,
   handing Blue a full extra cell of depth at odd separations and deciding ~90%
   of bot-vs-bot games by seat rather than composition. Fixed at
   `scripts/stratego_game.gd:392`. Any skirmish A/B data from before that fix is
   confounded.
2. **Cavalry's dominance in bot-vs-bot runs was mostly bot tuning, not engine
   math.** `bot_policy.gd` has `cavalry_charges := 3.0`, a pure eagerness bonus
   with no infantry equivalent, so cavalry initiates nearly every fight and wins
   the war by choosing when to engage even when individual fights are close to
   even. If cavalry ever needs toning down, that weight is the lever — not the
   combat rules.

Separately, a full combat-resolution rewrite is now in design. See
`campaign/HANDOFF_combat_rewrite.md`.

## Uncommitted work in the tree

`README.md`, `scripts/board_view.gd`, and a `_test_minimap_navigation_centres_main_view`
test in `tests/test_runner.gd` are the **user's own in-progress work** on a
separate minimap feature. Don't commit them. Several times this session I staged
only my own lines within a shared file using
`git hash-object -w` + `git update-index --cacheinfo` to avoid sweeping them in.

Standing instruction: **push to origin/main right after every commit** in this
repo, without being asked.
