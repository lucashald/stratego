# Handoff: the campaign ("The Ashmere Line")

Status as of 2026-09-01. Battle 1 is played and debriefed. Battle 2 is written,
verified, and loaded — but **not yet played**.

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

`campaign/roster.json` is the source of truth. Battle 2, supply 1.

**Alive:** Oakhand (HI, 5), Stonewatch (HI, 8), Marrow (MI, 5), Thistle (MI, 3),
Coldbrook (LI, 6), Harrow (MA, 6), Wren (LA, 5 — new recruit, 0 battles).

**Fallen:** Kestrel (LA), Ferrant (MC), Ash (LC). All three died at the Toll
Road. The roster lost every fast, mounted, and (until Wren) ranged formation it
had.

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

- **Play Battle 2.** It's loaded and waiting.
- **Veteran rerolls don't exist yet.** Promised as "I'll build the rule while
  you fight, so it's live for Battle 2" — never actually implemented. Still
  outstanding.
- **Between-battle Strength gains** for resting survivors: stated as a campaign
  rule, no mechanic built.
- Debrief Battle 2 conversationally once it concludes, and promote findings to
  `campaign/design_log.md`.

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
