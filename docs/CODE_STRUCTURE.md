# Hero Town — Code Structure & Runtime Flow

This document describes how the game actually boots and runs today, and what every
`.gd` script in the active (non-archived) codebase does. It reflects the real state
of the project as read from `project.godot`, the scene files, and the scripts —
not the aspirational file list in `CLAUDE.md`.

Scope: `scenes/`, `scripts/`, `vfx/`, `tests/`, `data/`. `addons/` (third-party/plugin
code) is out of scope except for a one-line mention of what it is. There is no
archived-prototype folder anymore — the pre-2D-port `bck/` Node2D prototype and the
old `test_3d_prototype.tscn` 3D board were both deleted once the 2D rebuild landed;
`scenes/town_2d.tscn` is the one and only game scene.

---

## 1. Boot sequence

Godot reads `project.godot` on launch:

```
run/main_scene = "res://scenes/main_menu.tscn"

[autoload]
GameData            = scripts/game_data.gd
GameState           = scripts/game_state.gd
fx                  = vfx/fx.gd
sfx                 = scripts/sfx.gd
_mcp_game_helper    = addons/godot_ai/runtime/game_helper.gd   (editor plugin, not gameplay)
```

Autoloads run first, before any scene node's `_ready()`, and stay alive for the
whole process. Load order is `GameData → GameState → fx → sfx → _mcp_game_helper`.

1. **`GameData`** (`scripts/game_data.gd`) scans `res://data/heroes/`,
   `res://data/enemies/`, `res://data/buildings/` for `.tres` resource files and
   loads them into three dictionaries keyed by each resource's `id`. This is the
   entire "database" of the game — 15 heroes, 6 enemies, 5 buildings today
   (`town_hall`, `portal`, `barracks`, `blacksmith`, `tavern`).
2. **`GameState`** (`scripts/game_state.gd`) holds the player's live save-state:
   just gold and shards (in-memory only, no persistence layer). Starts with
   `gold = 5000`, `shard = 500` (placeholder debug values, not tuned economy
   numbers). There is no owned-heroes roster anymore — see §6.
3. **`fx`** (`vfx/fx.gd`) is the global "juice" bus — screen shake, hit-stop,
   damage-number popups, particle effects. Any script can call `fx.spawn(...)`,
   `fx.shake(...)`, etc. from anywhere without a node reference.
4. **`sfx`** (`scripts/sfx.gd`) is a tiny sound-effect bus: an 8-voice pool of
   `AudioStreamPlayer`s round-robins between a handful of one-shot sounds
   (`click`, `coin`, `hit`, `crit`, `place`, `error`, `summon`, `upgrade`), with a
   small random pitch jitter per play so repeats don't sound robotic. Called as
   `sfx.play("hit")` from anywhere.

Then `scenes/main_menu.tscn` loads and shows the menu.

### Menu → gameplay

`scripts/main_menu.gd` wires three buttons:

- **Play** → `get_tree().change_scene_to_file("res://scenes/town_2d.tscn")`
- **Compact** → resizes/repositions the OS window into a thin always-on-top
  transparent overlay strip (a "desktop pet" style mode), then loads the same
  `town_2d.tscn`.
- **Quit** → `get_tree().quit()`

`scenes/town_2d.tscn` is the actual, current game scene — a `Node2D` world built
on the Tiny Swords (Free Pack) CC0 asset pack.

---

## 2. The game scene (`town_2d.tscn`)

Node tree (relevant nodes only; buildings/heroes/enemies below the line are spawned
at runtime, not authored in the scene file):

```
Town2D (Node2D)
├─ Terrain (TileMapLayer)        — hand-painted grass/stone/water tiles
├─ TerrainLayer (Node2D)         — script: board_2d.gd (decorative rocks/clouds)
├─ GridSystem (Node2D)           — script: scenes/grid_system.gd
├─ PlacementController (Node2D)  — script: scenes/placement_controller.gd
├─ DayNight (CanvasModulate)     — script: scenes/day_night.gd
├─ HeroTownCamera (Camera2D)     — instance of hero_town_camera.tscn
├─ Music (AudioStreamPlayer)     — looping background track
├─ CanvasLayer                   — script: scenes/canvas_layer.gd  (all HUD/UI)
│   ├─ HBoxContainer/PlacementButton  — legacy "place building" icon button
│   ├─ Coin_HUD / Shard_HUD           — currency counters
│   ├─ VBoxContainer/ExpandButton     — the real "Place Building" pill (expand_button.gd)
│   ├─ BuildPopup             — instance of big_frame.tscn, script: build_menu_popup.gd
│   └─ BuildingPopup          — instance of small_frame.tscn, script: building_popup.gd
├─ <BuildingBase instances>      — town_hall, barracks, portal (spawned at _ready())
└─ <Hero / Enemy instances>      — spawned/despawned during play
```

### Runtime flow, start to finish

1. `GridSystem` resolves its `Terrain` TileMapLayer sibling in `_enter_tree()`
   (earlier than `@onready` would, since `board_2d.gd`'s `_ready()` calls
   `grid_to_world()` before `GridSystem`'s own `_ready()` would otherwise have
   run), then `_ready()` builds a translucent hover-highlight sprite. The grid is
   a fixed logical size (`grid_size`, `Vector2i(12, 5)` today); all coordinate
   math (`grid_to_world`/`world_to_grid`) goes through the `TileMapLayer`'s own
   `map_to_local`/`local_to_map` — there is no 3D raycast anywhere in this game.
2. `TerrainLayer` (`board_2d.gd`) scatters a handful of rocks in the border/water
   ring around the playable board and a few slow drifting cloud-shadows over the
   water; the actual grass/stone/water tiles are hand-painted directly on the
   `Terrain` layer, not generated.
3. `PlacementController._ready()` immediately spawns the **prebuilt buildings**
   (`town_hall` at cell (1,2), `barracks` at cell (3,2)) and a **portal** at the
   rightmost column, via `_spawn_building()`. Each spawned `BuildingBase` is
   registered on the grid and passed to `CanvasLayer.connect_building()`, which
   hooks its `clicked`/`auto_spawn_requested` signals — and, specifically for the
   Barracks, immediately spawns its first hero (see step 7).
4. `CanvasLayer._ready()` wires the build/upgrade popups' signals to game logic
   and initializes the currency HUD from `GameState`. There's no hero-select UI
   and no separate "starting hero" grant anymore — a hero-producing building
   spawns its own starting hero the moment it exists (step 7).
5. **Building a new building:** Player clicks "Place Building" →
   `CanvasLayer._on_placement_button_pressed()` builds an options list from
   `GameData.BUILDINGS` (filtered to buildable types, i.e. non-negative cost)
   and shows `BuildMenuPopup`. Picking one emits `build_requested` →
   `CanvasLayer._on_build_requested` → `PlacementController.start_placement()`,
   which spawns a non-colliding "ghost" building that follows the hovered
   cell (tracked from mouse-motion events, converted to a grid cell every
   frame). Left-click on a free, affordable cell confirms the placement
   (spends gold, spawns the real building); right-click cancels.
6. **Moving a building:** Clicking an existing building emits `clicked` →
   `CanvasLayer._on_building_clicked` opens `BuildingPopup`. Its "Move"
   button emits `move_requested` → `PlacementController.start_move()`, which
   reuses the same ghost-drag flow but drags the existing node instead of
   instantiating a new one.
7. **Barracks / hero upgrade tree:** `BuildingPopup`, opened on a hero-producing
   building (today, just `barracks`, tied to the Warrior class), shows the
   currently active hero (whichever `HeroData` matches the building's class and
   current rarity `tier`), its live squad size, and any stat buffs accumulated
   so far. Pressing "Upgrade" spends gold per the level cost, calls
   `building.upgrade()`, then rolls 3 weighted-random reward offers from the
   building's `reward_pool` (`BuildingBase.roll_reward_offers()` — dropping
   "unlock next tier" once no higher rarity is authored for that class) and
   shows them as pick-one buttons. Picking one calls `building.apply_reward()`
   (bumps `tier`, or `squad_count`, or multiplies a `stat_buffs` entry) and
   emits `hero_building_changed`, which `CanvasLayer._sync_hero_building()`
   uses to grow/shrink the building's live squad of `Hero` instances and
   re-derive stats on whichever squad members already existed. There is no
   RNG hero-collection/gacha shop anymore — see §6 for what this replaced.
8. **Portal / spawning enemies:** `BuildingPopup`, when opened on the portal,
   lists every `EnemyData` whose `tier` is unlocked by the portal's current
   level, with a "Summon" button (spends nothing, instant) and an "Auto"
   toggle per enemy type. Toggling Auto starts the building's own timer, which
   round-robins between every toggled-on enemy type up to the level's
   `active_slots` cap. Either path emits `spawn_requested` →
   `CanvasLayer._on_spawn_requested`, which instantiates `enemy.tscn`, sets its
   combat stats from the `EnemyData` row, and drops it near the portal.
9. **Combat:** Heroes and enemies are both `Character` subclasses
   (`CharacterBody2D`). Each independently chases the nearest member of the
   opposing group (`heroes`/`enemies` node groups) and auto-attacks on contact —
   there is no manual combat input, per the GDD's hard cuts. Ranged units fire a
   travel-time `SkillHit` projectile instead of hitting instantly. Every hit
   also charges `mana` toward an optionally-equipped `SkillData`; once full it
   auto-casts (an AOE or projectile `SkillHit`) and resets. On death,
   `Enemy._on_death()` grants gold/shards to `GameState` and spawns a
   `coin.tscn` collect animation that flies to the currency HUD; a downed
   `Hero` instead falls over and revives at full HP after `revive_delay`
   seconds (heroes are meant to be a standing squad, not permanently lost).
10. **Currency HUD:** `CanvasLayer` listens to `GameState.currency_changed` and
    keeps the gold/shard labels in sync, with a little floating "-N" popup on
    spends.

---

## 3. Autoload scripts (global singletons)

### `scripts/game_data.gd` — `GameData`
Static content database. On `_ready()`, walks the three `data/*` folders and
loads every `.tres` into a `Dictionary` keyed by `id`:
- `HEROES: Dictionary` — `HeroData` resources (15 rows, `data/heroes/h001.tres`…)
- `ENEMIES: Dictionary` — `EnemyData` resources (6 rows)
- `BUILDINGS: Dictionary` — `BuildingData` resources (5 rows: `town_hall`,
  `portal`, `barracks`, `blacksmith`, `tavern`)

Function: `_load_dir(path) -> Dictionary` — generic loader used for all three.

### `scripts/game_state.gd` — `GameState`
Player's mutable save-state (in-memory only, no persistence layer). As of the
building-upgrade-tree rework, this is *just currency* — hero power/ownership now
lives entirely on the `BuildingBase` that produces each hero (see §4, §6).
- `gold: int`, `shard: int`
- `signal currency_changed(gold, shard)` — emitted on every spend/add
- `can_afford(gold_cost, shard_cost = 0) -> bool`
- `spend(gold_cost, shard_cost = 0) -> bool` — returns false and does nothing
  if unaffordable, otherwise deducts and emits the signal
- `add(gold_amount, shard_amount = 0)` — grants currency and emits the signal

### `vfx/fx.gd` — `fx`
Global game-feel/VFX bus, see [Section 7](#7-vfx-system-vfx). Not tied to any
one scene — call it from any script via the autoload name `fx`.

### `scripts/sfx.gd` — `sfx`
Global one-shot sound-effect bus (see §1, item 4). Not tied to any scene — call
`sfx.play("name")` from anywhere.

---

## 4. Core gameplay scripts (`scenes/`)

### `scenes/grid_system.gd` — class `GridSystem`
Owns the fixed-size 2D placement grid and its hover-highlight visual, backed by
the `Terrain` `TileMapLayer` sibling for all coordinate math.
- `grid_size: Vector2i` (`@export`, default `(12, 5)`) — cols × rows of the
  buildable area.
- `grid_to_world(cell) -> Vector2` / `world_to_grid(world_pos) -> Vector2i` —
  thin wrappers over the `TileMapLayer`'s own `map_to_local`/`local_to_map` +
  `to_global`/`to_local`, the two coordinate conversions everything else builds
  on. `world_to_grid` returns `Vector2i(-1, -1)` for any cell outside
  `grid_size`.
- `is_free`, `occupy`, `clear` — occupancy bookkeeping over a `Vector2i -> occupant`
  dictionary (no fixed-size array — the grid isn't bounded by a mesh anymore).
- `set_overlay(on)` / `set_highlight_color(valid)` — show/hide and tint the
  hover-highlight sprite during placement.
- `_unhandled_input` tracks the latest mouse position from motion events;
  `_process()` converts it to a grid cell every frame and repositions the
  highlight. (Tracked from input events rather than polled directly from the
  OS cursor, so synthetic input in tests behaves identically to a real mouse.)

### `scenes/board_2d.gd` (node name `TerrainLayer`)
Purely decorative: scatters ~12 rock sprites in the border/water ring just
outside the playable grid (never on it), and a handful of slow-drifting
translucent cloud-shadow sprites over the water. A seeded `RandomNumberGenerator`
keeps the layout stable across runs.

### `scenes/day_night.gd` (node type `CanvasModulate`)
Simple sine-wave day/night color tint cycle (the 2D replacement for an earlier
3D sun/moon rig) — lerps between a night-blue and daylight-white `Color` over an
8-minute loop, offset so the game always boots into daylight.

### `scenes/hero_town_camera.gd` — class `HeroTownCamera extends Camera2D`
The board-view camera: WASD pans, mouse-wheel zooms, middle-mouse-drag pans —
all smoothed toward a target position/zoom, clamped to a fixed pan range and
zoom range sized to the 12×5 board.

### `scenes/building_base.gd` — class `BuildingBase`
The script behind `building_base.tscn`, instanced for every building (town
hall, barracks, portal, tavern, blacksmith all share this one scene). A
`Node2D`, not a 3D node.
- `@export building_id: String` — key into `GameData.BUILDINGS`.
- `get_data() -> BuildingData` — looks itself up in `GameData.BUILDINGS`.
- `current_level: int` — generic level counter, `upgrade()` increments it and
  plays a squash/stretch tween; also restarts the portal's auto-spawn timer at
  the new level's `spawn_interval` if any enemy type is toggled on.
- `toggle_auto_spawn(enemy_id)` / `_on_spawn_timer_timeout()` /
  `on_enemy_defeated()` — the portal's round-robin auto-summon loop, capped at
  the current level's `active_slots`.
- **Hero-tree state and API** (only meaningful when `get_data().hero_class` is
  set, e.g. the Barracks): `tier: int` (a `HeroData.Rarity` index — which
  rarity of this building's class is currently active), `squad_count: int`
  (how many copies fight at once), `stat_buffs: Dictionary` (stat name →
  cumulative multiplier, from past `stat_buff` rewards).
  - `active_hero_id() -> String` — the `HeroData.id` whose `hero_class` and
    `rarity` match this building's class and `tier`.
  - `roll_reward_offers() -> Array[Dictionary]` — weighted-picks up to 3
    distinct entries from `BuildingData.reward_pool`, dropping `"tier_up"`
    once there's no next rarity authored for this class.
  - `apply_reward(reward: Dictionary)` — applies a picked reward: `"tier_up"`
    increments `tier`, `"count_up"` increments `squad_count`, `"stat_buff"`
    multiplies the named stat's entry in `stat_buffs`.
- `_ready()` — applies the building's sprite texture anchored feet-first
  (bottom-center at the tile origin, matching `Character`'s convention), fits
  an `Area2D`/`RectangleShape2D` collider to the sprite's actual pixel bounds
  (`_fit_collision_to_sprite`), and registers itself on the `GridSystem`.
- `_on_area_input_event` — click detection via `Area2D` (2D physics picking);
  emits `clicked`, with a `suppress_next_click` guard so confirming a "move"
  doesn't re-open the popup on the same physics frame.

### `scenes/placement_controller.gd`
Drives the drag-to-place / drag-to-move UX (no `class_name` — accessed by node
path, not by type).
- `PREBUILT_BUILDINGS` — the buildings placed automatically at scene start
  (`town_hall`, `barracks`); the portal is spawned separately in `_ready()` on
  the last grid column. Unlike the old 3D setup, there's no grid-fitting step
  to wait on — buildings spawn immediately.
- `start_placement(data: BuildingData)` — begins placing a brand-new building:
  spawns a non-colliding ghost that tracks `grid_system.hovered_cell`.
- `start_move(building: BuildingBase)` — begins relocating an existing
  building: clears its old grid cell, disables its collider, and reuses the
  same ghost-follow logic with the real node as the "ghost".
- `_unhandled_input` — left-click on a free cell confirms placement/move
  (spending gold for new builds); right-click cancels either.
- `_cancel_placement` — restores a moved building to its original cell, or
  frees a not-yet-placed ghost.

### `scenes/canvas_layer.gd`
The HUD/UI controller — owns all popups and wires their signals to game
logic (no `class_name`, root of the `CanvasLayer` node in the game scene).
- Connects `BuildMenuPopup.build_requested`, `BuildingPopup.move_requested`,
  `BuildingPopup.spawn_requested`, `BuildingPopup.hero_building_changed`, and
  `GameState.currency_changed`.
- `connect_building(building)` — called once per spawned `BuildingBase` so its
  `clicked` signal opens `BuildingPopup`; if the building is the Barracks, this
  is also where its first hero gets spawned (via `_sync_hero_building`).
- `hero_instances: Dictionary[BuildingBase, Array[Hero]]` — the live squad per
  hero-producing building (was a flat `hero_id -> Hero` map before the
  building-tree rework, since only one copy of each hero could ever exist).
- `_sync_hero_building(building)` — grows/shrinks a building's squad to match
  its current `squad_count` (spawning/freeing `Hero` instances via
  `_spawn_hero`), and re-derives `hero_data`/stats on every already-alive
  member (so a `tier_up` or `stat_buff` reward takes effect on heroes already
  on the field, without touching their current HP).
- `_spawn_hero` / `_on_spawn_requested` — the only two places that instantiate
  `hero.tscn` / `enemy.tscn` at runtime, setting combat stats directly from
  the relevant `HeroData`/`EnemyData` row (a `Hero` also gets a
  `source_building` reference so it knows whose `stat_buffs` apply to it).

### `scripts/character.gd` — class `Character` (`extends CharacterBody2D`)
Shared base class for both `Hero` and `Enemy`. All combat logic lives here;
subclasses only decide *who to chase* and a couple of small behavior hooks.
- State machine: `MOVE → COMBAT → KNOCKBACK → DEAD` (enum `State`).
- `max_hp`/`atk`/`atk_speed`/`mana_per_hit` are plain (non-exported) fields,
  always set from `HeroData`/`EnemyData` at spawn time — never edited directly
  in the Inspector. `@export move_speed`/`attack_range`/`skill` (an optional
  `SkillData` this character can cast) are exported.
- `AnimatedSprite2D`-driven visuals: `_get_sprite_frames()` (virtual, returns a
  `SpriteFrames` built by `Art.hero_sprite_frames`/`Art.enemy_sprite_frames`),
  `_play_anim`/`_play_action` pick idle/run/attack clips, feet-anchored via a
  per-frame-height offset (units vary — e.g. the Lancer's frame is much taller
  than the others).
- `_chase_and_engage(opponent_group)` — steers toward the nearest `Character`
  in the given node group (weighted by distance plus a same-target-crowding
  penalty, so allies spread across multiple enemies instead of dog-piling one),
  blended with a boids-lite `_separation_force` from same-group allies, or
  calls `_enter_combat` once in range. This is the one method subclasses call
  from their `_update_move` override.
- `_enter_combat` / `_exit_combat` — starts/stops a per-instance attack
  `Timer` (interval = `atk_speed`).
- `_on_attack_timeout` — fires on the timer; rolls a crit
  (`CRIT_CHANCE`/`CRIT_MULT`), then either hits `target` directly (melee) or
  fires a `SkillHit` projectile (ranged, via `_fire_projectile`), and charges
  mana toward an equipped skill.
- `_charge_mana` / `_cast_skill` — accrues `mana_per_hit` on every hit dealt or
  taken; once it reaches the equipped `SkillData.mana_cost` (and any cooldown
  has elapsed), resets to 0 and casts a `SkillHit` (AOE in place, or a
  projectile toward `target`).
- `take_damage(amount, attacker)` — applies damage, updates the health-bar
  fill, triggers a hit-flash/squash juice tween, and on death sets
  `state = DEAD`, calls the `_on_death()` hook, emits `died`, and calls `_die()`.
  Otherwise may apply knockback via `_should_knockback` (virtual, overridable
  per subclass).
- `spawn_fx(value, crit, screen_shake)` — calls `fx.spawn("impact_spark", ...)`,
  optionally `fx.shake`, `fx.hitstop`, `fx.popup(...)` for the floating damage
  number, and `sfx.play(...)`.
- Virtual/override points subclasses use: `_update_move`, `_idle_move`,
  `_should_knockback`, `_on_death`, `_die`, `_get_sprite_frames`,
  `get_own_group`.
- Movement is clamped every frame to a fixed `PLAYFIELD_MIN/MAX_X/Y` rectangle
  matching the board size.

### `scripts/hero.gd` — class `Hero extends Character`
- Joins the `"heroes"` group.
- `@export source_building: BuildingBase` — the hero-producing building whose
  `tier`/`stat_buffs` this instance's stats derive from.
- `apply_hero_data()` — (re)applies `hero_data`'s base stats times whatever
  multiplier `source_building.stat_buffs` has for each stat (`max_hp`, `atk`,
  `atk_speed`); safe to call any time after spawn (e.g. after a reward is
  picked) without touching current HP. Replaced the old
  star-multiplier/class-buff lookup against `GameState`.
- `_update_move` → `_chase_and_engage("enemies")`.
- `_idle_move` → `_patrol()` between `patrol_start_x`/`patrol_end_x` when no
  enemy is in the world (idle back-and-forth walk).
- `_should_knockback` → only bosses (`Enemy.is_boss`) can knock a hero back.
- `_die()` → falls over, plays dead for `revive_delay` seconds, then
  `_revive()` pops back up at full HP — heroes are a standing squad, not
  permanently lost on defeat (unlike enemies).

### `scripts/enemy.gd` — class `Enemy extends Character`
- Joins the `"enemies"` group.
- `@export is_boss`, `@export enemy_data: EnemyData` — every `Enemy` is
  portal-spawned (see `canvas_layer.gd`) so this is always set; there's no
  hand-placed/data-less enemy anymore.
- `_update_move` → `_chase_and_engage("heroes")`.
- `_on_death` → grants a random gold/shard amount (from `enemy_data`'s
  min/max range) to `GameState`, spawns a `coin.tscn` collect animation, and
  triggers a hit-burst/white-flash.
- `_die` → fades and sinks away, then frees (overrides `Character`'s default
  immediate free with a small tween).

### `scripts/skill_hit.gd` — class `SkillHit extends Area2D`
The shared hit/projectile hitbox used both for ranged basic attacks
(`Character._fire_projectile`) and skill casts (`Character._cast_skill`).
Stationary (AOE, damages on overlap or on a repeating `tick_interval`) when
`speed == 0`, otherwise travels along `direction` at `speed` like a projectile.
Filters targets by `target_group` ("heroes/enemies", whichever opposes the
caster) and never hits its own caster.

### `scenes/coin.gd`
Cosmetic-only: a `Node2D` that pops in, hops up, then tweens itself to the
currency HUD's coin icon and fades out, bumping the currency label and playing
a coin sound/sparkle on arrival. Spawned by every `Enemy._on_death()` (via
`Enemy.spawn_coin()`), not tied to `GameState` itself.

### `scenes/expand_button.gd` — class-less `@tool extends Button`
The "Place Building" pill in the HUD: collapsed to an icon-only button, expands
to icon+label on hover (with a short delay before collapsing back). Exposes its
colors/sizes/corner-radius as `@export`s with an editor-time preview toggle.

### `scenes/animation_button.gd` — class `AnimationButton extends TextureButton`
Small hover/focus polish: scales/brightens on `mouse_entered`/`focus_entered`,
reverts on exit. Used by the main menu's Play/Compact/Quit buttons and by the
building popup's Upgrade/Move/Close icon buttons.

### `scripts/main_menu.gd`
See [Section 1](#1-boot-sequence) — Play/Compact/Quit handlers.

---

## 5. UI popup scripts (`scripts/`)

### `scripts/build_menu_popup.gd`
Backs `build_menu_popup.tscn`. `show_options(options: Array)` rebuilds a list
of `UI_building_item.tscn` rows (one per buildable `BuildingData`, thumbnail +
cost), disabling any the player can't afford. Picking one emits
`build_requested(building_type)` and hides itself.

### `scripts/UI_building_item.gd` — class `BuildingItem extends Button`
Backs `UI_building_item.tscn`, one row in the "choose a building" grid.
`setup(texture, name, price, can_afford)` fills in the row with sane fallbacks
for missing/invalid data, dims and disables itself when unaffordable, and runs
a small looping glow-pulse tween on hover/focus.

### `scripts/building_popup.gd`
Backs `building_popup.tscn`. The single popup used for *every* building type
— title/level/upgrade button are generic, and `_refresh()` branches on
`building.building_id` to append type-specific content:
- **portal** → `_refresh_enemy_list` — lists summonable enemies up to the
  portal's unlocked tier, each with "Summon" and "Auto" buttons
  (`spawn_requested`).
- **barracks** (any hero-producing building) → `_refresh_hero_building_content`
  — shows the building's current active hero/tier and squad size, any
  accumulated `stat_buffs`, and — right after an upgrade has just been paid
  for — the 3 reward-choice buttons from `building.roll_reward_offers()`.
  `_on_upgrade_button_pressed` additionally rolls those offers for hero
  buildings; `_on_reward_picked` applies the chosen one
  (`building.apply_reward()`) and emits `hero_building_changed`.
- any other building (town hall, blacksmith, tavern) → `_refresh_level_info` —
  no bespoke effect code, just a generic dump of the current/next `levels[]`
  dict entries and the upgrade cost.
`_on_upgrade_button_pressed` spends gold per `BuildingData.levels[level].cost`
and calls `building.upgrade()`. `move_requested` is emitted by the Move
button and handled by `CanvasLayer`.

---

## 6. Data model (`scripts/resources/`, `data/`)

Four plain `Resource` subclasses define the schema for the `.tres` content
files `GameData` loads (three) plus one used directly by `Character` (the
fourth, `SkillData`). There is no separate runtime stats class — a spawned
`Character`'s combat fields (`max_hp`, `atk`, `atk_speed`, `move_speed`,
`attack_range`, `mana_per_hit`) live directly on the node itself and are set
from the matching `HeroData`/`EnemyData` row at spawn time (see
`Hero.apply_hero_data()` / `Enemy._ready()` / `canvas_layer.gd`'s
`_spawn_hero`/`_on_spawn_requested`).

| Script | class_name | Fields | Backing files |
|---|---|---|---|
| `scripts/resources/hero_data.gd` | `HeroData` | id, display_name, rarity, hero_class, unit_type, base_power, power_per_level (unused — no per-hero leveling anymore), base_hp, atk_speed, mana_per_hit | `data/heroes/h001–h015.tres` |
| `scripts/resources/enemy_data.gd` | `EnemyData` | id, display_name, tier, unit_type, hp, atk, spawn_time (unused by any code today), gold_min/max, shard_min/max | `data/enemies/e001–e006.tres` |
| `scripts/resources/building_data.gd` | `BuildingData` | id, display_name, build_cost, unlock_th_level (unread by any code — a dead gate, same status as before), thumbnail, sprite_texture, model_scene (unused, pre-2D leftover), levels (Array[Dictionary] — per-level cost/tier/spawn data), hero_class + reward_pool (only meaningful for hero-producing buildings) | `data/buildings/{town_hall,portal,barracks,blacksmith,tavern}.tres` |
| `scripts/resources/skill_data.gd` | `SkillData` | mana_cost, damage, shape (AOE/PROJECTILE), radius, projectile_speed, duration, tick_interval, cooldown | optionally referenced by a `Character.skill` export; not loaded via `GameData` |

`HeroData`/`EnemyData`/`BuildingData`/`SkillData` are static design content,
read-only at runtime — nothing ever mutates the loaded `.tres` resources, only
the live `Character`/`BuildingBase` fields copied from or derived alongside them.

### What replaced the old hero-acquisition system

Earlier versions of this game had a Shrine building with a reroll-shop gacha and
a per-hero "star" that duplicates could merge up to (`GameState.owned_heroes`,
`GameState.buy_hero`, `Hero.STAR_STAT_MULT`, `CLASS_BUFFS`). That's gone. Hero
power now comes entirely from upgrading the building that produces that hero
class (§2 item 7, §4's `BuildingBase` hero-tree API): a hero-producing
building's `tier` picks which rarity of `HeroData` is active, `squad_count`
picks how many copies fight at once, and `stat_buffs` accumulates flat percentage
bonuses — all chosen by the player from a 3-option reward roll each time that
building is upgraded, rather than acquired via RNG shop rolls. The corresponding
dead fields (`dupe_shard`, `upgrade_gold_base`, `upgrade_shard_base`,
`th_unlock`) have been removed from `HeroData`, and the old Shrine building
(`data/buildings/shrine.tres`, `scenes/shrine_popup.tscn`) no longer exists —
its former free-starter slot is now the Barracks.

---

## 7. VFX system (`vfx/`)

Small, self-contained game-feel layer, independent of gameplay logic.

### `vfx/fx.gd` — autoload `fx`
- `EFFECTS: Dictionary` — name → scene path registry (`impact_spark`,
  `shockwave`, `hit_flash`, `hit_burst`, `pickup_sparkle`, `smoke_pop`).
- `spawn(effect_name, global_pos, opts) -> FxEffect` — instantiates and
  configures a registered effect scene.
- `shake(strength, duration)` — tweens the viewport's active `Camera2D`'s pixel
  `offset` in a decaying random walk.
- `hitstop(duration, time_scale)` — briefly dips `Engine.time_scale` for a
  freeze-frame hit; re-entrant calls are ignored while one is in flight
  (`_hitstop_busy` guard).
- `flash(color, duration, max_alpha)` — full-screen color flash via a
  lazily-created top-layer `ColorRect`.
- `popup(text, global_pos, opts)` — the floating damage-number label (tween:
  scale-in, drift-up, fade, free). This is what `Character.spawn_fx` calls
  for every hit. Positions are plain world positions — the 2D world and its
  effect children already share one coordinate space, no camera/viewport
  conversion needed (unlike the old 3D setup).

### `vfx/fx_effect.gd` — class `FxEffect extends Node2D`
Base class every effect scene (`hit_burst.tscn`, `hit_flash.tscn`,
`impact_spark.tscn`, `shockwave.tscn`, `pickup_sparkle.tscn`,
`smoke_pop.tscn`) extends. Defines the play/stop lifecycle
(`play → _build (once) → _play → _duration timer → _on_done → optional queue_free`)
and a library of static texture/material-generation helpers (`make_dot_texture`,
`make_streak_texture`, `make_ramp`, `make_add_material`, `make_star_sprite`,
etc.) so individual effects don't each hand-roll gradient/particle textures.
Each concrete effect script under `vfx/effects/**/*.gd` overrides `_build`,
`_play`, `_duration`, and optionally `_apply_colors`/`_stop`/`_reset`.
`vfx/common/script/` holds a couple of small shared helper node scripts
(`vfx_controller.gd`, `vfx_light.gd`) some effects compose rather than
reimplement.

---

## 8. Legacy / unused / scratch code

Worth knowing about so it isn't mistaken for active systems:

- **`scenes/layer.gd`** — an earlier, simpler slot-based placement system
  (`occupied_slots`, `place_building(start, end, building)` operating on 1D
  integer slots along an X axis, `extends Node3D`). **Not referenced by any
  `.tscn` in the project** — it predates both `GridSystem`+`BuildingBase` and
  the 2D port. Safe to ignore/delete; not wired into `town_2d.tscn`.
- **`scripts/CONFIG.gd`**, **`scripts/CONFIG_Test.gd`**, **`scripts/SpriteHelper.gd`**
  — leftover pre-2D-port scratch: fixed 3D camera-angle constants and a
  `Node3D.rotation`-facing helper. Nothing in the current (2D) codebase
  references `CONFIG`/`CONFIGTEST`; `SpriteHelper` only references `CONFIG`
  internally. Dead.
- **`addons/godot_ai/`** — the MCP server plugin that lets Claude Code read
  and edit the Godot project live. Not gameplay code; don't modify.
- **`addons/ridiculous_coding/`** — a third-party "screen-shake while you
  type code" editor plugin (cosmetic developer-experience addon, unrelated
  to the game).

The pre-2D `bck/` archived prototype and the 3D scratch movement test
(`player_test_25.gd`, `test_25_camera.gd`, `level_test_25.tscn`) mentioned in
older notes have been deleted outright — they no longer exist in the repo at
all (only a couple of stale `.godot/editor/*.cfg` cache files still name
`level_test_25.tscn`; harmless, editor-generated, not source).

---

## 9. Tests (`tests/`)

### `tests/test_grid_system.gd`
A `@tool`, `McpTestSuite`-based unit test (run via the Godot AI plugin's test
runner) covering `GridSystem`'s pure coordinate math in isolation (builds a
standalone `GridSystem` + `TileMapLayer` pair, never added to the scene tree):
- `test_grid_to_world_round_trip` — `grid_to_world` → `world_to_grid` returns
  the original cell for every row × {0, 4, 9} column.
- `test_world_to_grid_out_of_bounds` — a far-away world position resolves to
  the `Vector2i(-1, -1)` sentinel.
- `test_occupancy` — `is_free`/`occupy`/`clear` behave as a basic
  read-after-write occupancy map.

---

## 10. Quick reference: script → responsibility

| Script | Responsibility |
|---|---|
| `game_data.gd` | Load static content (heroes/enemies/buildings) from `.tres` files |
| `game_state.gd` | Player's live gold/shard currency |
| `main_menu.gd` | Menu button handlers, scene transition into the game |
| `grid_system.gd` | Grid math (via the Terrain TileMapLayer), occupancy, hover highlight |
| `building_base.gd` | Per-building instance: sprite, collider, click, level, hero-tree state (tier/squad/buffs) |
| `placement_controller.gd` | Ghost-drag placement & move UX |
| `canvas_layer.gd` | HUD wiring: popups ↔ game logic, currency labels, hero-squad spawning/syncing |
| `build_menu_popup.gd` | "Choose a building to build" popup |
| `UI_building_item.gd` | One row in the build-menu popup |
| `building_popup.gd` | Per-building detail popup: upgrade, summon, hero-tree reward picks |
| `board_2d.gd` | Decorative rocks/clouds around the playable board |
| `day_night.gd` | Day/night color-tint cycle |
| `hero_town_camera.gd` | Pan/zoom board camera |
| `expand_button.gd` | "Place Building" hover-expand pill button |
| `animation_button.gd` | Hover/focus button polish |
| `character.gd` | Shared combat state machine + stats for heroes & enemies |
| `hero.gd` | Hero-specific chase/patrol/revive behavior, building-driven stats |
| `enemy.gd` | Enemy-specific chase/wander behavior, death rewards |
| `skill_hit.gd` | Shared AOE/projectile hitbox for basic ranged attacks and skill casts |
| `coin.gd` | Cosmetic coin-collect animation on enemy death |
| `hero_data.gd`, `enemy_data.gd`, `building_data.gd`, `skill_data.gd` | Data schemas |
| `fx.gd`, `fx_effect.gd`, `vfx/effects/**` | Screen shake, hit-stop, damage popups, particles |
| `sfx.gd` | One-shot sound-effect bus |
| `layer.gd`, `CONFIG.gd`, `CONFIG_Test.gd`, `SpriteHelper.gd` | Unused pre-2D-port legacy code |
