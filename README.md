# Stratego: Self-Play Arena

A complete, asset-free Stratego game for Godot 4. Play as Blue against a trainable bot, watch the bot play both armies, or train it through fast headless self-play.

## Play

On Windows, double-click **Play Stratego.bat** in this folder. The launcher uses the installed copy of Godot and opens the game directly, without the editor.

Alternatively, open this folder in Godot 4.3 or newer and run the project (`F5`).

Then:

1. Choose **New Human Game**. You command the blue army at the bottom.
2. Click a piece, then one of the gold destination markers. Press `Esc` to cancel a selection.

The setup is randomized for quick play, with each Flag restricted to its army's three rear rows. Enemy ranks stay hidden until combat. Standard combat and movement rules are implemented, including lakes, long-range Scouts, Miner/Bomb combat, the attacking Spy exception, flag capture, and wins by immobilization.

Combat results remain visible in **Last Combat** and are emphasized in the battle log; the affected square receives a brief marker without covering the board. The rules panel and game-over card distinguish wins by immobilization from draws caused by 120 moves without combat or the 500-move limit.

## Train the bot

The **Train & Challenge (32)** button runs self-play without drawing those matches. Every challenger is judged over eight paired games, then the best contender must defeat the exact pre-training champion in a separate 40-game title match. A failed contender cannot replace the playable bot.

For larger batches, run training from a terminal in this folder:

On Windows, the simplest option is to double-click **Train Stratego Bot.bat**. Enter the number of matches you want, or press Enter to train for 512 matches. The window stays open so you can see the training and title-match results.

Alternatively, use the full path to the included Godot installation in PowerShell:

```powershell
& "C:\situation-room\Godot_v4.3-stable_win64_console.exe" --headless --path "C:\stratego" --script res://training/self_play.gd -- --games=512
```

Optional arguments:

```text
--games=512                 Number of self-play matches
--seed=12345                Reproducible training seed
--output=res://trained_bot.json  Model output path
--title-matches=40          Final champion evaluation size
```

With the default output, the game and trainer share Godot's per-user data folder. If `res://trained_bot.json` exists and there is no per-user model, the game loads that project model instead.

The trainer uses evolutionary self-play. Each mutation changes only two to four weights and is tested across eight games: four randomized layouts, each replayed with the candidate on both colors. Session winners then face the pre-run champion in a separate title match. Losing contenders are saved separately for continued training, while the playable champion remains untouched. The bot scores moves using only public information plus its own ranks; it does not inspect hidden enemy ranks. This includes learned parameters for approaching or escaping nearby revealed superior pieces and for preserving the Bomb-like uncertainty of valuable pieces that have never moved.

## Watch and test

Use **Watch Self-Play** in the app to see the current policy command both armies with all pieces revealed.

### Choose a bot generation

Use the **Opponent Model** menu in the right-side panel to play against or watch any saved model. It lists the current champion, previous champion, continuing training contender, project model when present, and every archived generation. Select **Current champion** again to enable training.

Every candidate that wins its eight-game mini-series is now saved permanently in Godot's user-data archive. On this computer the files are in:

```text
C:\Users\watch\AppData\Roaming\Godot\app_userdata\Stratego- Self-Play Arena\champions
```

Archive files include both generation and lifetime game count, for example `generation_00628_games_0005738.json`. Existing current, previous, and contender models are migrated into the archive when the game starts.

Double-click **Evaluate Stratego Bot.bat** to run a read-only tournament between the current and previous champions. It uses paired layouts, swaps colors, and reports match score, material edge, and an estimated rating difference.

Run the automated rules and self-play checks with:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

## Piece key

`F` Flag · `B` Bomb · `1` Spy · `2` Scout · `3` Miner · `4` Sergeant · `5` Lieutenant · `6` Captain · `7` Major · `8` Colonel · `9` General · `10` Marshal
