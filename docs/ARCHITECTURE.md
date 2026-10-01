# Fight club — architecture contract

Companion to [GAME_DESIGN.md](GAME_DESIGN.md). Every module (and every parallel agent) codes against this file. Change it first, code second.

The old prototype lives at git tag `prototype-fight-club-v1`; read it with `git show prototype-fight-club-v1:game/fight.gd`. Combat numbers are verified against `game/tests/golden.json`, captured from that tag.

## 1. Layers and folders

```
game/
  main.tscn, main.gd   thin shell: shows MainMenu, then World + HUD. No rules, no drawing.
  desktop_strip.gd     shell helper for the OS window only: borderless, always-on-top strip docked to the top or
                       bottom of the screen, opaque background (no Windows rendering cutout), collapse to the HUD bar,
                       drag the bar to re-dock. Off when headless or embedded in the editor. Never reads GameState.
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
3. **Settle** when the last event is released: `economy.settle(result)` pays gold, XP, wins, fame, concessions (Restaurant + ringside bar), the main-event multiplier, sets afterglow; then `Stories.on_bout` updates the story board (`story_changed` / `story_ripe` / toast) → `Events.fight_finished(result)`. When the series ends the afterglow is multiplied (crowd pleaser, spotlights) and a cashed-in main event story is removed. Between bouts `Game.advance` ripens the timed stories with the clock.

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
| `series_started` | `info: Dictionary` (`lineup, attendance, seats, wins_needed, main_event, prop`) | the bell rings |
| `series_finished` | `result: Dictionary` (`winner` (-1 = unresolved), `wins`, `bouts`, `fame_bonus` (series bonus + `round(ripeness / 10)` of a won main event), `lineup`, `main_event`, `prop`) | a fighter reaches the win count |
| `roster_changed` | – | recruit, lineup or level change |
| `hero_changed` | `id: int` | one hero's XP / level / wins |
| `building_changed` | `id: StringName` | built, upgraded or moved |
| `story_changed` | `story_id: int` | created, replaced, removed (cashed / cooled out), ripeness whole number, ripe or cooling flag changed, chosen or cleared as the main event (throttled: never per frame) |
| `story_ripe` | `story_id: int` | ripeness first reaches `story_ripe_threshold` (a toast `"<Kind> ripe: <heroes>"`, icon `story`, follows) |
| `prop_changed` | – | prop bought, selected, consumed by a plant or refunded by an uproot |
| `manager_changed` | – | enabled / threshold changed |
| `toast` | `text: String, icon: StringName` | short user notice |
| `paused_changed` | `paused: bool` | menu open/close |

## 5. `Game` commands (the whole write API)

`new_game()`, `continue_game()`, `save()`, `set_paused(bool)`,
`book_fight(lineup: Array[int], opts := {}) -> bool` (`opts`: `main_event` = the locked Dictionary `plant` makes, `prop` id, `mods`, `seed`; the auto bell passes the planted ones),
`set_preferred_lineup(ids)`, `toggle_lineup(id)` (both clear the main event when the lineup no longer holds all its story's heroes), `plant()`, `uproot()`, `set_manager(enabled, threshold)`,
`set_main_event(story_id) -> bool`, `clear_main_event() -> bool`,
`recruit(hero_id)`, `assign_training(hero_id)`, `recall_training(hero_id)`,
`build(building_id, cell)` (unbuilt only, valid cell, pays level 1), `upgrade(building_id)`, `move_building(building_id, cell)` (free; onto its own spot is a silent success),
`buy_prop(prop_id) -> bool` (affordable, at most `prop_cap` held, a planted one still counts), `select_prop(prop_id) -> bool` (`&""` clears; needs one in stock), `expand_seats()`, `expand_fighters()`.

**Main event.** `set_main_event(id)` needs a ripe story whose heroes are owned and not training; it sets `preferred_lineup` to the story's heroes (a one-hero story brings the first other owned hero of the current lineup, else the first owned one) and fails, changing nothing, when that lineup does not fit. `main_event_id` (-1 = none) is dropped when the story leaves the board or stops being ripe. `plant()` locks the chosen story into `planted_main_event` (`{id, kind, title, ripeness, multiplier}`, `{}` when none / not ripe) and consumes one selected prop into `planted_prop`; later choices change nothing. Every bout of that series pays `round(normal payout * multiplier)` with `multiplier = 1 + 2 * ripeness / 100` (`Tuning.main_event_bonus`), reported as `main_event_multiplier` in the bout result. At the series' end the story is removed and a won series adds `round(ripeness / 10)` fame. `uproot()` drops the lock and refunds the prop; the story is never spent unless a series ends.

**Traits.** `Game.hero_traits(hero_id) -> Array[TraitDef]`. Combat mods are rebuilt for every bout from the lineup and its current levels: `showman` `skill_excitement_mult` x1.5 per showman, `brawler` `damage_mult[hero]` x1.15, `underdog` `start_excitement` +10 per underdog with a higher-level opponent; keys are absent while neutral. `crowd_pleaser` (any in the lineup) multiplies the afterglow x1.5 when the series ends, `grudge_holder` multiplies the ripening of every story involving that hero.

**Props** (consumed per plant): `fireworks` +15 `start_excitement`, `announcer` `skill_excitement_mult` x1.5 (stacks with showmen), `spotlights` afterglow x1.5 at series end (stacks with crowd pleasers), `ringside_bar` +0.5 gold per attendee each bout (added to the Restaurant rate). `prop_price(id)` = `round(base_price * seats / prop_price_seats)`, -1 for an unknown id.

Queries: `Game.state`, `Game.can_afford(cost)`, `building_level(id) -> int` (0 = unbuilt), `building_cell(id) -> Vector2i` ((-1, -1) unbuilt), `can_place(id, cell)`, `building_at(cell) -> StringName` (`&""` = none), `building_next_cost(id)` (-1 = maxed), `building_defs()`, `training_heroes() -> Array[int]`, `training_slots()`, `hero_capacity()`, `Game.attendance_if_booked_now()`, `Game.preview(lineup, opts := {}) -> {stars_min, stars_max, income_min, income_max}`, `hero_traits(hero_id)`, `story(id) -> Dictionary` (copy, `{}` if gone), `story_slots()`, `prop_defs() -> Array[PropDef]`, `prop_price(id)`, `props_owned(id)`, plus the vars `main_event_id`, `selected_prop`, `planted_main_event`, `planted_prop`.

`preview` is a pure estimate (`systems/preview.gd`): excitement = `preview_base_excitement` + casts of strike/sweep/drain fighters (`preview_skills_per_fighter` each, `preview_skill_excitement` per cast, times showman and announcer multipliers) + start excitement (underdog, fireworks) - `preview_level_gap_penalty` per level between the strongest and weakest fighter + `preview_story_bonus` when a ripe story fits inside the lineup; stars = `1 + excitement / preview_excitement_per_star`, clamped 1..5 and snapped to halves. The range is +/- (`preview_width` - `preview_width_step` x Promotion Office level). Income = ticket base at the attendance the manager's threshold draws, times the excitement multiplier of each end's star band, times the main-event multiplier when `opts.main_event` (default `main_event_id`) is a ripe story inside the lineup. `opts.prop` defaults to `selected_prop`. Zeros for an invalid lineup.

Every building command emits `building_changed(id)`, autosaves and returns `false` (no throw) on invalid input. `assign_training(hero_id)` needs a free gym slot and an owned, uncapped hero who is not planted or in the running series; `plant()` and `book_fight` refuse trainees (no auto-recall); trainees earn `gym_xp` every `gym_interval` s whenever the game runs and are released at the level cap. `recruit` refuses at `hero_capacity()`.


## 6. `GameState` (single serialisable Resource)

`gold`, `hype`, `fame_points`, `seats_tier`, `fighter_tier`, `heroes: Array[HeroState]` (`owned, level, xp, wins, losses, streak, recent_losses` (consecutive losses, reset by a win)), `preferred_lineup`, `buildings: Dictionary` (id String → `{level: 1..3, cell: [x, y]}`, absent = unbuilt), `training: Dictionary` (hero id → seconds since the last gym payout), `manager: {enabled, threshold}`, `stories: Array[Dictionary]` (`{id: int, kind: StringName, title: String, heroes: Array[int], ripeness: float 0..100, ripe: bool, cooling: bool, full_bouts: int}`; saved with `kind` as a String), `next_story_id`, `meetings: Dictionary` (`"a-b"` with a < b → `{wins_a, wins_b}`), `props: Dictionary` (prop id String → count 0..`prop_cap`), `fight_count`, `rng_seed_counter`. `selected_prop`, `main_event_id`, `planted_main_event` and `planted_prop` live on `Game` and are not saved (a prop consumed by a plant that never rang is lost if the game closes). `save_store` writes JSON via temp file + backup at `user://fight_club_save.json`, version `1`; corrupt primary falls back to the backup. `buildings` / `training` / `stories` / `next_story_id` / `meetings` / `props` / `recent_losses` are optional in old saves (default empty / 0); `decode` also rejects a story with an unknown kind, the wrong hero count, a hero out of range, a ripeness outside 0..100, a `ripe` flag that disagrees with the threshold or a duplicate id, more stories than `Game.story_slots()`, a meeting key that is not `"a-b"` with a < b, and a prop that is unknown or held over `prop_cap` times; when present, `SaveStore.decode` rejects an unknown building id, a level outside 1..3, a cell off the buildable land or overlapping the arena or another building, and trainees that are unowned, past the interval or exceed the gym slots. No offline progress in this scope.

## 7. Content schemas (`data/defs/`)

- `HeroDef`: `id, display_name, unit, red, health, attack, ranged, skill: SkillDef, price, trait_ids`.
- `SkillDef`: `name, kind (strike|sweep|heal|drain), power, description`.
- `BuildingDef`: `id: StringName, display_name, description, footprint: Vector2i, levels: Array[BuildingLevel]`; `BuildingLevel`: `cost: int, effect: float` (one number per level). Catalog holds `buildings: Array[BuildingDef]` (`data/buildings/*.tres`). The `Buildings` system (`systems/buildings.gd`) gives each id its meaning: `promotion_office` = hype tau multiplier (`Hype.grow`), `recruitment_hall` = owned-hero capacity (`Roster.can_recruit`; baseline `Tuning.hall_base_capacity`), `gym` = training slots (`gym_xp` per `gym_interval`), `restaurant` = gold per attendee at bout settlement (`Economy.settle` returns `concessions`, paid outside the excitement multiplier). Unbuilt = neutral (1.0 / baseline / 0 / 0). Grid (48x8, owned columns 10..37, arena columns 16..31, path row 7) is in `Tuning` (`grid_*`, `land_*`, `arena_*`, `path_row`).
- `PropDef`: `id, display_name, description, icon_name (stem in resources/ui/icons/), base_price, value` — `Props` (`systems/props.gd`) gives each id its meaning; `Catalog.props`, data in `data/props/*.tres`.
- `TraitDef`: `id, display_name, description, icon_name, value` — `Traits` (`systems/traits.gd`) gives each id its meaning; `Catalog.traits`, data in `data/traits/*.tres`; `HeroDef.trait_ids` picks 1-2 per hero.
- Stories are plain Dictionaries handled by the pure `Stories` (`systems/stories.gd`); their numbers are `Tuning` (`story_*`, `main_event_*`, `preview_*`, `prop_*`). Kinds: `win_streak` [hero] (streak reaches `story_streak_len`, +`story_streak_step` per further win), `rivalry` [a, b] (a < b; a split result over `story_rivalry_meetings` meetings, +`story_rivalry_step` per meeting: a meeting is a decided bout where one of the pair beat the other), `grudge` [loser, winner] (a loss to someone with an existing rivalry, +`story_grudge_step` per repeated loss, plus time), `comeback` [hero] (a win after `story_comeback_losses` losses in a row, +`story_comeback_step` per repeat, plus time), `legend` [hero] (level >= `story_legend_level` and a streak >= `story_legend_streak`, +`story_legend_step` per win, plus time). Time ripening: +1 per `story_time_seconds` of unpaused play for grudge, comeback and legend. One story per (kind, heroes); a new story starts at `story_start`; a full board (`story_slots_base` + Promotion Office level) drops the least ripe story only if its ripeness is not above the newcomer's, else drops the newcomer. At 100 a story counts `full_bouts` per bout, cools after `story_overripe_bouts`, then loses `story_cooling` per bout and is removed at 0; a cooling story no longer ripens.
- All GDD numbers are **tuning placeholders** and live in `Tuning`/`.tres`, not in code.

## 8. UI rules

- Screens are `.tscn` + one `fight_club_theme.tres`; components are reusable scenes; repeated cards may be instanced in code.
- Icons carry state, text carries names and numbers. Readable at 960×420.
- One drawer at a time through `ui/router.gd`; ESC / right-click closes; opening a drawer never pauses the sim (only the menu does).
- A widget receives values through setters or `Events`; it never reaches into another widget or into `Game.state` for writes.

## 9. Tests

`godot --headless --path . --script res://game/tests/run_all.gd` runs every `test_*.gd` (each exposes `run() -> Array[String]` of failures). Logs and captures go under `.godot/`. New systems ship with a test in the same change.
