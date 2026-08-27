# Stratego Projects

This repository contains two independently playable Godot projects on the same `main` branch.

## Classic

`classic/` is the stable version: 2–4 players, trainable bots, configurable Scout movement, four-square fog of war, and optional private battle results. New gameplay experiments should not be developed here, although important fixes can still be applied deliberately.

Use **Play Classic.bat** to launch it. The original **Play Stratego.bat**, **Train Stratego Bot.bat**, and **Evaluate Stratego Bot.bat** launch Classic for backward compatibility.

## New

`new/` is the substantially different WEGO formation prototype. Players plan full paths simultaneously; movement resolves by weight-speed impulses, followed by melee/retreat batches, ranged fire, leftover movement, and end-of-round victory checks. It includes the bridge-crossing scenario and retains a four-player fog mode.

Use **Play New.bat** to launch it. New has a separate Godot application identity, so its trained bots and other `user://` data cannot overwrite Classic's data.

## Tests and training

- **Test Classic.bat** and **Test New.bat** run each version's automated checks.
- **Train Classic Bot.bat** and **Evaluate Classic Bot.bat** retain the trained-policy workflow.
- New currently uses a heuristic simultaneous-order bot while the WEGO action space is stabilized; its training/evaluation launchers run bounded self-play diagnostics rather than persisting a champion model.

The source folders are self-contained Godot projects. Open `classic/project.godot` or `new/project.godot` in the editor, rather than opening the repository root as a Godot project.
