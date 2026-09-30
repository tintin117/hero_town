# Fight club — architecture contract

Companion to [GAME_DESIGN.md](GAME_DESIGN.md). Every module (and every parallel agent) codes against this file. Change it first, code second.

The old prototype lives at git tag `prototype-fight-club-v1`; read it with `git show prototype-fight-club-v1:game/fight.gd`. Combat numbers are verified against `game/tests/golden.json`, captured from that tag.

## 1. Layers and folders

```
game/
  main.tscn, main.gd   thin shell: shows MainMenu, then World + HUD. No rules, no drawing.
  data/                authored content as .tres; typed schemas in data/defs/*.gd
  core/                game_state.gd, events.gd (autoload "Events"), game.gd (autoload "Game"),
                       save_store.gd
  systems/             pure logic (RefCounted, static or instance): hype, economy, roster, fame,
                       manager, buildings, traits, stories, props, preview
  combat/              combat_sim.gd (pure), arena.tscn + arena.gd (presentation), combat_fx.gd
  town/                town.tscn, placement.gd
  ui/                  theme/, components/, hud.tscn, main_menu.tscn, drawers/, router.gd
  tests/               run_all.gd, test_*.gd, golden.json
```

| Layer | May depend on | Must not |
|---|---|---|
| `data/` | nothing | contain logic beyond simple getters |
| `systems/`, `combat/combat_sim.gd` | `data/`, `core/game_state.gd` | touch nodes, `Events`, or the scene tree |
| `core/game.gd` | systems, `Events` | reference UI or World nodes |
| `combat/arena`, `town/`, `ui/` | `Game` (commands + reads), `Events` (signals), `data/` | mutate `GameState`, compute rewards, call systems directly |

## 2. Data flow (one direction)

```
UI / input ──command──▶ Game ──▶ systems mutate GameState ──▶ Events.<signal> ──▶ UI / Arena / Town redraw
```

- **Commands** are the only writes. Each returns `bool` (or a small result Dictionary) and never throws for invalid requests.
- **Reads** go through `Game.state` (a `GameState` Resource) or pure query helpers on `Game` (`Game.can_afford(cost)`, `Game.preview(lineup)`). UI may read, never write.
- **Signals** describe what already happened. They carry the new value so listeners never poll.
- Sim time: `Game._physics_process(dt)` calls `advance(dt)` unless paused. Tests call `advance` directly.

## 3. Fight lifecycle

0. **Planting.** The player picks a lineup (`Game.toggle_lineup`, swap-when-full) and holds the arena to `Game.plant()` it (tap the arena opens the seed tray; the shell forwards Town `pressed`/`released` to `Hud.press_arena()`/`release_arena()`, and the HUD emits `plant_progress` for the arena's gold arc). Hype grows only while a lineup is planted; the series consumes it (`Game.planted`, `planted_changed`). Nothing is planted after a series, new game or load.
0. **Series (bo5, first to 3).** The bell rings by itself when hype reaches the manager threshold (default 70; there is no manual Book). It locks `attendance` for the whole series and plays bouts 1..n with a `series_pause` (3 s) of crowd chatter between them; each bout runs steps 1–3 below and pays as it finishes. The series ends at `series_wins` wins (fame bonus) or after `series_max_bouts` (draw guard, no winner). Hype falls to the last bout's afterglow when the series ends and grows only while idle. `Game.series` holds the running series; `Game.crowd_now()` is the locked crowd or what the bell would draw now.
1. **Bout start** (`Game.book_fight` rings the bell, `_start_bout` per bout): `hype`→`attendance`; `combat_sim.simulate(lineup, seed, mods)` runs the whole fight instantly and deterministically, returning `{events, result}`.
2. **Playback**: `Game` releases `events` by fight clock. Each event fires `Events.combat_event(e)`; a skill event pays its 10-gold tip when released. The Arena only replays events for display.
3. **Settle** when the last event is released: `economy.settle(result)` pays gold, XP, wins, fame, concessions, sets afterglow → `Events.fight_finished(result)`.

Skipping presentation gives identical outcomes (needed for offline progress later). Presentation effects never consume the sim RNG.

`simulate(lineup: Array[int], rng_seed: int, mods: CombatMods) -> Dictionary`
- `lineup`: hero ids with stats already snapshotted by the caller (`{id, def, level, traits}`).
- `mods`: `start_excitement`, `skill_excitement_mult`, `damage_mult` per hero, all default neutral.
- `lineup` entries are plain Dictionaries: `{id, name, red, ranged, health, attack, skill: {kind, power}}` with level scaling and trait effects already applied by the caller — `combat_sim` knows nothing about `data/` or `GameState`.
- returns `events: Array[Dictionary]` (kinds `move`, `attack`, `skill`, each with `t` seconds and the old field shapes: `attacker, origin, hits[{target, damage, position, push_to}], healing, radius, tip, excitement_gain, winner`) and `result: {winner, duration, excitement, tips, skills, attacks, hp_left: {id: hp}, tracks: {id: PackedVector2Array}}`. `tracks` holds each fighter's position at every 60 Hz step so the Arena can render without re-simulating. XP/level/wins are **not** in the result; `economy` derives them.
- Ported rules (unchanged numbers): 60 Hz fixed step, arena radius 260, attack interval 1.5, mana 25/15, cast tip 10, excitement 1/s (cap 20) + 8 per skill, multiplier 1 / 1.25 / 2.5 at 25 / 60, overtime after 60 s, level growth 5 %. Parity with `golden.json` is a G1 gate.

## 4. Signal contract (`Events` autoload)

| Signal | Args | Fired when |
|---|---|---|
| `gold_changed` | `gold: int, delta: int` | any gold change |
| `hype_changed` | `hype: float` | each sim step while hype moves (≤ 10 Hz) |
| `fame_changed` | `points: int, tier: int` | fame gained / tier crossed |
| `fight_booked` | `lineup: Array[int], main_event: StringName` | bell, before playback |
| `fight_started` | `info: Dictionary` (`lineup, attendance, seats, seed, duration`) | playback begins |
| `combat_event` | `event: Dictionary` | playback releases a sim event |
| `fight_finished` | `result: Dictionary` | one bout settled |
| `planted_changed` | – | a lineup was planted, uprooted or consumed by its series |
| `series_started` | `info: Dictionary` (`lineup, attendance, seats, wins_needed`) | the bell rings |
| `series_finished` | `result: Dictionary` (`winner` (-1 = unresolved), `wins`, `bouts`, `fame_bonus`) | a fighter reaches the win count |
| `roster_changed` | – | recruit, lineup or level change |
| `hero_changed` | `id: int` | one hero's XP / level / wins |
| `building_changed` | `id: StringName` | built, upgraded or moved |
| `story_changed` | `story_id: int` | created, ripened, cashed, cooled |
| `story_ripe` | `story_id: int` | ripeness reaches badge threshold |
| `prop_changed` | – | prop bought or selected |
| `manager_changed` | – | enabled / threshold changed |
| `toast` | `text: String, icon: StringName` | short user notice |
| `paused_changed` | `paused: bool` | menu open/close |

## 5. `Game` commands (the whole write API)

`new_game()`, `continue_game()`, `save()`, `set_paused(bool)`,
`book_fight(lineup: Array[int], opts := {}) -> bool` (`opts`: `main_event` story id, `prop` id),
`set_preferred_lineup(ids)`, `toggle_lineup(id)`, `plant()`, `uproot()`, `set_manager(enabled, threshold)`,
`recruit(hero_id)`, `assign_training(hero_id)`, `recall_training(hero_id)`,
`build(building_id, cell)`, `upgrade(building_id)`, `move_building(building_id, cell)`,
`buy_prop(prop_id)`, `select_prop(prop_id)`, `expand_seats()`, `expand_fighters()`.

Queries: `Game.state`, `Game.can_afford(cost)`, `Game.preview(lineup, opts) -> {stars_min, stars_max, income_min, income_max}`, `Game.attendance_if_booked_now()`.

## 6. `GameState` (single serialisable Resource)

`gold`, `hype`, `fame_points`, `seats_tier`, `fighter_tier`, `heroes: Array[HeroState]` (`owned, level, xp, wins, losses, streak, training_elapsed`), `preferred_lineup`, `buildings: Dictionary` (id → `{level, cell}`), `manager: {enabled, threshold}`, `stories: Array`, `props: {owned, selected}`, `fight_count`, `afterglow_pending`, `rng_seed_counter`. `save_store` writes JSON via temp file + backup at `user://fight_club_save.json`, version `1`; corrupt primary falls back to the backup. No offline progress in this scope.

## 7. Content schemas (`data/defs/`)

- `HeroDef`: `id, display_name, unit, red, health, attack, ranged, skill: SkillDef, price, trait_ids`.
- `SkillDef`: `name, kind (strike|sweep|heal|drain), power, description`.
- `BuildingDef`: `id, display_name, footprint: Vector2i, unlock_tier, levels: Array[BuildingLevel]` (`cost, effects: Dictionary`).
- `PropDef`: `id, display_name, icon, base_price, effect: Dictionary`.
- `TraitDef`: `id, display_name, icon, effect: Dictionary`.
- `StoryDef`: `id, kind, create_rule, ripen_rule`, `Tuning`: hype `tau`, base attendance floor, afterglow factor, story caps, fame tiers.
- All GDD numbers are **tuning placeholders** and live in `Tuning`/`.tres`, not in code.

## 8. UI rules

- Screens are `.tscn` + one `fight_club_theme.tres`; components are reusable scenes; repeated cards may be instanced in code.
- Icons carry state, text carries names and numbers. Readable at 960×420.
- One drawer at a time through `ui/router.gd`; ESC / right-click closes; opening a drawer never pauses the sim (only the menu does).
- A widget receives values through setters or `Events`; it never reaches into another widget or into `Game.state` for writes.

## 9. Tests

`godot --headless --path . --script res://game/tests/run_all.gd` runs every `test_*.gd` (each exposes `run() -> Array[String]` of failures). Logs and captures go under `.godot/`. New systems ship with a test in the same change.
