# Fight club — project context

Godot 4.6.3 idle arena prototype. Read [README.md](README.md) for the current mechanics, regression check, asset map, and previous-prototype recovery reference. F5 runs `game/main.tscn`.

- Design gameplay and mechanics from scratch; do not carry over the previous town or companion systems.
- Preserve reusable `asset/`, `fonts/`, `resources/`, and standalone `vfx/` content, including script `.uid` files.
- Preserve third-party `addons/` and the user's editor plugin settings.
- Prefer native Godot scenes and resources for authored content, and the smallest implementation of the requested mechanics.
- Keep generated checks, logs, and captures under the ignored `.godot/` directory. Run relevant checks after changes.
