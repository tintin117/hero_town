# Fight club

A Godot 4.6.3 idle arena prototype. Open `project.godot` and press **F5** to play.

## Play the prototype

- Book exactly **3 of the 5 heroes**. Click a booked hero to deselect them, then choose a replacement. The three highest-star heroes are selected initially.
- **Open arena** starts repeating free-for-all fights. Health, attack, targeting preferences, and skills determine combat outcomes. Every living hero gets one normal attack per round in a randomized order.
- The last survivor earns **one career victory**. The other heroes retain their existing records, and everyone starts the next fight at full health.
- Each fight guarantees **100 + 5 × the trio's combined career victories**, using their records at the start of that fight. The new victory increases the next fight's guaranteed payout.
- Every skill cast pays **10 coins immediately**: the bank pulses, a gold **+10** floats above the caster, and the crowd-tip total updates. The final breakdown includes those tips without paying them twice.
- **Stop after this fight** finishes and pays the current fight, then unlocks the roster. During the three-second break it stops immediately.

Coins and records last for the current session. This first demo uses a normal window; desktop docking, saving, upgrades, recruitment, and a separate excitement score are not implemented. Fight durations vary with combat; the preview shows coins per fight, not coins per minute.

## Small regression check

Run with a Godot 4.6 executable:

```text
godot --headless --path . --script res://game/check_fight.gd
```

Checks all ten trios over 200 seeded fights plus two reward/regression fights, all five skills, targeting, mana priority, cancelled casts, one-time rewards, and UI controls. UI checks verify the bank and popup update at cast start without waiting a frame. To capture booking, combat, skill tips, overlapping tips, and the winner screen, omit `--headless` and append `-- --capture`. Captures go under `.godot/`.

Edit the five hero definitions and income constants in `game/fight.gd` to tune the mechanic; combat pacing lives in `game/main.gd`.

## Skills and mana

Every hero has one skill. Mana starts at **0/100** each fight: **+25** for landing a normal hit and **+15** for surviving one. Full mana triggers a cast before the next normal attack, resets to zero, and does not consume a normal turn. Skills generate no mana. If both sides become ready, the attacker casts first; a killed defender cannot cast. Combat ends as soon as one survivor remains.

| Hero | Target preference | Skill |
| --- | --- | --- |
| Bram | Highest attack | **Heavy Strike:** 2x attack damage. |
| Ivo | Highest current HP | **Sweep:** attack damage to every living opponent. |
| Nia | Lowest current HP | **Snipe:** 2.5x attack damage. |
| Tuck | Random opponent | **Second Wind:** restore 30% of maximum HP to himself. |
| Rook | Last opponent who damaged him; random if unavailable | **Drain:** 1.5x attack damage and healing equal to actual damage dealt. |

Targeting ties use the seeded RNG, and skills reevaluate targets when they cast. Skill amounts are rounded to the nearest integer without normal-attack variation. Healing is capped at maximum HP; overkill cannot increase Drain healing. Second Wind at full HP still spends mana and earns a tip. Each cast earns one tip regardless of the number of targets. Cancelled casts earn nothing.

The preview shows guaranteed income **plus variable skill tips**. Tips go into the bank at execution start; settlement adds only the guaranteed income and one career victory. Mana, last-attacker records, queued casts, and the tip counter reset between fights; coins and career victories persist for the session.

## Reusable assets

- `asset/` — original art, audio, models, textures, and shaders.
- `fonts/` — original fonts.
- `resources/` — authored sprite animations, UI textures/themes, and particle resources.
- `vfx/` — standalone effect scenes, shaders, and their supporting scripts.
- `icon.svg` and `icon.jpg` — existing project artwork.

Third-party editor tools remain in `addons/`. Gameplay does not depend on them.

## Previous prototype

The previous committed prototype remains on `codex/farm-fight-redesign`. Its uncommitted work was saved before the reset in Git stash `64b9c5f6845bb4f6991925cf5d3e6e7774d19a48`, named `Before Fight club reset: farm-fight-redesign work in progress`.
