# Fight club — project context

Godot 4.6.3 idle arena game (desktop strip, 1280×420). Read [README.md](README.md) for how it plays, the layout and the test command, [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) for the design, and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the module contracts (change the contract first, code second). F5 runs `game/main.tscn`.

- Design gameplay and mechanics from scratch; do not carry over the previous town or companion systems. The old prototype lives at git tag `prototype-fight-club-v1`.
- Keep the layers apart: UI → `Game` commands → systems mutate `GameState` → `Events` signals → UI/town/arena redraw. The UI never computes rewards; systems never touch nodes; `combat_sim` stays pure and seeded.
- Authored content and every tuning number live in `game/data/*.tres`, not in code.
- Preserve reusable `asset/`, `fonts/`, `resources/`, and standalone `vfx/` content, including script `.uid` files.
- Preserve third-party `addons/` and the user's editor plugin settings.
- Prefer native Godot scenes and resources for authored content, and the smallest implementation of the requested mechanics.
- Keep generated checks, logs, and captures under the ignored `.godot/` directory. Run `godot --headless --path . --script res://game/tests/run_all.gd` after changes and read the whole output: grep for `FAIL` and for `SCRIPT ERROR`, because a script that errors inside a test can still count as passing.
- New systems ship with a test in the same change. Windowed playthroughs need a scene (autoloads are missing under `--script`).
