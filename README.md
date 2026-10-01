# Fight club

A Godot 4.6 idle arena game for a desktop strip window (1280×420, resizable from 960×420). Open `project.godot` and press **F5** (`game/main.tscn`).

You are the promoter of a small fight club. Fighters brawl on their own; you build the business around the show: the hype, the crowd, the stories and the money. The design is in [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md); the code layout and contracts are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). This build covers the GDD's steps 1–2 (hype slice, stories, Main Events, preview, props). Every number is a tuning placeholder in `game/data/`.

## How to play

The loop is **plant → grow → bell → bo5 series → repeat**, like a farm.

- **Tap the arena** to open the seed tray and pick your fighters (click cards; picking into a full lineup swaps out the oldest pick). **Hold the arena** to plant the picked fighters. A gold arc fills around the ring.
- **Hype only grows while a lineup is planted.** When it reaches the bell threshold (default 70, set in the Manager drawer) the bell rings by itself: the crowd is locked and a **best-of-five series** starts (first to 3 wins, 3 seconds of crowd chatter between bouts). Every bout pays ticket money × excitement, plus tips per skill and Restaurant snacks.
- After the series the planted lineup is used up and hype falls to an afterglow. Your last pick is remembered, so replanting is one hold.
- **Stories** form on their own from fighters' results: Win Streak, Rivalry, Grudge, Comeback, Legend. They ripen; a ripe story can be cashed as the **Main Event** of a series for up to ×3 payout and extra fame. Overripe stories go cold.
- **Traits** shape the show: Showman (more excitement from skills), Brawler (more damage), Crowd Pleaser (bigger afterglow), Grudge Holder (stories ripen faster), Underdog (excitement when outleveled).
- The seed tray shows a **1–5 star preview** and expected gold per bout. The Promotion Office narrows its uncertainty.
- **Props** (Fireworks, Announcer, Spotlights, Ringside Bar) are bought in the Stories drawer and attached to one series each.
- **Roster drawer:** recruit heroes (the Recruitment Hall limits how many you can own), edit the lineup, buy more seats and fighter slots.
- **Build drawer:** Promotion Office, Recruitment Hall, Gym and Restaurant, three levels each. Pressing Build shows a placement ghost in the town (left-click to place, right-click or ESC to cancel); you are charged only once placed. Click a building to open its entry; **Move** repositions it. The Gym trains benched heroes.
- **Manager drawer:** the bell threshold and an on/off switch for the auto bell. **Menu** (gear, or ESC) pauses and saves; Continue resumes. Closing the game grants no offline progress.
- Scroll the town with the middle mouse button, Shift + wheel, or the scrollbar.
- **Desktop strip:** the game docks as a solid, borderless, always-on-top panel on the bottom edge of the screen (above the taskbar), as wide as the town. Controls sit above the scenery. The chevron collapses it to just the status bar; drag the bar to re-dock at the top or bottom. Running inside the editor's embedded game view keeps a normal window.

Combat is unchanged from the previous prototype and verified against its recorded numbers (`game/tests/golden.json`): auto-chasing fighters, one skill per hero template (Heavy Strike, Sweep, Snipe, Second Wind, Drain), overtime after 60 s, 5 % stat growth per level up to level 10. There is no stamina or injury in normal play.

## Project layout

```
game/
  main.tscn / main.gd   thin shell: menu, town + arena, HUD; forwards arena gestures and placement
  core/                 Game (autoload) + Events (autoload signal bus), GameState, save store
  systems/              pure rules: hype, economy, roster, fame, manager, buildings, stories, traits, props, preview
  combat/               combat_sim (pure, seeded) and the arena scene / effects that replay it
  town/                 scrollable Sunnyside strip, buildings, placement ghost, ambient life
  ui/                   theme, components, HUD, drawers (roster, build, stories, manager, seed tray), menus
  data/                 authored .tres content: heroes, buildings, traits, props, tuning
  tests/                headless tests, golden data, report scripts
```

Data flows one way: UI → `Game` commands → systems mutate `GameState` → `Events` signals → UI, town and arena redraw. The UI never computes rewards.

## Verification

Godot 4.6.x is required. Run the whole suite headless:

```text
godot --headless --path . --script res://game/tests/run_all.gd
```

Read the output for `FAIL` lines **and** for `SCRIPT ERROR` lines: a script that errors inside a test can still be reported as passing. The suite covers combat parity with the prototype's golden fights, every rule system, saves, the UI drawers and layouts at 960×420, 1280×420 and 1600×560, the town and arena. Generated logs and captures belong under the ignored `.godot/`.

Windowed runs (screenshots, playthroughs) are driven with a small scene under `.godot/` so the `Game` and `Events` autoloads exist; `--script` runs do not have them.

`docs/BALANCE.md` (when present) holds the seeded progression simulation and pacing findings.

## Saves

`user://fight_club_save.json` (version 1) with a backup and atomic writes. Only progress is saved; a running series and the planted lineup are not, so loading starts idle. Tests use isolated `.godot/` saves, never the player's file.

## Reusable assets

- `asset/` — original art, audio, models, textures, and shaders (Sunnyside World by Daniel Diggle, Tiny Swords; see `resources/art/SUNNYSIDE_CREDITS.md`).
- `fonts/` — original fonts (Peaberry, crisp pixel rendering).
- `resources/` — sprite animations, UI textures/themes, generated UI icons.
- `vfx/` — standalone effect scenes and shaders.

Third-party editor tools remain in `addons/`. Gameplay does not depend on them.

## Previous prototype

The earlier event-based prototype is preserved at git tag `prototype-fight-club-v1` (read it with `git show prototype-fight-club-v1:game/fight.gd`). Its earlier work in progress is in Git stash `64b9c5f6845bb4f6991925cf5d3e6e7774d19a48`.
