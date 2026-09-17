# Editing Hero Town

Open `project.godot` in Godot 4.6. The normal **F5** route is `game/menu/main_menu.tscn` → `game/companion/companion.tscn`. The larger remaster town is a separate scene, `game/town/town.tscn`. Use the scenes in `game/previews/` with **F6** for experiments without loading or changing player saves. See the [folder map](../README.md) for all entry points.

The editor owns the things you can see and tune: scene composition, textures, animation frames, terrain, themes, and authored balance resources. Scripts own saved progress, purchases, battle simulation, spawning the current army, animation playback, and adapting the desktop window. Editing a saved scene or resource changes the next run; runtime changes in Godot's **Remote** scene tree are temporary.

## Main menu

Open `game/menu/main_menu.tscn`. Change the menu artwork under `MainMenuScene` and button artwork, labels, spacing, and font overrides under `front_ui/Layout`. The buttons keep their existing signal connections. The root's companion save path selects the campaign used by New Game/Resume.

## Companion town

Open `game/companion/companion.tscn`. Static town content is present in the Scene tree before running, so artists can position it in the 2D viewport. Open an instanced scene directly to edit every use of that scene; use **Editable Children** or **Make Local** when an individual instance needs an override.

For a fresh visual or balance preview, open `game/previews/companion_preview.tscn` and press **F6**. This inherits the editable companion, starts from the selected balance, and disables both campaign persistence and the legacy GameState save system. Edit the base `companion.tscn` for shared artwork, or use overrides on the preview scene for experiments. To keep a separate playtest campaign, run a companion scene with **Persistence Enabled** on, **Save Path** set to `user://companion_design_preview.json`, and **Seed From Full Window** off. Existing campaign saves retain their accumulated progress; changing starting values does not reset them.

### Art and layout

Paint the native `TileMapLayer` nodes in `game/companion/terrain.tscn`. Painted cells, erased cells, and layer transforms are saved in the scene and retained when the game starts. Terrain is visual: painting a tile does not change campaign plots, income, or battle rules.

The companion's static sprites, building interaction areas, training anchors, HUD controls, and taskbar sparring are authored scenes. Select the relevant node to change its position, scale, texture, and native theme overrides. Keep gameplay-linked node names and assigned references intact. When moving a building, move its complete group so its interaction area and activity indicators stay aligned.

| Task | Select/open | Change |
| --- | --- | --- |
| Move a complete building | `Settlement/TownDistrict/CastleSite`, `BarracksSite`, `AcademySite`, `FrontierSite` | The group position; children include the sprite, hit target, and activity label. `BarracksSite` also contains training sprites. |
| Dress the town | Sprite2D props under `Settlement` and `TownDistrict` | Texture, transform, Hframes/Vframes, and tint. |
| Change the army's visual layout | `TownDistrict/ActorTemplates` and the companion root | Warrior/Mage/Enemy/SpellEffect templates, Warrior/Enemy Columns and Spacing; the saved state determines how many appear. |
| Adjust worker loops | `game/companion/town_workers.tscn` | Root Cycle Seconds, Work Seconds, Delivery Distance, Animation FPS. Select a worker to set its work Texture, Carry Texture, Return Texture, Frame Width, and Phase Offset. Its scene position is its home. |
| Change taskbar sparring | `game/companion/taskbar_sparring.tscn` | Sprite transforms/textures; root Duel Seconds, Animation FPS, Lunge Distance, Fireball Arc Height, attack and guard textures. |
| Restyle controls and panels | `HUD`, `ManagementPanel`, `resources/ui/companion_theme.tres` | Native fonts, theme styles, button dimensions, panel text area, and action locations. State-dependent text and visibility still update during play. |
| Change combat feedback | `game/companion/combat_number.tscn` and companion root Combat Art | Number font/appearance, effect textures, and damage/healing colors. |

`Land Width` controls the scroll extent. If extending it, also paint the added ground and cliff cells in `terrain.tscn`; startup no longer fills terrain for you.

Worker loops and taskbar sparring are cosmetic. Their scene assets and Inspector controls change presentation, without changing resource income, project duration, or combat damage.

### Campaign balance

Select `data/companion/default_balance.tres` in FileSystem. Its Inspector groups expose **New Game** starting gold/warriors, **Economy** income and costs, **Training** prices and durations, **Combat** health/damage/healing, and **Pacing** recovery and battle presentation seconds. Expand **Expeditions → Lands** to edit each expedition's name, hint, rewards, enemy count, health, and attack. Order determines conquest order. Append expeditions to extend an existing campaign; use a fresh preview campaign when reordering or removing them because saved progress is an owned-land count.

To try another balance without changing the shared defaults, duplicate this resource and assign it to the companion root's **Balance** field. The menu's **Companion Scene** selects which companion scene supplies New Game balance. Starting-state changes apply to fresh campaigns; purchases and encounters use the selected balance. An already running project keeps the duration saved when purchased, and an already deployed battle keeps its saved outcome and presentation snapshot.

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
- Current army size, combatants, damage numbers, project countdowns, and contextual action lists come from the running state. Edit their source scenes/resources instead of adding a second runtime copy by hand.
- Keep resource IDs, required animation names, and gameplay-linked node references stable. Rename display labels freely; coordinate schema or ID changes with a programmer.
- Cosmetic terrain does not move legal placement cells or battle formations. Changing the tactical grid remains a rules change.
- `prototypes/full_window_conquest/conquest.tscn` is the older full-window conquest prototype. It shares the balance resource but retains its procedural interface; use the companion and remaster scenes above for the new editing workflow.

## Verify a change

Save the scene/resource, stop the running game, and start it again. Check the altered object in the same mode where players will see it, including compact town and an expanded management panel. For battle art, deploy once so idle, movement, attack, and death poses are exercised.

The automated scene/resource edit checks run with:

```powershell
& '<Godot executable>' --headless --path . res://tests/editor/editor_workflow_checks.tscn -- --test
```

They save modified scene/resource copies under `.godot`, reload them, and verify the changes survive startup. `--test` disables the legacy GameState save system; these checks use a separate companion save path. See [tests/README.md](../tests/README.md) for the gameplay and native-window checks.
