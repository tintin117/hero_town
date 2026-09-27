# Fight club

A Godot 4.6.3 idle arena prototype. Open `project.godot` and press **F5** to play.

## Play the prototype

- Open **Heroes** to book exactly **3 of the 5 heroes**. Click a booked hero to deselect them, then choose a replacement. Bram, Ivo, and Nia are selected initially.
- **Open arena** starts repeating real-time free-for-all fights. Heroes chase the nearest opponent and attack on independent cooldowns. Nia shoots from range and retreats when approached; the other four fight in melee.
- The last survivor earns **one career victory**. The other heroes retain their existing records, and everyone starts the next fight at full health.
- Each fight locks in **base income = round((100 + 5 × sum(level − 1) + 5 × combined victories) × arena seats / 100)**. Hero levels, victories, and capacity are quoted when the fight starts. Later level-ups and expansion affect the next booking.
- Fill the **excitement bar** through fight time and skill casts. At 40 excitement, fight income becomes **1.25x** the base; at 80, it becomes **2.5x**. The live bar shows the tier and projected payout, with a pulse when a new tier is reached.
- Every skill cast pays **10 coins immediately**, at every hero level and arena size. The bank pulses, a gold +10 floats above the caster, and the crowd-tip total updates. The final breakdown includes those tips without paying them twice.
- Every participant earns **10 XP** after a fight, with **10 extra XP for the winner**. Levels improve HP, attack, and base booking income. Roster cards show level, XP progress, current stats, and coins per skill.
- Open **Arena** for seating capacity, the next expansion, and the next booking's base pay, level bonus, victory bonus, and capacity multiplier. Spend earned coins on **Expand** to add seats and a larger covered stand.
- **Stop after this fight** finishes and pays the current fight, then unlocks the roster. During recovery it cancels the queued fight immediately.

Coins, victories, levels, XP, and arena expansion last for the current session. This demo uses a compact **1280×420** normal window, resizable from **960×420**. Desktop transparency/docking, saving, equipment, recruitment, and hero rarity are not implemented. Fight durations vary with combat; the preview shows base coins per fight before excitement and skill tips, not coins per minute.

## Desktop Promenade presentation

The arena sits in a shallow town strip with the project's existing Tiny Swords houses, barracks, trees, terrain, and pawn sprites. Visitors stroll along the public path, clouds and smoke drift, banners move, and spectators briefly cheer when excitement reaches a new tier. These decorations do not affect combat or consume its seeded RNG. The combat floor and Sweep effects share the same projection.

The town is a fixed **48 x 8 cell** ground strip, with each cell displayed at **48 x 24 pixels**. Explore it using the horizontal scrollbar, middle-button drag, or Shift + mouse wheel; **Center arena** returns to the fight. The HUD stays fixed, and automatic repeats preserve your view. Resizing changes the visible area, never cell coordinates or combat scale.

**Arrange** shows the grid and occupied footprints. Select the tavern (2 x 2 cells) or barracks (3 x 2), then click a green preview to move it. Red previews overlap another building, the arena/seating reserve, the public path, or the map boundary. Escape, right-click, or leaving Arrange cancels a move. Opening a panel and starting another fight preserve the preview, and combat/recovery keep running. Roofs can extend above their ground footprint. New construction, prices, rotation, housing bonuses, and saving are deferred.

- The bank shows spendable coins. **At finish** shows the active fight's pending payout; **tips paid** are already in the bank. Between fights, the completed payout is explicitly labeled **paid / last fight**.
- The compact crowd board shows the score, multiplier, threshold markers, and next tier. HP stays green, mana blue, and excitement amber.
- **Heroes** and **Arena** are temporary panels. Only one opens at a time; close with its Close button, Escape, the same navigation button, or a click outside. Combat keeps running while inspecting them. Booking remains locked until fighting stops.
- The bottom ribbon reports combat, the winner, and earned income. Hover the result for its full calculation and hover the winner for XP results; Heroes shows updated level/XP bars and skill tooltips.
- The interface uses native Godot controls, keyboard focus, and a scrollable roster as a fallback. Window sizing is applied at runtime without changing the project's editor or plugin settings.

No generated sprites are required for this pass. The arena floor, stands, canopy, flags, and paths use native drawing alongside the existing assets. The art-direction images remain under `concept-art/` as references, not runtime backgrounds.

## Crowd excitement

- Starts at **0/100** each fight, never decays, and caps at **100**.
- Fight time adds **1 point per simulated second**, capped at **20 points total**. Intermission and idle time add nothing.
- Each executed skill adds **8 points immediately**, including healing at full HP. Sweep adds 8 once, regardless of target count. Waiting, dead, and cancelled casts add nothing; normal hits add no excitement.
- **Normal:** below 40, **1x**. **Excited:** 40 to below 80, **1.25x**. **Wild:** 80 and above, **2.5x**. These are guaranteed tier multipliers; there is no random payout roll in this version.
- **Fight income = round(locked base income × final excitement multiplier)**. The finishing skill contributes before settlement. For a 190-coin base, the three tiers pay 190, 238, or 475 coins.
- Skill tips remain **10 coins at cast start**. They are neither multiplied nor paid again at settlement. The result shows base × multiplier, fight income, already-paid tips, and the combined total.
- The bar retains the result during the break and resets for the next fight. Rarity bonuses are deferred until heroes have a rarity attribute; levels continue to raise base income.

## Hero recovery

Every fight participant, including the winner, rests for **8 seconds after settlement**. Roster cards show Ready or a rest countdown. Recovery continues while the arena is closed, while town panels are open, and during other fights; it grants no XP, income, or excitement. Progress remains session-only, without offline recovery.

Automatic repeats retain your booked trio and resume only when everyone is ready. The three-second intermission runs concurrently with recovery, so the total normal wait is eight seconds. Opening the arena while selected heroes are resting queues a fight; **Cancel next fight** stops the queue without resetting recovery. Heroes start their next fight at full HP and zero mana. Houses and recovery-speed upgrades are deferred.

## Hero levels and earnings

- All heroes start at **level 1**, capped at **level 10**. Stars have been replaced by levels.
- XP needed for the next level is **30 + 20 × (current level − 1)**. Excess XP carries forward; reaching the cap clears remaining XP and displays MAX.
- XP is awarded once when the fight finishes, including to defeated participants. Unbooked heroes receive none. Level-ups apply after settlement; new stats and level bonuses take effect in the next fight.
- Each level adds **5% of original HP and attack**, rounded to the nearest integer. Growth is linear: level 10 has 145% of base stats. Skill damage scales with attack, Second Wind scales with maximum HP, and Drain still heals only actual damage dealt. Movement, cooldowns, mana, and skill multipliers stay the same.
- Each level above 1 adds **5 base coins** to a booking, and each career victory adds another **5**. Seating capacity multiplies this subtotal before the fight's excitement multiplier. Unbooked heroes contribute nothing.
- Skill tips remain **10 per executed cast**, including multi-target skills, at every level. Cancelled casts pay nothing. Levels never multiply tips.

Combat stats and base income are snapshotted at fight start. Hero definitions keep their original HP and attack, so repeatedly leveling cannot compound or mutate base stats.

## Arena capacity

| Seats | Base income multiplier | Expansion cost |
| --- | --- | --- |
| 100 | 1x | Starting arena |
| 150 | 1.5x | 500 coins |
| 200 | 2x | 1,000 coins |

These are initial prototype prices; 200 seats is the current cap. Assume every seat is filled. Expansion adds visible seating rows and, at 150/200 seats, a covered stand with a wider canopy while leaving the combat floor, movement, and skill ranges unchanged.

Upgrades can be purchased while a fight runs and debit the bank immediately. The active fight retains its quoted base payout, while the next-booking preview updates immediately. Unaffordable and max-capacity purchases cannot spend coins.

For example, a level **5 + 6 + 10** trio with no career victories gets **190** base coins at 100 seats, **285** at 150 seats, or **380** at 200 seats. Round the capacity-scaled base to the nearest whole coin, then round again after applying excitement; a half coin rounds up. Skill tips are added separately.

## Small regression check

Run with a Godot 4.6 executable:

```text
godot --headless --path . --script res://game/check_fight.gd
```

Checks all ten trios over 200 seeded fights with ongoing leveling, two reward/regression fights, and 20 mixed-level/max-level fights, requiring exactly one survivor within 120 simulated seconds. Also checks XP thresholds, overflow, the level cap, stat scaling, flat immediate tips, movement, skills, mana, and one-time settlement. Arena checks cover the 5/6/10 example, rounding, affordability, both upgrades, capacity limits, current-fight quote preservation, and unchanged combat geometry. UI checks cover the new income breakdown, expansion purchases, instant affordability after tips, XP bars, level-up feedback, and stop/rebook/repeat controls. To capture combat, progression, and all three arena capacities, omit `--headless` and append `-- --capture`. Captures go under `.godot/`.

Excitement checks cover elapsed-time caps, exact thresholds, ordered same-frame casts, full-health healing, cancelled casts, multi-target finishing casts, payout rounding, and repeat resets. Every seeded fight also verifies accumulated excitement and multiplied settlement. UI captures include Excited, Wild, and the final income breakdown.

Recovery checks cover inactive time, invalid deltas, exact expiry, independent bench recovery, queued fights, concurrent intermission, and cancellation without resetting rest. Grid checks cover native cell conversion, overlap and protected-cell rejection, atomic moves, cancelled previews, HUD input isolation, panning, resize, and automatic repeats retaining both view and placement preview.

Promenade checks also cover opening/switching/closing panels, Escape and outside dismissal, focus return, booking through the hero panel, purchasing through Arena, combat continuing behind an open panel, cheering feedback, and layouts at 960×420 and 1600×560. Captures include the closed promenade and both panels.

Edit the five hero definitions and combat/income constants in `game/fight.gd` to tune the mechanic. The model's `advance(delta)` returns ordered action events and runs from the UI's fixed physics update; rendering never decides damage or rewards. `game/main.gd` handles projection, panels, animations, effects, and the three-second intermission; `game/promenade.gd` uses a native TileMapLayer for ground coordinates and upright building nodes, while `game/town_grid.gd` validates integer-cell footprints.

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

The preview shows base income **before excitement and skill tips** (10 per cast). Tips go into the bank at execution start; settlement adds the excitement-scaled fight income, one career victory, and participant XP. Positions, movement, targets, cooldowns, mana, queued casts, effects, elapsed time, excitement, and the tip counter reset between fights; coins, victories, levels, XP, and arena capacity persist for the session.

## Reusable assets

- `asset/` — original art, audio, models, textures, and shaders.
- `fonts/` — original fonts.
- `resources/` — authored sprite animations, UI textures/themes, and particle resources.
- `vfx/` — standalone effect scenes, shaders, and their supporting scripts.
- `icon.svg` and `icon.jpg` — existing project artwork.

Third-party editor tools remain in `addons/`. Gameplay does not depend on them.

## Previous prototype

The previous committed prototype remains on `codex/farm-fight-redesign`. Its uncommitted work was saved before the reset in Git stash `64b9c5f6845bb4f6991925cf5d3e6e7774d19a48`, named `Before Fight club reset: farm-fight-redesign work in progress`.
