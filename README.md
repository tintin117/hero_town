# Fight club

A Godot 4.6.3 idle arena prototype. Open `project.godot` and press **F5** to play.

## Play the prototype

- Book exactly **3 of the 5 heroes**. Click a booked hero to deselect them, then choose a replacement. The three highest-star heroes are selected initially.
- **Open arena** starts repeating real-time free-for-all fights. Heroes chase the nearest opponent and attack on independent cooldowns. Nia shoots from range and retreats when approached; the other four fight in melee.
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

Checks all ten trios over 200 seeded fights plus two reward/regression fights, requiring exactly one survivor within 120 simulated seconds. Also checks movement, nearest targeting, range boundaries, independent cooldowns, all five skills, mana priority, cancelled casts, one-time rewards, and UI controls. UI checks verify the bank and popup update at cast start without waiting a frame. To capture booking, combat, skill tips, overlapping tips, and the winner screen, omit `--headless` and append `-- --capture`. Captures go under `.godot/`.

Edit the five hero definitions and combat/income constants in `game/fight.gd` to tune the mechanic. The model's `advance(delta)` returns ordered action events and runs from the UI's fixed physics update; rendering never decides damage or rewards. `game/main.gd` handles projection, animations, effects, and the three-second intermission.

## Movement and ranges

The arena is a circle with a **260-unit radius**, projected as an oval with upright, depth-sorted sprites. Logical distances are independent of window size. The three spawn positions are evenly spaced and assigned with the seeded RNG, which also sets initial cooldown offsets and simultaneous-action priority.

- All heroes reconsider the **nearest living opponent every 0.25 seconds**, after losing their target, and before attacking or casting. Equal distances retain the current target; other ties use seeded RNG.
- Melee heroes move at **90 units/second** and attack within **45 units**. Nia moves at **75 units/second**, approaches beyond **160**, holds at **110–160**, and retreats below **110**. At the boundary she stands and fights.
- Normal attacks have individual **1.5-second cooldowns**. Attacks and casts pause movement for **0.2 seconds**; casts do not reset the normal cooldown.
- Heroes stay inside the boundary and gently separate overlapping bodies. This open floor uses direct steering without obstacles or navigation meshes.
- Damage is immediate. Shot and impact effects are visual feedback, not delayed projectiles. Sweep's visible oval is the projection of its actual circular damage area.

## Skills and mana

Every hero has one skill. Mana starts at **0/100** each fight: **+25** for landing a normal hit and **+15** for surviving one. Full mana prioritizes a cast over the next normal attack and resets to zero when the cast begins. Offensive skills wait for an enemy in range; waiting pays nothing and does not block other heroes. Skills generate no mana. If both sides become ready, eligible attacker and defender casts resolve in that order before another normal attack; a killed defender cannot cast. Combat ends as soon as one survivor remains.

| Hero | Range | Skill |
| --- | --- | --- |
| Bram | 45 units | **Heavy Strike:** 2x attack damage to the nearest enemy. |
| Ivo | 90-unit radius | **Sweep:** attack damage to every enemy inside the circle. |
| Nia | 160 units | **Snipe:** 2.5x attack damage to the nearest enemy. |
| Tuck | Self | **Second Wind:** restore 30% of maximum HP to himself. |
| Rook | 45 units | **Drain:** 1.5x attack damage to the nearest enemy; heal by actual damage dealt. |

Targeting ties use the seeded RNG, and skills reevaluate targets when they cast. Skill amounts are rounded to the nearest integer without normal-attack variation. Healing is capped at maximum HP; overkill cannot increase Drain healing. Second Wind at full HP still spends mana and earns a tip. Each cast earns one tip regardless of the number of targets. Cancelled casts earn nothing.

The preview shows guaranteed income **plus variable skill tips**. Tips go into the bank at execution start; settlement adds only the guaranteed income and one career victory. Positions, movement, targets, cooldowns, mana, queued casts, effects, and the tip counter reset between fights; coins and career victories persist for the session.

## Reusable assets

- `asset/` — original art, audio, models, textures, and shaders.
- `fonts/` — original fonts.
- `resources/` — authored sprite animations, UI textures/themes, and particle resources.
- `vfx/` — standalone effect scenes, shaders, and their supporting scripts.
- `icon.svg` and `icon.jpg` — existing project artwork.

Third-party editor tools remain in `addons/`. Gameplay does not depend on them.

## Previous prototype

The previous committed prototype remains on `codex/farm-fight-redesign`. Its uncommitted work was saved before the reset in Git stash `64b9c5f6845bb4f6991925cf5d3e6e7774d19a48`, named `Before Fight club reset: farm-fight-redesign work in progress`.
