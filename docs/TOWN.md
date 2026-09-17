# Hero Town remaster

This separate town mode is a 20-stage idle army demo. It uses the existing Tiny Swords art, Peaberry font, music, and effects. No generated assets or third-party addon modifications are required.

## Play

F5 opens `game/menu/main_menu.tscn`. Resume continues the Growing Banner companion; New Game starts a fresh companion save and backs up the previous run. For a fresh preview without player saves, open `game/previews/town_preview.tscn` and press F6. Running `game/town/town.tscn` directly uses the normal town save. The menu uses its original 1920×1080 design viewport.

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

The `mage_tower`/`rogue_den` IDs and hero class values 2/1 intentionally remain stable; the playable classes are Ranger/Lancer. All four classes now have five authored rarity resources. These IDs remain stable for saved progression.

Crew tops out at six per building. Army capacity grows from 3 to 4, 6, and 8 after the first three captains. Rarity promotions require stages 3, 5, 10, and 15; they upgrade the whole army and preserve training. Training grants up to three ranks of damage, health, haste, and class specialty.

Gold is the only active currency. Town Hall is fixed. Portal management, shards, Tavern, Blacksmith, random upgrade offers, and the former research preview are not part of this demo's UI.

## Desktop landscapes

Options now offers waterside village, terraced castle town and scattered hamlet scenery. Native companion mode has transparent surroundings and a compact control strip. Keep Embed Game on Play disabled. See [COMPANION_REDESIGN.md](archive/COMPANION_REDESIGN.md) for historical screenshots and validation.

## Runtime architecture

The town entry scene is `game/town/town.tscn`. Its scenes and scripts live together in `game/town/`; the menu lives separately in `game/menu/`:

| Component | Responsibility |
|---|---|
| `town.gd` | Terrain, building/unit views, placement input, camera fit, presentation |
| `town_hud.gd` | Build/research controls, HUD, reports, return summary, settings |
| `desktop_window.gd` | Native compact/expanded window behavior and restoration |
| `battle_director.gd` | Preparation, battle snapshots, rewards, recovery, progression |
| `battle_simulation.gd` | Fixed-step movement, targeting, projectiles, abilities, damage, healing, bosses |
| `rules.gd` | Shared caps, formation coordinates, research-derived stats |
| `unit_view.gd`, `town_building.gd` | Animated sprite presentation and selection badges |

`GameState` owns gold, numbered building records, research spending, progression, settings, and save transactions. `GameData` loads building/hero/research/stage resources. Stage definitions live in `data/town/stages/`; research nodes live in `data/town/research/`.

The combat simulation is independent of rendering. The visible game and balance tests use the same model, including projectile travel, boss warnings, healing, guard, and timeouts. It runs at a fixed 0.05-second step and is capped at 20 live enemies. Unit views only consume model state and events. Victories are settled by the director, not individual enemy deaths.

Unused legacy combat, placement, and research UI implementations have been removed. The independent full-window conquest prototype remains in `prototypes/full_window_conquest/`.

## Saving and offline income

The save is `user://hero_town_v1.json`, normally under `%APPDATA%/Godot/app_userdata/hero town/` on Windows. A `.bak` file keeps the previous valid state. Saves use a temporary file, flush, and replacement; malformed primary saves recover from the backup. Unreadable originals are retained when neither copy can load.

Purchases, moves, results, and settings save immediately; periodic checkpoints run every 30 seconds. An interrupted battle restarts in preparation and cannot award a duplicate victory. This is a new versioned save format; the earlier prototype did not persist progression.

Offline income is half the average ordinary-battle gold rate across the latest five successful ordinary battles. New samples include the actual battle duration and 0.8-second recovery. Historical samples keep their recorded duration and are replaced gradually by new wins. First-clear bonuses are excluded. Earnings cap at eight hours, require a prior ordinary victory, and never unlock stages. Research refunds clear the measured rate. Returning applies and saves gold before showing the summary; repeated reopening and clock rollback cannot repeat the reward.

## Tests

See [tests/README.md](../tests/README.md) for current commands, isolated user data, and native-window checks. Generated reports stay under `.godot/`. The [historical validation record](archive/REMASTER_VALIDATION.md) and [progression notes](archive/BUILDING_PROTOTYPE.md) record earlier pacing measurements and their limits; they are not a substitute for running the current checks.

## Building progression

The compact HUD keeps the next objective visible and supports a pinned upgrade cost. Buildings combines crew, rarity, training, role information, and affordability progress. Barracks offers free reversible Balanced, Bulwark, and Vanguard choices; changes apply to the next battle. Newly recruited soldiers wait visibly beside their building during combat. Arrange mode previews deployment and allows safe refunds between battles. The first boss opens the fourth army plot. Results transition after 0.8 seconds without a blocking reward panel.
