# Multiplayer Stratego — Classic

The stable, playable version of the asset-free 2–4 player Stratego variant for Godot 4. Play as Blue against one to three trainable bots, watch the active armies fight, or train the shared policy through fast headless self-play.

## Play

On Windows, double-click **Play Classic.bat** in the repository's parent folder, or **Play Stratego.bat** in this folder. The launcher uses the installed copy of Godot and opens the game directly, without the editor.

Alternatively, open this folder in Godot 4.3 or newer and run the project (`F5`).

Then:

1. Choose **2 players**, **3 players**, or **4 players** in the right-side panel. Changing this selection immediately starts a new human game.
2. Choose a **Scout range**. **Unlimited** is the default; numeric limits from 1–10 squares are available, including a four-square range suited to the larger board. Changing it starts a new match.
3. Toggle **Private battle results**. It is enabled by default; changing it also starts a new match so one knowledge rule applies throughout the game.
4. Choose **New Human Game** at any time to reshuffle. You command the Blue army at the bottom; every other active color uses the selected bot policy.
5. Click a piece, then one of the gold destination markers. Press `Esc` to cancel a selection.

The game uses a 20×20 board. Each player receives a full 40-piece army in a four-row deployment centered on one edge, leaving the corners open rather than placing adjacent armies in direct lanes. Two-player games use Red and Blue; three-player games add Green; four-player games add Yellow. Play follows those active colors clockwise. Setups are randomized for quick play, with each Flag kept off its army's front deployment row or column.

Four-square fog of war hides enemy positions outside the Manhattan-distance vision of every living friendly piece. Terrain stays visible, vision updates immediately as armies move, and learning a rank in combat does not let a player track that piece while it is outside sight. Standard combat and movement rules remain in place, including lakes, configurable long-range Scouts, Miner/Bomb combat, and the attacking Spy exception. A numeric Scout range is the maximum number of squares it may travel in one turn; pieces and lakes still block its path normally. Capturing a Flag eliminates that entire army instead of ending the match; an army with no legal moves is also eliminated. The last army standing wins.

With private results enabled, only the attacker and defender learn both ranks. An uninvolved player still receives a battle report naming the colors, location, and surviving color, but the ranks remain hidden in their board view and battle log. Ordinary movement outside the player's vision is omitted from the log. Turning the option off restores public combat identities. Spectator mode is always omniscient. Intelligence sharing and scouting reports remain separate follow-up milestones. Draws occur after 240 moves without combat or the 1,200-move limit.

## Train the bot

The **Train & Challenge (32)** button trains using the currently selected player count, Scout range, and battle-privacy rule without drawing those matches. Evaluations repeat layouts with the candidate in every active starting seat. Since the challenger controls one seat and the incumbent controls every other seat, the scoring baseline adjusts automatically for 2, 3, or 4 players. A failed contender cannot replace the playable bot.

For larger batches, run training from a terminal in this folder:

On Windows, the simplest option is to double-click **Train Stratego Bot.bat**. Enter the number of matches you want, or press Enter to train for 512 matches. The window stays open so you can see the training and title-match results.

Alternatively, use the full path to the included Godot installation in PowerShell:

```powershell
& "C:\situation-room\Godot_v4.3-stable_win64_console.exe" --headless --path "C:\stratego\classic" --script res://training/self_play.gd -- --games=512
```

Optional arguments:

```text
--games=512                 Number of self-play matches
--seed=12345                Reproducible training seed
--players=4                 Player count (2–4)
--scout-range=unlimited     Scout range (`unlimited`, `0`, or a square limit)
--private-battles=true      Private (`true`) or public (`false`) battle ranks
--output=res://trained_bot.json  Model output path
--title-matches=40          Final champion evaluation size
```

With the default output, the game and trainer share Godot's per-user data folder. If `res://trained_bot.json` exists and there is no per-user model, the game loads that project model instead.

The trainer uses evolutionary self-play. Each mutation changes only two to four weights. Session winners face the pre-run champion in a separate title match. When decisive-game scores are tied, a contender must average more than two points of material advantage to advance. Losing contenders are saved separately for continued training, while the playable champion remains untouched. The bot scores moves using its own army, public information, and currently visible enemies; it does not inspect fogged enemy positions or hidden ranks. Its directional features understand all four home edges and score threats from any surviving rival. Existing champion files migrate automatically to the current model version.

The version-5 policy adds or activates these decision categories:

- decisive avoidance of attacks against a revealed stronger piece (`known_loss`, fixed at `-100`);
- avoiding squares threatened by a revealed superior, moving away from it, and leaving a concealed valuable piece unmoved when that is safer;
- maintaining direct Flag cover and intercepting visible intruders near the Flag;
- avoiding clusters of adjacent unidentified enemies with valuable pieces;
- applying pressure to the largest remaining army while retaining a separate preference for finishing depleted rivals;
- sending Miners toward revealed Bombs and Spies toward revealed Marshals, with explicit bonuses for executing those counters.

## Watch and test

Use **Watch Self-Play** in the app to see the current policy command every active army with all pieces revealed.

### Choose a bot generation

Use the **Opponent Model** menu in the right-side panel to play against or watch any saved model. It lists the current champion, previous champion, continuing training contender, project model when present, and every archived generation. Select **Current champion** again to enable training.

Every candidate that wins its eight-game mini-series is now saved permanently in Godot's user-data archive. On this computer the files are in:

```text
C:\Users\watch\AppData\Roaming\Godot\app_userdata\Stratego- Self-Play Arena\champions
```

Archive files include both generation and lifetime game count, for example `generation_00628_games_0005738.json`. Existing current, previous, and contender models are migrated into the archive when the game starts.

Double-click **Evaluate Stratego Bot.bat** to run a read-only tournament between the current and previous champions. It repeats each layout with the challenger in every active starting seat and reports match score, material edge, and an estimated rating difference.

Run the automated rules and self-play checks with:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

## Piece key

`F` Flag · `B` Bomb · `1` Spy · `2` Scout · `3` Miner · `4` Sergeant · `5` Lieutenant · `6` Captain · `7` Major · `8` Colonel · `9` General · `10` Marshal
