# Fight club

A Godot 4.6.3 idle arena prototype. Open `project.godot` and press **F5** to play.

## Play the prototype

- Book exactly **3 of the 5 heroes**. Click a booked hero to deselect them, then choose a replacement. The three highest-star heroes are selected initially.
- **Open arena** starts repeating free-for-all fights. Health and attack determine combat strength; random targeting and attack order allow upsets. Every living hero attacks once per round.
- The last survivor earns **one career victory**. The other heroes retain their existing records, and everyone starts the next fight at full health.
- Each fight pays **100 + 5 × the trio's combined career victories**, using their records at the start of that fight. The new victory increases the next fight's payout.
- **Stop after this fight** finishes and pays the current fight, then unlocks the roster. During the three-second break it stops immediately.

Coins and records last for the current session. This first demo uses a normal window; desktop docking, saving, upgrades, recruitment, and a separate excitement score are not implemented. Fight durations vary with combat; the preview shows coins per fight, not coins per minute.

## Small regression check

Run with a Godot 4.6 executable:

```text
godot --headless --path . --script res://game/check_fight.gd
```

Checks all ten trios over 200 seeded fights, the example income calculation, one-time rewards, lineup validation, and the UI's selection and repeat controls. To capture the booking, combat, and winner screens, omit `--headless` and append `-- --capture`. Captures go under `.godot/`.

Edit the five hero definitions and income constants in `game/fight.gd` to tune the mechanic; combat pacing lives in `game/main.gd`.

## Next design pass

- Define each hero's attributes and combat behavior, with exactly **one skill per hero**.
- Heroes gain mana when landing hits and when being hit, then automatically cast their skill when they have enough mana.
- Each skill cast earns bonus money from the crowd, in addition to the existing fight income.
- Mana gains, skill costs/effects, targeting, and crowd bonus amounts remain to be designed. These mechanics are not implemented in this prototype.

## Reusable assets

- `asset/` — original art, audio, models, textures, and shaders.
- `fonts/` — original fonts.
- `resources/` — authored sprite animations, UI textures/themes, and particle resources.
- `vfx/` — standalone effect scenes, shaders, and their supporting scripts.
- `icon.svg` and `icon.jpg` — existing project artwork.

Third-party editor tools remain in `addons/`. Gameplay does not depend on them.

## Previous prototype

The previous committed prototype remains on `codex/farm-fight-redesign`. Its uncommitted work was saved before the reset in Git stash `64b9c5f6845bb4f6991925cf5d3e6e7774d19a48`, named `Before Fight club reset: farm-fight-redesign work in progress`.
