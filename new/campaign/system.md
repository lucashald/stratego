# Campaign system — The Red Tide

Built from what killed Blue. The Ashmere Line put its entire strength on the field
every battle, so one bad battle ended the faction. Halgate is structured so that
cannot happen: the faction is more than one army, and the city's wealth rebuilds
what a battle costs.

## The campaign turn

Each turn is a loop:

1. **Intelligence.** The GM reports where Vare strikes next and what is known of
   the strike force — its size, its composition, its objective, the ground.
   Recorded as `dispatch_NN.md`.
2. **Choose a company.** The commander picks which of Halgate's companies to send.
   Only that company is at risk in the battle; the rest of the faction stays home.
   Losing does not wipe Halgate — it costs one company blood.
3. **Reinforce and recruit.** Spend from the treasury: restore chosen formations
   toward full Strength (1 crown/point) and/or hire new formations from the
   reserve ((Strength) + 2 crowns) and fold them into the deploying company. The
   aim of this phase is to arrive competitive with the strike force just reported.
4. **Fight.** The battle is built to the choice, **verified winnable bot-vs-bot
   before handover** (the Fen Road rule), then played.
5. **Aftermath.** Survivors keep their history and may earn Veteran status.
   Permanent deaths are struck to `fallen`. The treasury gains income. Loop.

## Why this fixes Blue's problems

- **A single battle can't wipe the faction.** One company deploys; the others and
  the city remain. A defeat is a setback, not an extinction.
- **Recruiting keeps you competitive.** Intelligence comes before the deployment
  choice, so reinforcement is spent against a known threat, not blind. Halgate is
  rich by design so the money is actually there.
- **Choices every turn.** Which company, which formations to bring back to full,
  whether to hire — a real between-battle decision layer, not a single forced
  recruit.
- **Permadeath still bites.** Losses are permanent and the dead don't come back.
  What changed is that the stakes of one battle are a company, not everything.

## Files

- `roster.json` — active faction (Halgate): treasury, companies, reserve, rules.
- `ashmere_line.json` — Blue's closed record, Battles 1–3.
- `dispatch_NN.md` — each turn's intelligence report and the deployment choice.
- `battles/NN_name.{json,md}` + `replays/NN_name.json` — scenarios as played.
- `chronicle.md` — the in-world story. `design_log.md` — findings.
