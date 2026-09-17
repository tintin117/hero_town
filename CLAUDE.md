# Hero Town — project context

Read [README.md](README.md) for the folder map and [docs/EDITOR_WORKFLOW.md](docs/EDITOR_WORKFLOW.md) for the designer workflow.

## Current project

Godot 4.6.3, GDScript, 2D Tiny Swords pixel art, Forward Plus / D3D12 on Windows. F5 starts `game/menu/main_menu.tscn`, then `game/companion/companion.tscn`. The separate 20-stage army town is `game/town/town.tscn`. The earlier full-window conquest prototype is under `prototypes/full_window_conquest/`.

Scenes and their scripts are colocated by feature in `game/`. Authored balance lives in `data/companion/` and `data/town/`; shared animation, theme, and effect resources live in `resources/`. The town uses GameData and GameState autoloads; the companion owns its ConquestState and separate save. Keep existing save paths, resource IDs, class names, and node contracts stable.

## Working rules

- Preserve third-party `addons/`, original `asset/` packs, and `fonts/`.
- Prefer native scenes, Inspector exports, and resources for art/layout/balance. Keep simulation, transactions, and persistence in code. Do not overwrite authored scene values during startup.
- Implement the requested scope with existing native features; avoid speculative abstractions and features.
- Keep script `.uid` files when moving scripts, and update resource paths, autoloads, and relevant checks.
- Use `game/previews/` for F6 experiments without player saves. For automated checks, follow [tests/README.md](tests/README.md), use isolated user data and `-- --test`. Generated outputs belong in `.godot/`.
- Keep Embed Game on Play disabled for native desktop checks. Run relevant checks after code changes; only take screenshots when the user explicitly asks.
- `docs/archive/` contains historical context, not current architecture instructions.

## Design references

The broader GDD is at `D:\Optics Team\Godot\[Optics] Hero_Town_GDD\`. Its Overview, Current Plan, Detail Planning, Hero, Enemy, Building, Economy, Progression, Portal_Combat, Shrine, and UI_UX HTML files describe product plans; some features are outside the current playable scope.
