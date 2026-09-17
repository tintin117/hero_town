# Desktop companion

Press **F5** for the main menu, then **Resume** or **New Game**. Disable Godot’s **Embed Game on Play** so the game can position its native transparent window. For scene and balance changes, see the [editor workflow](EDITOR_WORKFLOW.md); for a fresh run without player saves, use `game/previews/companion_preview.tscn` with **F6**.

## Controls

The town sits above the Windows taskbar and spans the current monitor’s usable width. Roll the mouse wheel or use arrow keys to scroll across the authored 2880-pixel landscape. Gold and window controls stay fixed. Scrolling pauses while a management panel is open.

Click the castle, barracks, academy, army, or frontier tower to manage it. The frontier panel previews expedition rewards. Gold opens the retained return/battle report. Close a panel with its x or Escape. Panels expand the same window upward. Empty space outside the native input polygon passes through to the desktop.

The lower-right controls open the frontier, drag the window, dock it, fold it into taskbar sparring, and save/close. In sparring mode, click the characters to restore town; drag them horizontally to reposition along the current monitor’s taskbar edge. Sparring and worker loops are cosmetic. Income, training, recovery, and expeditions continue while the game remains open.

Yellow combat numbers show damage to enemies, red numbers damage to your army, and green numbers healing. Building indicators show activity without exposing internal project names. The visible troop count is capped for readability; all trained troops participate in combat calculations.

## Editing

`game/companion/companion.tscn` owns static composition, HUD, building groups, actor templates, and the window’s exported presentation settings. `terrain.tscn` contains paintable TileMapLayers. Keep the root’s **Land Width** and painted terrain consistent when extending the map. Terrain decoration does not alter campaign rules or plots.

`town_workers.tscn` and `taskbar_sparring.tscn` expose their own animation and timing settings. `data/companion/default_balance.tres` holds economy, training, combat, pacing, and expedition values. Preview overrides are suitable for experiments; edit the base scene or shared balance to affect normal gameplay.

## Saves

The companion uses `user://conquest_companion_v1.json`. New Game preserves the previous companion save in a `.previous` backup. On its first launch, a normal companion can seed from `user://conquest_v1.json`, the full-window prototype’s save; later progress remains independent. The **Seed From Full Window** and **Persistence Enabled** Inspector fields control this behavior.

Closing completely pauses training, battles, recovery, and gold income. Reopening resumes saved remaining time without offline catch-up. A deployed battle’s result and presentation are saved together to prevent duplicate rewards.

The old full-window scene remains at `prototypes/full_window_conquest/conquest.tscn`. It shares campaign rules and balance while retaining its procedural UI.

## Verification

Use the companion, return, menu, and editor workflow checks listed in [tests/README.md](../tests/README.md). Native window checks require Windows; they cannot establish behavior on every DPI/driver combination. Captures and test saves are generated under `.godot/`, outside the authored project folders.
