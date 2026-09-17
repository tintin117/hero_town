# Editing Hero Town

For a visual overview and a first-session walkthrough, start with the [game structure and onboarding map](GAME_MAP.md).

Open `project.godot` in Godot 4.6. The normal **F5** route is `game/menu/main_menu.tscn` → `game/companion/companion.tscn`. The larger remaster town is a separate scene, `game/town/town.tscn`. Use the scenes in `game/previews/` with **F6** for experiments without loading or changing player saves. See the [folder map](../README.md) for all entry points.

The editor owns the things you can see and tune: scene composition, textures, animation frames, terrain, themes, and authored balance resources. Scripts own saved progress, purchases, battle simulation, spawning the current army, animation playback, and adapting the desktop window. Editing a saved scene or resource changes the next run; runtime changes in Godot's **Remote** scene tree are temporary.

## Main menu

Open `game/menu/main_menu.tscn`. Change the menu artwork under `MainMenuScene` and button artwork, labels, spacing, and font overrides under `front_ui/Layout`. The buttons keep their existing signal connections. The root's companion save path selects the campaign used by New Game/Resume.

## Farm and Fight companion

Open `game/companion/companion.tscn`. The companion owns its FarmFightState; legacy expedition logic remains available to the retained full-window prototype. Use `game/previews/companion_preview.tscn` for F6 editing without player saves. Normal gameplay uses `user://farm_fight_v1.json`; there is no legacy-save seeding.

### Art and layout

| Task | Scene or node | Editable controls |
| --- | --- | --- |
| Home farmland | `farm_land.tscn` | Gold/wood spot positions, land title, terrain instance |
| Repeating land variants | `farm_quarry.tscn`, `farm_river.tscn` | Inherited spot positions and decorative props |
| Ground and cliffs | `farm_terrain.tscn` | Native painted TileMapLayers; the default land span is 1440 pixels |
| Resource visuals and workers | `gold_spot.tscn`, `wood_spot.tscn` | Resource sprite, worker template scale/textures, interaction target, worker spacing |
| Hero buildings | Companion → `Settlement/TownDistrict/Towers` | Each class group, sprite, status label, hit target, and Spawn marker |
| Enemy tower and rear defense | Companion → `Settlement/TownDistrict/Enemy`, `RearDefense` | Artwork, labels, and health-bar layout |
| Soldiers | `game/town/unit_view.tscn`, `resources/art/unit_library.tres` | Shared class animations and unit presentation; companion Unit Scene can override |
| HUD and panels | Companion → `HUD/Bar`, `ManagementPanel` | Theme, layout, typography, Farm/Tower/Research controls |
| Skill graph | `skill_tree.tscn` → `Graph`, `Detail` | Class icons, node positions, connections, selected-node card; upgrades stay repeatable |
| Pack UI theme | `resources/ui/farm_theme.tres` | Original Tiny Swords buttons/icons; parchment and wood nine-slice tiles assembled from the original pack into `farm_paper.png` / `farm_wood.png` |
| Folded view | `taskbar_sparring.tscn` | Cosmetic duel poses and timing |
| Combat feedback | Companion Presentation exports and `combat_number.tscn` | Damage/healing colors and floating-number appearance |

Only visible and adjacent land scenes are instantiated. Worker counts come from assignments, and soldiers from combat state; edit their templates rather than adding duplicate runtime actors. Land templates must retain Title, GoldSpot, and WoodSpot. The companion's Land Scene is home farmland; Land Variants cycle over conquered/frontier indices. Keep terrain width and Land Span consistent.

The moving TownDistrict positions the active battlefield. Within it, tower groups remain authored; Spawn markers determine new hero spawn positions. Preserve the Formation and tower contracts when changing the composition. Worker animation uses the assigned count but does not determine income.

Panels use native controls and anchors. Runtime text shows current values; static styling and scene overrides remain editable. The companion adapts panel width and native window size to the monitor. The popup expands to a 640-pixel logical window, with gameplay continuing underneath; display scale also fits that height on smaller monitors.

### Balance and rules

Select `data/companion/farm_fight_balance.tres`. Inspector groups cover starting resources/workers, spot capacity, income, farmer costs, efficiency, cost growth, hero capacity, stat/spawn scaling, enemy waves, tower health, land names and strength curves.

Expand Heroes to edit the four class resources: stable ID, display description, combat role, stats, attack range, spawn timer, and gold/wood prices. Use IDs `warrior`, `monk`, `archer`, and `lancer`. The default opening has four idle farmers, 25 gold, 20 wood, one Warrior and its barracks. Starting Warriors and Starting Tower are editable. A small enemy wave starts nearby immediately; later waves enter from the enemy tower. Reinforcement purchases use the global Recruit Seconds cooldown, separately per tower.

Gold/wood scenes contain eight deposit sprites, five `WorkPlaces` markers, a `Dropoff` marker, and the editable worker template. Assigned workers harvest at those positions and carry resources to camp. Move markers and scenery directly in the editor. The four-step opening guide follows real progress and never pauses the fight.

Costs grow from authored base prices using the cost exponent. Farmer and hero stat bonuses are additive per purchased rank; tower spawn intervals shorten toward the configured minimum. Land yield and enemy strength grow with territory number. New-game values apply to fresh campaigns; existing progress remains saved.

Duplicate the balance resource and assign the companion's Balance field for experiments. The menu's selected Companion Scene supplies its New Game balance. Preview disables both the campaign save and the unrelated town autoload's persistence.

The older `default_balance.tres`, `conquest_state.gd`, `terrain.tscn`, and `town_workers.tscn` remain for the full-window expedition prototype/reference. They no longer tune the active Farm and Fight campaign.

## Remaster town

Open `game/town/town.tscn` to edit, or run `game/previews/town_preview.tscn` with **F6** for a fresh town without player saves. Its camera, scenery, HUD, audio player, desktop controller, and battle director are scene nodes. The root's **Building Scene** and **Unit Scene** select the templates used when the game spawns buildings and soldiers.

| What to edit | Scene or resource | Editor controls |
| --- | --- | --- |
| Meadows, castle terrace, village | `game/town/landscapes/meadow.tscn`, `terrace.tscn`, `village.tscn` | Paint `Terrain`; move or replace Sprite2D props; edit Line2D road points; change water polygon/texture. |
| Landscape selection | `game/town/scenery.tscn` | Authored landscape children. Runtime Options selects the visible landscape. |
| Building presentation | `game/town/town_building.tscn` | Sprite transform, texture override, interaction rectangle. The saved army record controls placement on the gameplay grid. |
| Soldier presentation | `game/town/unit_view.tscn` | Sprite transform, animation resource override, art library, boss scale, movement smoothing, death effect. Battle simulation controls position and health. |
| Shared soldier animations | `resources/art/unit_library.tres` and `resources/art/{warrior,lancer,archer,monk}_{blue,red}.tres` | Blue/Red entries select SpriteFrames resources; the SpriteFrames editor changes textures, frame regions, animation speed, and looping. |
| Death animation | `game/town/death_dust.tscn` | AnimatedSprite2D SpriteFrames, scale, frame timing. |
| Interface | `game/town/town_hud.tscn` | Static controls, fonts, theme styles, and responsive sizing settings. Runtime labels show current gold, phase, and army state. |
| Building costs and art | `data/town/buildings/*.tres` | Build Cost, Starting Crew, Unlock Stage, Thumbnail, Sprite Texture. |
| Hero balance | `data/town/heroes/*.tres` | Base HP, Base Power, Atk Speed, ability and class fields. |
| Research | `data/town/research/*.tres` | Title, Description, Cost, prerequisites, rank, and value fields used by the rules. |
| Encounters and rewards | `data/town/stages/stage_01.tres` … `stage_20.tres` | Enemies, Gold, First Clear Gold, Time Limit. |

Container nodes arrange their children automatically. Change their spacing, minimum sizes, and theme overrides rather than dragging container-managed child positions. Responsive layout and camera fitting adapt to compact windows; disable the relevant automatic layout control only when deliberately authoring a fixed layout.

On `Scenery`, **Preview Landscape** switches the editor preview; **Ambient FPS** controls decorative animation. On the town root, **Fit Camera To Window** controls camera fitting. On `TownHUD`, **Responsive Layout** controls automatic panel/toolbar positions, and **Responsive Typography** controls window-dependent font sizes. Per-control font overrides remain available.

Keep the `idle`, `run`, `attack`, and any existing `guard` animation names. The companion's worker, training, and taskbar art uses its own authored scene assets; changing remaster animation resources does not replace those scenes automatically.

## Where code is still needed

- Adding a new purchase type, ability, campaign action, or save field changes game rules and needs code.
- Current army size, combatants, damage numbers, spawn countdowns, and contextual action lists come from the running state. Edit their source scenes/resources instead of adding a second runtime copy by hand.
- Keep resource IDs, required animation names, and gameplay-linked node references stable. Rename display labels freely; coordinate schema or ID changes with a programmer.
- Cosmetic terrain does not move legal placement cells or battle formations. Changing the tactical grid remains a rules change.
- `prototypes/full_window_conquest/conquest.tscn` is the older full-window conquest prototype. It retains its own legacy balance and procedural interface; use the companion and remaster scenes above for the new editing workflow.

## Verify a change

Save the scene/resource, stop the running game, and start it again. Check the altered object in the same mode where players will see it, including compact town and an expanded management panel. For battle art, build a tower and observe automatic waves so idle, movement, attack, and death poses are exercised.

The automated scene/resource edit checks run with:

```powershell
& '<Godot executable>' --headless --path . res://tests/editor/editor_workflow_checks.tscn -- --test
```

They save modified scene/resource copies under `.godot`, reload them, and verify the changes survive startup. `--test` disables the legacy GameState save system; these checks use a separate companion save path. See [tests/README.md](../tests/README.md) for the gameplay and native-window checks.
