# Hero Town remaster

The active game is now a 20-stage idle army demo. It uses the existing Tiny Swords art, Peaberry font, music, and effects. No generated assets or third-party addon modifications are required.

## Play

F5 opens `scenes/main_menu.tscn`. Resume continues the Growing Banner companion; New Game starts a fresh companion save and backs up the previous run. To run the older 20-stage remastered town, open `scenes/town_2d.tscn` and press F6. The menu uses its original 1920×1080 design viewport.

Use a separate game window for desktop companion mode; disable Godot's embedded game preview if it is enabled, so the game can resize and position its own native window.

1. Choose **Build**, select the Barracks, and click a free town tile. The initial 150 gold covers its 100-gold price and one 50-gold training node.
2. Three Warriors appear immediately. Battles begin automatically as soon as an army exists.
3. Battles run automatically. Victory awards gold once, and all soldiers recover between rounds.
4. Click a building, or choose **Buildings** and select an army by its numbered identity. Each building has independent Crew, Rarity, and Training branches.
5. Defeat captains at stages 5, 10, 15, and 20. Defeat switches to farming cleared stages. An improvement or **Challenge** starts another progression attempt.

Right-click or Escape cancels placement. Moving is free and changes the next round's formation. Choose **Arrange** to hold the next battle and wait for the current battle to finish. Research refunds are then available; the building remains. Choose **Resume** to continue. Purchases during combat never alter the active battle snapshot.

**Options** controls volume, always-on-top, reduced effects, companion height, and the stage to farm. Management panels expand the same game window and restore it when closed. **Report** shows each army's damage, healing, and casualties. Completing stage 20 leaves farming enabled.

## Armies and progression

| Building ID | Display name | Initial crew | Unlock | Specialty |
|---|---|---:|---:|---|
| `barracks` | Warrior Barracks | 3 | Start | Protect nearby allies |
| `mage_tower` | Ranger Range | 2 | Stage 2 | Three-target volley |
| `cleric_hall` | Cleric Sanctuary | 1 | Stage 4 | Heal an injured ally |
| `rogue_den` | Lancer Lodge | 2 | Stage 7 | Piercing line attack |

The `mage_tower`/`rogue_den` IDs and hero class values 2/1 intentionally remain stable; the playable classes are Ranger/Lancer. All four classes now have five authored rarity resources. The old fantasy-class labels in the retained prototype scripts are not used by the active game.

Crew tops out at six per building. Army capacity grows from 3 to 4, 6, and 8 after the first three captains. Rarity promotions require stages 3, 5, 10, and 15; they upgrade the whole army and preserve training. Training grants up to three ranks of damage, health, haste, and class specialty.

Gold is the only active currency. Town Hall is fixed. Portal management, shards, Tavern, Blacksmith, random upgrade offers, and the former research preview are not part of this demo's UI.

## Desktop landscapes

Options now offers waterside village, terraced castle town and scattered hamlet scenery. Native companion mode has transparent surroundings and a compact control strip. Keep Embed Game on Play disabled. See [COMPANION_REDESIGN.md](COMPANION_REDESIGN.md) for actual-size screenshots, save safety and current validation.

## Runtime architecture

`scenes/main_menu.tscn` and `scenes/town_2d.tscn` remain the entry scenes. Their active scripts live in `scripts/remaster/`:

| Component | Responsibility |
|---|---|
| `town.gd` | Terrain, building/unit views, placement input, camera fit, presentation |
| `town_hud.gd` | Build/research controls, HUD, reports, return summary, settings |
| `desktop_window.gd` | Native compact/expanded window behavior and restoration |
| `battle_director.gd` | Preparation, battle snapshots, rewards, recovery, progression |
| `battle_simulation.gd` | Fixed-step movement, targeting, projectiles, abilities, damage, healing, bosses |
| `rules.gd` | Shared caps, formation coordinates, research-derived stats |
| `unit_view.gd`, `town_building.gd` | Animated sprite presentation and selection badges |

`GameState` owns gold, numbered building records, research spending, progression, settings, and save transactions. `GameData` loads building/hero/research/stage resources. Stage definitions live in `data/stages/`; research nodes live in `data/research/`.

The combat simulation is independent of rendering. The visible game and balance tests use the same model, including projectile travel, boss warnings, healing, guard, and timeouts. It runs at a fixed 0.05-second step and is capped at 20 live enemies. Unit views only consume model state and events. Victories are settled by the director, not individual enemy deaths.

The earlier scripts under `scenes/` and `scripts/` (including `character.gd`, `hero.gd`, `enemy.gd`, and the preview panels) remain as prototype references. They are not instantiated by the new entry scenes. Do not connect them to the remaster's gameplay or its authoritative transactions.

## Saving and offline income

The save is `user://hero_town_v1.json`, normally under `%APPDATA%/Godot/app_userdata/hero town/` on Windows. A `.bak` file keeps the previous valid state. Saves use a temporary file, flush, and replacement; malformed primary saves recover from the backup. Unreadable originals are retained when neither copy can load.

Purchases, moves, results, and settings save immediately; periodic checkpoints run every 30 seconds. An interrupted battle restarts in preparation and cannot award a duplicate victory. This is a new versioned save format; the earlier prototype did not persist progression.

Offline income is half the average ordinary-battle gold rate across the latest five successful ordinary battles. New samples include the actual battle duration and 0.8-second recovery. Historical samples keep their recorded duration and are replaced gradually by new wins. First-clear bonuses are excluded. Earnings cap at eight hours, require a prior ordinary victory, and never unlock stages. Research refunds clear the measured rate. Returning applies and saves gold before showing the summary; repeated reopening and clock rollback cannot repeat the reward.

## Tests

See [REMASTER_VALIDATION.md](REMASTER_VALIDATION.md) for recorded check counts, progression timings, native graphics measurements, and their limits.

Test scenes launched from `res://tests/*.tscn` through Godot MCP automatically disable persistence; `-- --test` also remains supported. This disables loading the real player save; save tests use isolated files under `.godot/remaster_tests/`.

```powershell
$godot = 'D:\Personal Stuff\Godot\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
& $godot --headless --path . res://tests/remaster_tests.tscn -- --test
& $godot --headless --path . res://tests/remaster_ui_tests.tscn -- --test
& $godot --headless --path . res://tests/remaster_balance.tscn -- --test
& $godot --headless --path . res://tests/remaster_endurance.tscn -- --test
& $godot --path . res://tests/remaster_desktop_tests.tscn -- --test
```

The endurance test defaults to **1,800 seconds of wall-clock time**. Use `--duration=60` after `--test` for a short smoke test. Without `--headless`, it also exercises native graphics. It fills every battle to 48 soldiers and 20 enemies, logs population/memory periodically, and records frame timing and peak nodes. Reports in `.godot/` are local build artifacts.

The balance script simulates an explicit purchasing policy; its times are pacing evidence, not a guarantee for every player strategy. It reserves gold for unlocked army types, then favors affordable crew, promotions, and training. The current three-policy comparison finishes in 35–37 minutes with the first captain at 3–4 minutes. See BUILDING_PROTOTYPE.md for current results. Human playtesting should assess readability, sound levels, formation clarity, and whether the later captain battles feel rewarding.

## Building prototype

The compact HUD keeps the next objective visible and supports a pinned upgrade cost. Buildings combines crew, rarity, training, role information, and affordability progress. Barracks offers free reversible Balanced, Bulwark, and Vanguard choices; changes apply to the next battle. Newly recruited soldiers wait visibly beside their building during combat. Arrange mode previews deployment and allows safe refunds between battles. The first boss opens the fourth army plot. Results transition after 0.8 seconds without a blocking reward panel.
