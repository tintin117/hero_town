# Hero Town

Open `project.godot` in **Godot 4.6.3**. **F5** starts the main menu and desktop companion. Disable **Embed Game on Play** to let the companion position its own desktop window.

The desktop companion now runs **Farm and Fight**: assign farmers to gold and wood, build hero towers, invest in four research branches, and push through continuous waves to an endless frontier. Old expedition saves remain separate.

## Start editing

New designers and artists: start with the [game structure and onboarding map](docs/GAME_MAP.md) for mode diagrams, scene trees, editing locations, and a first 10-minute walkthrough.

| Work | Open in Godot |
| --- | --- |
| Menu layout and artwork | `game/menu/main_menu.tscn` |
| Companion town and buildings | `game/companion/companion.tscn` |
| Companion ground and land layouts | `game/companion/farm_terrain.tscn`, `farm_land.tscn`, `farm_quarry.tscn`, `farm_river.tscn` |
| Farming spots and minimized sparring | `game/companion/gold_spot.tscn`, `wood_spot.tscn`, `taskbar_sparring.tscn` |
| Farm and Fight economy, heroes, waves, and land scaling | `data/companion/farm_fight_balance.tres` |
| Town mode, HUD, and landscapes | `game/town/town.tscn` and neighboring scenes |
| Town balance | `data/town/` |
| Shared soldier animations and UI theme | `resources/art/`, `resources/ui/` |

For experiments, open **`game/previews/companion_preview.tscn`** or **`game/previews/town_preview.tscn`** and press **F6**. These previews disable player-save loading and writing. Edit the base scenes for shared changes. The companion preview also supports inherited-scene overrides; the town preview loads the base town scenes with sample progress. Running a normal gameplay scene directly uses its regular save.

Read the [editor workflow](docs/EDITOR_WORKFLOW.md) for Inspector controls and the boundary between authored content and game rules. [Companion controls](docs/COMPANION.md), [town mode](docs/TOWN.md), and [test commands](tests/README.md) cover the rest.

## Folder map

Scenes and their scripts live together, grouped by feature. Keep each scene's behavior beside it; keep tunable resource values in `data/`.

```text
game/
  menu/          Main menu scene, backdrop, and buttons
  companion/     Desktop town, terrain, workers, sparring, and campaign state
  town/          Army town, combat, HUD, landscapes, and town autoloads
  shared/        Display sizing and sound helpers
  previews/      Safe F6 entry scenes for designers and artists
data/
  companion/     Campaign balance resources and their schemas
  town/          Buildings, heroes, enemies, research, stages, and schemas
resources/       Authored animation libraries, UI themes, and effects
vfx/             Reusable visual effects
asset/           Original art and audio packs
fonts/           Original fonts
tests/           Checks grouped by feature; fixtures are read-only inputs
prototypes/      Retained full-window conquest prototype
docs/            Current guides; archive/ contains historical notes
addons/          Third-party editor plugins
```

Generated test reports, captures, and temporary resources belong in `.godot/` and stay out of source control. Preserve `.gd.uid` files when moving scripts; Godot uses them to identify resources. Save filenames and resource IDs are independent of this folder layout.
