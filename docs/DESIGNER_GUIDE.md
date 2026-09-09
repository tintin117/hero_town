# Editing the Conquest companion

The main menu opens `conquest/companion.tscn`. Open that scene to edit the playable town. This guide supersedes older prototype/remaster architecture notes for the active companion.

## Arrange the level

- Paint `Settlement/Terrain` TileMap layers. Runtime no longer repaints cells or offsets terraces. The existing 2,880-unit landscape is baked into the scene.
- Move building instances under `Settlement/TownDistrict`. Their `Visual`, `Hit`, `Activity`, and `PopupAnchor` children move together. The barracks also owns its training sprites. The academy switches between its authored built and locked visuals.
- Move or duplicate resource spots and villagers under `Settlement/WorkingHamlet`, or place them elsewhere under `Settlement`. Registration searches all descendants.
- Move the markers under `TownDistrict/Anchors` to reposition armies, spells, and damage numbers. Set formation columns, spacing, and unit scenes on the level root.
- To extend the town, paint more terrain and increase the root's **Land Width**. Scrolling uses this authored width; it does not create more tiles.

Use Godot's **Editable Children** on instances to adjust hit rectangles, work markers, textures, or animations. Edit a source scene to update every instance; use an inherited scene for a reusable visual variant. Ordinary decoration needs only Sprite2D or AnimatedSprite2D nodes.

## Add a resource spot or villager

1. Instantiate `conquest/units/wood_spot.tscn`, `gold_spot.tscn`, or `food_spot.tscn`. Set a unique **Spot ID**, a readable **Display Name**, and **Capacity** (one by default).
2. Move the root, resize `Hit`, and place `WorkPosition` where the worker should stand. Change `Visual`'s SpriteFrames for new artwork.
3. Expand **Gathering** in the Inspector. Choose **Make Unique** before changing the yield or cycle time for only this spot. The shared defaults are five units every ten seconds.
4. Instantiate `conquest/units/villager.tscn`. Give it a unique **Villager ID**, display name, starting position, and **Initial Spot ID**. An empty initial spot means idle. Its SpriteFrames contain `idle`, `walk_wood/gold/food`, and `work_wood/gold/food`; keep these animation names when replacing art.
5. Start a fresh game to check initial assignments. Existing saves retain their assignments; newly added villagers start idle and can be assigned through the picker.

IDs are save identities, not node names. Renaming or moving a node is safe; changing its ID creates a different entity. Never reuse an existing ID for a different object. Invalid settings and duplicate IDs produce runtime warnings. Missing destinations leave workers idle; reduced capacities retain workers in sorted villager-ID order.

Click a spot to select a villager. Click its current worker's **Unassign** row to free a full spot, then assign another worker. Transfers reset partial gathering progress. Movement is cosmetic and travels directly to the marker without obstacle navigation; production starts immediately and does not depend on distance.

Wood and food are currently stockpiles. Mining adds to gold alongside existing passive income. Purchases remain gold-only. Gathering continues through battles and taskbar mode; closing the application preserves partial cycles and earns nothing while closed.

## Tune difficulty and progression

Select the level root's **Balance** resource, normally `conquest/data/default_balance.tres`. It exposes starting inventory, warrior count, costs, training/research durations, passive income, combat stats, spell strength and interval, battle presentation, and recovery. Starting values apply to new games; existing saves retain player progress.

To add an encounter, duplicate a resource such as `conquest/data/meadow.tres`, change its name, hint, enemy count/HP/attack, income and plot reward, then append it to Balance's **Encounters** array. Progression follows array order. Append encounters to preserve existing save progression; reordering existing encounters changes the meaning of conquered land indices.

Resources are shared by default. **Make Unique**, or save a duplicate `.tres`, when experimenting with one level or spot. Never store live inventory or assignments in a Resource. The full-window Conquest view uses the same default balance and supports its own exported Balance override.

Buildings use the existing home, barracks, academy, army, and frontier actions. Adding a new-looking building with one of these actions requires no code. Entirely new actions or currencies require a behavior change; duplicating a barracks does not create another independent training queue.

## Edit UI and understand the code boundary

`conquest/ui/hud.tscn` owns the resource display and desktop controls; `popup.tscn` owns titles, body, action layout, and the scrollable villager picker. `action.tscn` defines a generated action/assignment row, and `theme.tres` defines their common appearance. Containers lay out changing content. Desktop code adjusts the window and keeps navigation reachable across monitor sizes.

Scene scripts handle local behavior and emit signals. `companion.gd` connects scene instances to `conquest_state.gd`, which owns inventory, assignments, gathering timers, and campaign simulation. Its `register_gathering()` receives IDs/settings, `assign_villager(id, target)` validates transfers (empty target unassigns), and `gathering_changed` refreshes views. Live state is saved separately from authored scenes and settings. Saved battles retain their duration, enemy count, and encounter name.

## Verify changes

Run these from the project directory with your Godot executable. Set `APPDATA` to an absolute directory inside `.godot` for each test run, keeping all autoload and test saves away from real progress. Supply an absolute `--log-file` path inside `.godot` as well.

```powershell
$env:APPDATA = Join-Path (Get-Location) '.godot/designer-test'
godot --headless --path . --log-file "$PWD/.godot/rules.log" --script conquest/checks.gd
godot --headless --path . --log-file "$PWD/.godot/gathering.log" --script conquest/gathering_checks.gd
godot --path . --rendering-method gl_compatibility --log-file "$PWD/.godot/designer.log" --script conquest/designer_checks.gd
godot --path . --rendering-method gl_compatibility --log-file "$PWD/.godot/companion.log" --script conquest/companion_checks.gd
godot --path . --rendering-method gl_compatibility --log-file "$PWD/.godot/menu.log" --script tests/main_menu_checks.gd
```

`designer_checks.gd` demonstrates moving a building, editing terrain, adding a differently tinted spot with a unique yield, adding a fourth villager, and appending an encounter. It checks assignment buttons, unchanged authored placement, and gathering in taskbar mode. Native desktop checks require a graphical session. Confirm the printed success markers and absence of script errors; an engine exit code alone is not sufficient for assertion-based scripts.
