# Fight club — project context

Fresh Godot 4.6.3 prototype. Read [README.md](README.md) for the asset map and previous-prototype recovery reference. F5 runs the empty `game/main.tscn` scene.

- Design gameplay and mechanics from scratch; do not carry over the previous town or companion systems.
- Preserve reusable `asset/`, `fonts/`, `resources/`, and standalone `vfx/` content, including script `.uid` files.
- Preserve third-party `addons/`; they are disabled in the clean project configuration.
- Prefer native Godot scenes and resources for authored content, and the smallest implementation of the requested mechanics.
- Keep generated checks, logs, and captures under the ignored `.godot/` directory. Run relevant checks after changes.
