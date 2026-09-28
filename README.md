# Fight club

A Godot 4.6.3 idle arena prototype. Open `project.godot` and press **F5** to play.

## Play the prototype

- The game opens on a main menu: **New Game**, **Continue**, and **Quit**. New Game starts a fresh estate and asks before replacing an existing save. Continue is disabled without a valid primary or backup save; loading keeps the arena stopped. Quit from the launch menu leaves existing files untouched.
- During play, **Menu** (or Escape after closing panels/placement) saves and pauses combat, recovery, and the intermission. Continue resumes that session. Quit saves before closing; a failed save keeps the game open. Time spent in the menu grants no income or recovery.
- A short welcome explains the fight → gold → estate loop. **Start first fight** opens the arena; **Explore first** skips the introduction. **Guide** reopens it. The objective strip teaches the next useful action, shows its price and missing gold, and opens the relevant controls.
- Start with **Bram, Ivo, and Nia**. Open **Heroes** to book three heroes; Arena upgrades allow bookings of up to four and then five. Click an unowned hero to recruit them when the Recruitment Hall has space and you can afford their price.
- **Open arena** starts repeating real-time free-for-all fights. Heroes chase the nearest opponent and attack on independent cooldowns. Nia shoots from range and retreats when approached; the other four fight in melee.
- The last survivor earns **one career victory**. The other heroes retain their existing records, and everyone starts the next fight at full health.
- Each fight locks in **base income = round((100 + 5 × sum(level − 1) + 5 × sum(min(victories, 50))) × arena seats / 100)**. The first 50 wins per participating hero contribute income; career records remain unlimited. Levels, victories, seats, and Tavern sales are quoted when the fight starts. Later upgrades affect the next booking.
- Fill the **excitement bar** through fight time and skill casts. At 25 excitement, fight income becomes **1.25x** the base; at 60, it becomes **2.5x**. The live bar shows the tier and projected payout, with a pulse when a new tier is reached.
- Every skill cast pays **10 gold immediately**, at every hero level and arena size. The bank pulses and a fixed **Crowd tips +10** popup appears below earnings; nearby tips combine visually within 0.25 seconds. Small gold fly toward the bank. The final breakdown includes those tips without paying them twice.
- Every participant earns **10 XP** after a fight, with **10 extra XP for the winner**. Levels improve HP, attack, and base booking income. Roster cards show level, XP progress, current stats, and gold per skill.
- Open **Arena** for three separate upgrades: spectator seats, fighter capacity, and **Auto-fill**. Auto-fill retains ready booked heroes and fills vacancies with ready recruits, preferring the most stamina, then roster order. It runs with at least three ready heroes, up to arena capacity. Buying it enables it; click its button to switch it off/on.
- Open **Build** to place one of four support buildings on your starting estate. Click a built structure or open Build to buy its next level. All four fit without purchasing land. The **NEXT** strip opens the panel for the recommended purchase.
- **Stop after this fight** finishes and pays the current fight, then unlocks the roster. During recovery it cancels the queued fight immediately.
- Before Auto-fill, **Book rested heroes** in Heroes selects the ready heroes with the most stamina, then roster order. It stops a queued booking and lets you reopen the arena with reserves. The objective points to this button when injured bookings have a ready replacement trio; it never changes an active fight.

Gold, hero progression, recruitment, stamina/recovery, buildings, positions, and Arena upgrades save automatically. This demo uses a compact **1280×420** normal window, resizable from **960×420**. It targets **12–18 running hours** across two–three days. Closing the application grants no income or recovery; reopening restores progress with the arena stopped. There is no desktop docking, equipment, rarity, prestige, or production chain.

Fights favor **short, mobile exchanges** over large health pools, while retaining the 1.5-second attack cadence. Base HP is Bram 225, Ivo 198, Nia 165, Tuck 210, and Rook 158; Second Wind restores **20% maximum HP** (42 at level 1). After **60 seconds**, visible overtime increases damage by **10% per additional second**; healing is unchanged. This prevents two healers sustaining each other forever. Across the original 200 seeded fights with progression, the average remains **16.4 seconds**, with a **9.3–35.1 second** range. The default trio's first twenty fights average **11.5 seconds**.

## Desktop Promenade presentation

The arena sits in a shallow town strip with the project's existing Tiny Swords houses, barracks, trees, terrain, and pawn sprites. Visitors stroll along the public path, clouds and smoke drift, banners move, and spectators briefly cheer when excitement reaches a new tier. These decorations do not affect combat or consume its seeded RNG. The combat floor and Sweep effects share the same projection.

The town is a fixed **48 x 8 cell** ground strip, with each cell displayed at **48 x 24 pixels**. Explore it using the horizontal scrollbar, middle-button drag, or Shift + mouse wheel; **Center arena** returns to the fight. The HUD stays fixed, and automatic repeats preserve your view. Resizing changes the visible area, never cell coordinates or combat scale.

**Arrange** shows the grid and occupied footprints. Select a built structure, then click a green preview to move it for free. New construction uses the same preview, pans to an available estate cell, and charges only when valid placement is confirmed. Red previews overlap another building, the arena/seating reserve, the public path, or unowned ground. Escape, right-click, or leaving Arrange cancels without spending. Panels and repeating fights preserve the preview while combat/recovery continue. Roofs can extend above their ground footprint.

The starting estate owns columns **10–37** of the 48×8 grid. The arena occupies protected columns **16–31**, and row 7 is the public path. Outer columns **0–9** and **38–47** are muted expansion previews labeled **Future expansion / 100,000,000 gold / Unavailable in this demo**. They are not purchasable and are excluded from demo completion.

- The bank shows spendable gold. **At finish** shows the active fight's pending payout; **tips paid** are already in the bank. Between fights, the completed payout is explicitly labeled **paid / last fight**.
- The compact crowd board shows the score, multiplier, threshold markers, and next tier. HP stays green, mana blue, and excitement amber.
- **Heroes**, **Arena**, and **Build** are temporary panels. Only one opens at a time; close with its Close button, Escape, the same navigation button, or a click outside. Combat keeps running while inspecting them. Booking remains locked until fighting stops; recruitment and upgrades remain available.
- The bottom ribbon reports combat, the winner, and earned income. Hover the result for its full calculation and hover the winner for XP results; Heroes shows updated level/XP bars and skill tooltips.
- The interface uses native Godot controls, keyboard focus, and a scrollable roster as a fallback. Window sizing is applied at runtime without changing the project's editor or plugin settings.

No generated sprites are required for this pass. The arena floor, stands, canopy, flags, and paths use native drawing alongside the existing assets. The art-direction images remain under `concept-art/` as references, not runtime backgrounds.

## Crowd excitement

- Starts at **0/100** each fight, never decays, and caps at **100**.
- Fight time adds **1 point per simulated second**, capped at **20 points total**. Intermission and idle time add nothing.
- Each executed skill adds **8 points immediately**, including healing at full HP. Sweep adds 8 once, regardless of target count. Waiting, dead, and cancelled casts add nothing; normal hits add no excitement.
- **Normal:** below 25, **1x**. **Excited:** 25 to below 60, **1.25x**. **Wild:** 60 and above, **2.5x**. These are guaranteed tier multipliers; there is no random payout roll in this version.
- **Fight income = round(locked base income × final excitement multiplier)**. The finishing skill contributes before settlement. For a 190-gold base, the three tiers pay 190, 238, or 475 gold.
- Skill tips remain **10 gold at cast start**. They are neither multiplied nor paid again at settlement. The result shows base × multiplier, fight income, already-paid tips, and the combined total.
- The bar retains the result during the break and resets for the next fight. Rarity bonuses are deferred until heroes have a rarity attribute; levels continue to raise base income.
- Upward tier crossings trigger fireworks behind the stands. Skills adding at least 16 actual excitement within two seconds trigger a smaller burst, limited to once every four simulated seconds. Passive time and zero-gain casts do not count. Simultaneous triggers merge into the stronger celebration.

## Combat feedback

Every normal hit shows its actual damage in cream; skill damage is larger and gold, and actual healing is green. Numbers rise for 0.8 seconds and fan apart near clustered heroes. Brief flashes and sprite-only recoil leave the model's positions and ranges unchanged, and the winning attack finishes its animation before returning to idle.

Bram has a layered heavy cleave, impact debris, shockwave, and dust; Ivo spins three sweeping trails inside his exact damage area with dust around its edge; Nia fires a bright cyan beam with muzzle sparkles and an impact ring; Tuck emits rising green rings, crosses, and sparkles; Rook draws twin curved drain trails with motes flowing from victim to caster and a healing pulse. Skills have a cast flash and floor pulse, with trails lingering for 0.85 seconds. Approach and escape dashes leave tinted afterimages, speed lines, and dust; pushed heroes slide with impact dust. Skill names stay near the action; money feedback stays in the HUD. Effects use snapshot positions and never delay damage or spend the combat RNG. Existing 2D impact, shockwave, smoke, and sparkle prefabs are configured per instance without changing the source assets.

## Hero recovery

Every participant, including the winner, consumes **one stamina per completed fight**. Heroes begin with **10 stamina**. At zero they become Injured and recover for **120 seconds**, then refill to maximum stamina. Roster cards show stamina or the injury countdown. Recovery continues while the arena is closed, while panels are open, and during other fights; it grants no XP, income, or excitement. Closed-game time never advances recovery.

Without Auto-fill, repeating fights retain your booking and wait until everyone is ready. With Auto-fill enabled, ready recruits replace injured bookings temporarily, retaining the player's preferences. The three-second intermission overlaps recovery. Opening while heroes are injured queues a fight; cancellation does not reset recovery. Every new fight starts at full HP and zero mana. Injuries are temporary; heroes never die permanently.

## Support buildings and recruits

Buildings are unique, construct instantly at level 1, and have three purchased levels. Effects and prices are fixed during play.

| Building | Footprint | Baseline → level 1 / 2 / 3 | Prices in gold: build / level 2 / level 3 |
| --- | --- | --- | --- |
| Training Yard | 3×2 | 10 → 15 / 20 / 25 stamina | 250 / 150,000 / 1,000,000 |
| Infirmary | 2×2 | 120 → 90 / 60 / 45 seconds recovery | 1,800 / 100,000 / 1,800,000 |
| Recruitment Hall | 3×2 | 3 → 5 / 6 / 8 roster capacity | 200 / 350 / 900,000 |
| Tavern | 2×2 | 0 → 1 / 3 / 6 gold per occupied seat per completed fight | 100 / 300,000 / 7,000,000 |

Training adds five remaining stamina to ready heroes; injured heroes finish their current recovery and refill to the new maximum. Infirmary upgrades apply to recovery periods that begin afterward. Tavern sales are snapshotted with seats at fight start, paid once at completion, and not multiplied by excitement. The earnings display and result separate fight income, previously paid tips, and Tavern sales.

Recruitment purchases are separate from the Hall: **Tuck 150; Rook 250; Aldric 400; Vera 350,000; Oswin 500,000 gold**. Aldric uses Ivo's lancer template, Vera Nia's archer template, and Oswin Tuck's monk template, with existing red art. There are no duplicate/random recruit rolls.

The first fight funds a **100-gold Tavern**. The opening objectives then recommend training, the Hall, three reserves and the Hall's second level, the Infirmary, seating, and Auto-fill. A full replacement trio is affordable before the starters' first exhaustion when following the recommendations. Building panels show the actual before/after effect, including Tavern gold per fight at current seating. Purchases remain optional and available in any order; there are no tutorial-only rewards or time gates.

Buying all buildings/levels, all eight heroes, and all Arena upgrades completes the demo. Fighting continues afterward. Blacksmith, Minstrel Stage, and land purchases are deferred.

### Measured demo pacing

Three complete seeded simulations (7, 42, 123), using the live rules at 60 steps/second, buying the recommended milestone immediately when affordable, and following the manual reserve-booking prompt until Auto-fill, finished in **15.84–16.01 running hours**. These are running simulation times: reading, placement, and purchase decisions add time for a real player. None of the upgrades has a time gate.

| Milestone | Measured range |
| --- | --- |
| First building: Tavern | 11.1–12.9 seconds / after the first fight |
| Six heroes recruited | 1.34–1.42 minutes |
| Infirmary constructed | 2.51–2.66 minutes |
| First exhaustion / three ready reserves | 3.47–3.64 minutes |
| 150 spectator seats | 6.18–6.79 minutes |
| Auto-fill | 9.02–9.96 minutes |
| Purchases by ten minutes | 10, plus one manual lineup rotation |
| Four fighters | 2.45–2.63 hours |
| Five fighters | 7.52–7.77 hours |
| All demo purchases | 15.84–16.01 hours / 2,199–2,210 completed fights |

The economy check requires a first building within one minute, a full replacement trio before first exhaustion, ten purchases by ten minutes, seating at 5–8 minutes, Auto-fill at 8–10 minutes, four fighters at 2–3 hours, five at 6–8 hours, and completion at 12–18 hours. This replaces the earlier opening targets of 3–5 minutes for the first building and 30–60 minutes for Auto-fill. All **364** additional max/mixed-level matchups covering every three-, four-, and five-hero combination finished within **78.28 seconds**. Native-window checks also verify progression while minimized/unfocused and management layouts at 960×420, 1280×420, and 1600×560.

## Saving

The version-1 save is `user://arena_tycoon_v1.json` (Godot's Fight club user-data folder). Saves occur after settlements, purchases, moves and preference changes, every 30 seconds, and on clean window close. Writes use a temporary file, validated previous-save backup, and replacement; load falls back to the `.bak` file if necessary. Unreadable primary data is preserved as `.corrupt` before replacement. Save failures appear in the status and objective tooltip; a failed close-time save keeps the game open so unsaved progress is not discarded.

The save includes gold, career progress, ownership, stamina, remaining recovery, placements, upgrades, booking preferences, Auto-fill setting, and whether the welcome was dismissed. Older version-1 saves remain valid; established estates skip the welcome and can reopen Guide. Loading validates types, ranges, roster/XP limits, ownership and non-overlapping placement. Interrupted fights are discarded without awarding settlement, XP, wins, or stamina consumption; already-saved tips remain. Transient combat and wall-clock timestamps are not restored. Regression fixtures never write the player's save.

## Hero levels and earnings

- All heroes start at **level 1**, capped at **level 10**. Stars have been replaced by levels.
- XP needed for the next level is **30 + 20 × (current level − 1)**. Excess XP carries forward; reaching the cap clears remaining XP and displays MAX.
- XP is awarded once when the fight finishes, including to defeated participants. Unbooked heroes receive none. Level-ups apply after settlement; new stats and level bonuses take effect in the next fight.
- Each level adds **5% of original HP and attack**, rounded to the nearest integer. Growth is linear: level 10 has 145% of base stats. Skill damage scales with attack, Second Wind scales with maximum HP, and Drain still heals only actual damage dealt. Movement, cooldowns, mana, and skill multipliers stay the same.
- Each level above 1 adds **5 base gold** to a booking, and each of a hero's first **50 career victories** adds another **5**. Seating capacity multiplies this subtotal before excitement. Non-participants contribute nothing.
- Skill tips remain **10 per executed cast**, including multi-target skills, at every level. Cancelled casts pay nothing. Levels never multiply tips.

Combat stats and base income are snapshotted at fight start. Hero definitions keep their original HP and attack, so repeatedly leveling cannot compound or mutate base stats.

## Arena capacity

| Seats | Base income multiplier | Expansion cost |
| --- | --- | --- |
| 100 | 1x | Starting arena |
| 150 | 1.5x | 5,500 gold |
| 200 | 2x | 600,000 gold |

These are initial prototype prices; 200 seats is the current cap. Assume every seat is filled. Expansion adds visible seating rows and, at 150/200 seats, a covered stand with a wider canopy while leaving the combat floor, movement, and skill ranges unchanged.

Separate fighter-capacity upgrades cost **700,000** for four and **1,200,000 gold** for five. **Auto-fill costs 6,000 gold**. Smaller manual bookings remain legal after expanding, with at least three heroes.

Upgrades can be purchased while a fight runs and debit the bank immediately. The active fight retains its quoted base payout, while the next-booking preview updates immediately. Unaffordable and max-capacity purchases cannot spend gold.

For example, a level **5 + 6 + 10** trio with no career victories gets **190** base gold at 100 seats, **285** at 150 seats, or **380** at 200 seats. Round the capacity-scaled base to the nearest whole coin, then round again after applying excitement; a half coin rounds up. Skill tips are added separately.

## Small regression check

Run with a Godot 4.6 executable:

```text
godot --headless --path . --script res://game/check_fight.gd
godot --headless --path . --script res://game/check_tycoon.gd
godot --headless --path . --script res://game/check_tycoon.gd -- --opening
godot --headless --path . --script res://game/check_tycoon.gd -- --economy
```

Checks all ten trios over 200 seeded fights with ongoing leveling, two reward/regression fights, and 20 mixed-level/max-level fights, requiring exactly one survivor within 120 simulated seconds. Also checks XP thresholds, overflow, the level cap, stat scaling, flat immediate tips, movement, skills, mana, and one-time settlement. Arena checks cover the 5/6/10 example, rounding, affordability, both upgrades, capacity limits, current-fight quote preservation, and unchanged combat geometry. UI checks cover the new income breakdown, expansion purchases, instant affordability after tips, XP bars, level-up feedback, and stop/rebook/repeat controls. To capture combat, progression, and all three arena capacities, omit `--headless` and append `-- --capture`. Captures go under `.godot/`.

Excitement checks cover elapsed-time caps, exact thresholds, ordered same-frame casts, full-health healing, cancelled casts, multi-target finishing casts, payout rounding, and repeat resets. Every seeded fight also verifies accumulated excitement and multiplied settlement. UI captures include Excited, Wild, and the final income breakdown.

Recovery checks cover inactive time, invalid deltas, exact expiry, independent bench recovery, queued fights, concurrent intermission, and cancellation without resetting rest. Grid checks cover native cell conversion, overlap and protected-cell rejection, atomic moves, cancelled previews, HUD input isolation, panning, resize, and automatic repeats retaining both view and placement preview.

Combat-feedback checks cover damage/healing labels for every skill and normal hits, overkill values, preserved winning animations, coalesced HUD tips, exact rapid-excitement windows/cooldowns, merged celebrations, extended skill trails, movement trails, and transient-node cleanup. The default trio's first twenty fights with seeds 0–19 produce 18 Excited and 2 Wild results. All ten trios over 200 seeded fights produce 0 Normal, 53 Excited, and 147 Wild results. The regression check requires a 12–30 second average across these fights, and still requires every fight to terminate within 120 seconds. Mobility checks cover shared role behavior, threat detection, dash cooldowns, pursuit commitment and expiry, target death, no dash rewards, escape space at the boundary, physical pushback, interrupting dashes, defeat, and fight resets. A separate balance check starts fresh level-1 heroes for each of 20 seeds in all six lineups containing Nia: she wins 54/120 fights (45%), with no undefeated lineup. Fresh heroes prevent winner XP from skewing this check.

Promenade checks also cover opening/switching/closing panels, Escape and outside dismissal, focus return, booking through the hero panel, purchasing through Arena, combat continuing behind an open panel, cheering feedback, and layouts at 960×420 and 1600×560. Captures include the closed promenade and both panels.

The tycoon check covers injury boundaries, eight-hero recruitment, 3–5 fighter bookings, manual/automatic rotation, Tavern quotes, victory-income limits, land ownership, purchases, save validation/backup recovery, and management UI. It also checks the welcome, first-fight purchase prompt, affordable/visible placement, rotation guidance, and legacy-save compatibility. Menu checks cover fresh/continued games, canceled replacement, backup recovery, paused combat/recovery, write failures, and Quit without overwriting saves. `--opening` measures three seeded openings through Auto-fill. `--economy` runs three seeded complete progressions at 60 simulation steps per second, buying each recommended milestone as it becomes affordable and manually rotating when prompted before Auto-fill. Logs, timing JSON, and optional `--capture` screenshots go under `.godot/`.

Edit definitions, fixed cost tables, and milestones in `game/fight.gd` to tune progression. `advance(delta)` returns ordered combat events; rendering never decides damage or rewards. `game/main.gd` handles panels, projection, and intermission; `game/combat_feedback.gd` owns transient effects. `game/promenade.gd` presents buildings and native ground cells; `game/town_grid.gd` validates footprints and ownership; `game/save_game.gd` validates and persists durable progress.

## Movement and ranges

The arena is a circle with a **260-unit radius**, projected as an oval with upright, depth-sorted sprites. Logical distances are independent of window size. Spawn positions for the booked three to five heroes are evenly spaced and assigned with the seeded RNG, which also sets initial cooldown offsets and simultaneous-action priority.

- Heroes choose the **nearest living opponent every 0.25 seconds**, after losing their target, and before attacking or casting, except during melee pursuit commitment below. Equal distances retain the current target; other ties use seeded RNG.
- Melee heroes move at **90 units/second** and attack within **45 units**. Nia moves at **75 units/second**, approaches beyond **160**, holds at **110–160**, and retreats below **110**. At the boundary she stands and fights.
- Normal attacks have individual **1.5-second cooldowns**. Attacks and casts pause movement for **0.2 seconds**; casts do not reset the normal cooldown.
- Heroes stay inside the boundary and gently separate overlapping bodies. This open floor uses direct steering without obstacles or navigation meshes.
- All melee heroes share an **approach dash**: when a target is more than 70 and at most 200 units away, dash up to **110 units in 0.22 seconds**, closing toward melee range. Cooldown: **4.5 seconds**. Keep pursuing that target for those 4.5 seconds instead of abandoning an escaping archer for another passing melee hero. Target death ends the commitment immediately; expiry restores nearest targeting.
- All ranged heroes share an **escape dash**: a living opponent must be actively targeting them within **100 units**. Choose open space away from nearby opponents, including a sideways route at the fence, and dash up to **110 units in 0.22 seconds**. Cooldown: **12 seconds**, giving melee heroes multiple approach opportunities between escapes. If there is no safer destination, stand and fight.
- Dashes have a half-second opening cooldown, use a fixed direction, and pause attacks/casts until arrival. They add no damage, invulnerability, mana, excitement, or tips. Skill damage can interrupt a dash with pushback. Role behavior uses the existing ranged/melee attribute, without hero-specific movement code.
- Every damaging skill pushes surviving victims **65 units away from its impact origin over 0.22 seconds**, clamped to the arena boundary. Sweep pushes each victim radially. Damage and the single cast tip resolve immediately; the subsequent slide adds no damage or reward. Pushback changes positions without silencing a ready cast; normal range checks still apply. Defeated heroes do not slide, and settlement clears all movement.
- Damage is immediate. Shot and impact effects are visual feedback, not delayed projectiles. Sweep's visible oval is the projection of its actual circular damage area.

## Skills and mana

Every hero has one skill. Mana starts at **0/100** each fight: **+25** for landing a normal hit and **+15** for surviving one. Full mana prioritizes a cast over the next normal attack and resets to zero when the cast begins. Offensive skills wait for an enemy in range; waiting pays nothing and does not block other heroes. Skills generate no mana. If both sides become ready, eligible attacker and defender casts resolve in that order before another normal attack; a killed defender cannot cast. Combat ends as soon as one survivor remains.

| Hero | Range | Skill |
| --- | --- | --- |
| Bram | 45 units | **Heavy Strike:** 2x attack damage to the nearest enemy. |
| Ivo | 90-unit radius | **Sweep:** attack damage to every enemy inside the circle. |
| Nia | 160 units | **Snipe:** 2.5x attack damage to the nearest enemy. |
| Tuck | Self | **Second Wind:** restore 20% of maximum HP to himself. |
| Rook | 45 units | **Drain:** 1.5x attack damage to the nearest enemy; heal by actual damage dealt. |

Targeting ties use the seeded RNG, and skills reevaluate targets when they cast. Skill amounts are rounded to the nearest integer without normal-attack variation. Healing is capped at maximum HP; overkill cannot increase Drain healing. Second Wind at full HP still spends mana and earns a tip. Each cast earns one tip regardless of the number of targets. Cancelled casts earn nothing.

The preview shows base income **before excitement and skill tips** (10 per cast). Tips go into the bank at execution start; settlement adds the excitement-scaled fight income, one career victory, and participant XP. Positions, movement, targets, cooldowns, mana, queued casts, effects, elapsed time, excitement, and the tip counter reset between fights; gold, victories, levels, XP, and arena capacity persist for the session.

## Reusable assets

- `asset/` — original art, audio, models, textures, and shaders.
- `fonts/` — original fonts.
- `resources/` — authored sprite animations, UI textures/themes, and particle resources.
- `vfx/` — standalone effect scenes, shaders, and their supporting scripts.
- `icon.svg` and `icon.jpg` — existing project artwork.

Third-party editor tools remain in `addons/`. Gameplay does not depend on them.

## Previous prototype

The previous committed prototype remains on `codex/farm-fight-redesign`. Its uncommitted work was saved before the reset in Git stash `64b9c5f6845bb4f6991925cf5d3e6e7774d19a48`, named `Before Fight club reset: farm-fight-redesign work in progress`.
