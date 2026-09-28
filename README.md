# Fight club

A Godot 4.6 idle arena game. Open `project.godot` and press **F5**.

## Play the core loop

**Book an event → fight 10 rounds → review rewards and hero condition → prepare the next event.**

- **New Game** starts with Bram and Ivo in a two-fighter arena. **Continue** preserves an existing estate and loads with combat stopped. New Game asks before replacing a save.
- **Start event / 10 fights** books a finite event with your preferred lineup. Fights repeat with three-second intermissions until ten fights have completed. The arena then waits for a manual booking; the previous lineup remains selected.
- **End after fight** finishes and pays the current fight, then ends the event early. **End event** stops immediately during intermission or recovery without resetting recovery. Starting another event resets only the event counters.
- The event button above the arena shows completed rounds. Open it to review total gold and fight XP, each participant's XP, and current levels, stamina, injury and recovery. It highlights **Review results** when the event ends. Rewards are already paid; reviewing never grants a second payout. **Manage heroes** opens lineup preparation.
- The first completed fight can fund **Nia for 100 gold**. The starting Hall capacity is three, so no building is needed for that first reserve.
- **Heroes** contains recruitment, readiness, stamina, injury meters, XP, stats, and preferred lineup controls. Click an unavailable preferred hero to remove the preference; unavailable heroes cannot be added to bookings.
- Without Auto-fill, the entire preferred lineup must be available before another fight starts. **Use rested heroes** replaces the preferences with available reserves and keeps the current event running.
- **Auto-fill**, purchased for 6,000 gold, retains ready preferences and fills vacancies from ready reserves within the booked event, ordered by stamina then roster order. It never selects injured, exhausted, or training heroes. It can run with two ready heroes up to the purchased fighter capacity, but never books another event.
- If an active event lacks eligible fighters, it waits and automatically resumes when recovery permits. Waiting does not consume a round. Recovery and training continue after an event ends. Basic recovery never requires a building, food, or gold.
- **Build** constructs and upgrades facilities. Click a built facility or its **Manage** button for training, patients, or meals. The Recruitment Hall opens the roster.
- **Arrange** moves buildings freely on owned ground. Construction charges only after valid placement. Escape or right-click cancels a preview without spending.
- Opening management panels does not stop combat, recovery, or training. **Menu** pauses simulation and saves; Continue resumes the session. Closing the game grants no offline progress.

This prototype adds finite events without event goals, pre-fight buffs, betting, title progression, production chains, or permanent hero deaths.

## Fatigue and injury

Every participant spends **one stamina per completed fight**. Maximum stamina starts at ten. At zero, the hero enters **Resting** for **60 running seconds**, then refills to the current maximum.

Every defeat adds one point to an independent **three-point injury meter**. The third defeat causes an injury with **180 seconds of recovery work**. Hospital beds accelerate that work; everyone outside a bed still recovers at normal speed. Completing injury recovery clears the meter.

A healthy bench hero loses one injury-meter point per uninterrupted **60 seconds outside combat**. Fatigue recovery and Gym training count as bench time. Starting a fight resets that interval; victories do not remove meter points, and unused bench time cannot be banked. Fatigue and injury recover concurrently. Both conditions must permit a return to combat.

Every new fight starts with full combat HP and zero mana. Damage during a fight is separate from stamina and long-term injury recovery.

## Buildings and recruits

Buildings construct instantly, are unique, and have three purchased levels. All four fit on the starting estate. Internal IDs and logical placement footprints remain compatible with old saves.

| Building | Footprint | Levels 1 / 2 / 3 | Gold: construct / level 2 / level 3 |
| --- | --- | --- | --- |
| Gym | 3×2 | 15 / 20 / 25 maximum stamina; 1 / 2 / 3 training slots | 250 / 150,000 / 1,000,000 |
| Hospital | 2×2 | 1 / 2 / 3 beds; 2× / 3× / 4× injury recovery | 450 / 100,000 / 1,800,000 |
| Recruitment Hall | 3×2 | 5 / 6 / 8 owned-hero capacity, from a baseline of three | 200 / 350 / 900,000 |
| Restaurant | 2×2 | 1 / 3 / 6 gold per occupied seat per fight; 30 / 20 / 10 seconds between meals | 100 / 300,000 / 7,000,000 |

**Recruit prices:** Nia 100; Tuck 150; Rook 250; Aldric 400; Vera 350,000; Oswin 500,000. Bram and Ivo are the two starters. Each named hero can be recruited once; there are no random recruit rolls. Aldric shares Ivo's combat template, Vera shares Nia's, and Oswin shares Tuck's.

### Gym

Assign healthy, unbooked bench heroes below level ten. Each trainee earns **5 XP every 30 seconds**, consumes no stamina, and cannot enter the arena. Leave at least two other owned heroes outside training and injury; those two may be temporarily fatigued.

Training repeats until recalled or the hero reaches the level cap. **Recall** is immediate and free, discarding only the incomplete training interval. At maximum level, a trainee automatically releases the slot. Stamina upgrades add five remaining stamina to heroes not undergoing fatigue recovery; resting heroes refill to the new maximum when their countdown finishes.

### Hospital

Patients are admitted automatically, oldest injury first with hero ID as a stable tie break. A fresh injury takes **90 / 60 / 45 seconds** in a level 1 / 2 / 3 Hospital. Waiting heroes continue natural recovery. Capacity and rate upgrades apply immediately while preserving completed recovery work. The panel shows occupied beds, the queue, and simultaneous fatigue when present.

### Restaurant

The Restaurant retains audience sales and serves manually purchased meals:

- **Light meal:** 20 gold; restores up to five stamina.
- **Full meal:** 50 gold; restores maximum stamina.

Food cancels ordinary fatigue recovery but never cures an injury or reduces the injury meter. Active fighters, injured heroes, trainees, unowned heroes, and full-stamina heroes cannot be fed. The panel shows the actual stamina gain before spending. A shared serving cooldown starts after a successful meal; upgrades affect later services, not an already-running cooldown. No automatic meal spending occurs.

## Arena, combat, and rewards

Spectator seats start at **100**. Expansions to **150 / 200** cost **5,500 / 600,000 gold**. Fighter capacity starts at **two**; upgrades to **three / four / five** cost **1,500 / 700,000 / 1,200,000 gold**. Smaller legal bookings remain available after expansion.

Each fight snapshots combat stats, arena seats, and Restaurant sales. Changes made during combat affect later bookings.

**Base fight income:** `round((100 + 5 × sum(level − 1) + 5 × sum(min(career wins, 50))) × seats / 100)`.

Excitement starts at zero, never decays within a fight, and caps at 100. Fight time supplies one point per second, capped at twenty; executed skills add eight each, once per skill regardless of targets. Normal attacks add none.

| Final excitement | Multiplier |
| --- | --- |
| Below 25 | 1× |
| 25 to below 60 | 1.25× |
| 60 and above | 2.5× |

Fight settlement pays `round(locked base × final excitement multiplier)`. Every executed skill pays **10 gold immediately**. Tips are not multiplied or paid twice. Restaurant sales are paid separately at completion and are not multiplied by excitement. The finishing skill contributes before settlement.

Every participant earns **10 XP**, with **10 more for the winner**. The winner gains one career victory. Level requirements are `30 + 20 × (level − 1)` XP, with overflow retained and a level cap of ten. Each level adds five percent of original HP and attack, rounded; growth is linear. Skills, movement ranges, mana, and cooldowns otherwise keep their established rules.

| Hero template | Ability |
| --- | --- |
| Bram | Heavy Strike: 2× attack against the nearest enemy in melee range |
| Ivo / Aldric | Sweep: attack damage to every enemy within a 90-unit radius |
| Nia / Vera | Snipe: 2.5× attack against the nearest enemy within 160 units |
| Tuck / Oswin | Second Wind: recover 20% maximum HP |
| Rook | Drain: 1.5× attack in melee; heal only actual damage dealt |

Fighters chase nearby enemies, melee heroes dash into range, archers retreat and escape, and skills can push survivors. After sixty seconds, overtime raises damage by ten percent per additional second without increasing healing. Movement and presentation effects do not consume the combat RNG.

## Sunnyside desktop town

The default window is **1280×420**, resizable from **960×420**. The town retains its **48×8 logical cells**, displayed as square **32×32 pixels** (16px art at 2×), for a 1536px-wide strip. Use the horizontal scrollbar, middle-button drag, or Shift + wheel; **Center** returns to the arena. Resizing does not change saved cell coordinates or combat geometry.

Owned land remains columns **10–37**; the arena reserves columns **16–31** and row seven is the public path. Outer land is a non-purchasable preview. Building roofs may extend above their occupied ground footprints.

The terrain, gabled facilities, open training yard, visitors, spectators, and all eight heroes use the supplied Sunnyside assets. Layered actors share one animation clock and foot anchor. Spear, bow, and staff overlays preserve class identity; composite recoil, tinting, and afterimages affect the complete actor. The circular arena and its effects use uniform projection, with seating wings beside the floor. Trainees, patients, and resting heroes appear near their facilities. Those decorative assignments never delay model updates.

Sunnyside World by **Daniel Diggle**: [source and usage terms](https://danieldiggle.itch.io/sunnyside). See `resources/art/SUNNYSIDE_CREDITS.md`. Original pack files remain untouched.

## Saves

The existing `user://arena_tycoon_v1.json` path now stores **version 2**, with fatigue, injury, injury order, bench decay, Gym assignments, and Restaurant cooldown. Version-1 saves migrate automatically: old “Injured” countdowns become fatigue with their exact remaining seconds, Nia stays owned, and old fighter tiers map to the same purchased capacities. Gold, progression, buildings, and logical positions are preserved.

The launch menu never overwrites an unread save. Saving validates the state, writes a temporary file, and keeps a backup; corrupted-primary recovery remains available. Interrupted fights are discarded without additional settlement, XP, wins, stamina consumption, or injury credit. Already-saved skill tips remain. Menu time and closed-game time do not advance simulation. Test fixtures use isolated `.godot/` saves, never the player's file.

Event counters and the results panel last for the current session, until the next booking. Closing and reopening retains earned progress and the preferred lineup, but loads with no active event or prior event report. Menu/Continue within the same session preserves the paused event.

## Verification and measured pacing

Run with a Godot 4.6 executable:

```text
godot --headless --path . --script res://game/check_core_loop.gd
godot --headless --path . --script res://game/check_arena_event.gd
godot --headless --path . --script res://game/check_fight.gd
godot --headless --path . --script res://game/check_tycoon.gd
godot --headless --path . --script res://game/check_tycoon.gd -- --opening
godot --headless --path . --script res://game/check_tycoon.gd -- --economy
```

Checks cover all 420 two–five-fighter combinations at seeded max/mixed levels, focused duels, one-time combat rewards, fatigue and injury boundaries, Hospital overflow/large time steps, Gym eligibility/recall/caps, meal validation/cooldown, unavailable bookings, continuous recovery, v1/v2 saves, backups, facility UI, and menu pause. The longest checked matchup was **80.08 seconds**. Rendered layout checks cover 960×420, 1280×420, and 1600×560. Logs and captures belong under `.godot/`.

The event prototype uses a fixed **ten-fight** booking. A pacing probe at sixty simulation steps per second (seeds 7, 42, 123) includes recovery and intermissions:

| Roster and management | Ten-fight event duration |
| --- | --- |
| Three heroes, manually rotating available reserves | 4:31–4:35 |
| Six heroes at Auto-fill unlock, three fighter places, level-1 Hospital | 2:56–3:08 |
| Unchanged starter duo, waiting through injuries | 8:16–11:12 |

Recruitment and roster changes remain available during events, with each fight paying immediately. These durations are playtest references, not guarantees; injuries and lineup choices change the pace.

The following three complete progression simulations predate finite events and assume continuous bookings (seeds 7, 42, 123). They used live combat rules at sixty simulation steps per second, purchasing recommended milestones when affordable and manually rotating before Auto-fill, without meals or Gym assignments. They remain a baseline for the unchanged prices, not a measured completion time for manual event booking.

| Milestone | Measured running time |
| --- | --- |
| First reserve, Nia | 11.83–13.35 seconds / after one fight |
| Restaurant | 23.63–25.15 seconds |
| Hospital | 2.15–2.32 minutes |
| Three-fighter capacity | 3.14–3.43 minutes |
| 150 spectator seats | 6.64–7.08 minutes |
| Auto-fill | 8.96–9.99 minutes |
| Four-fighter capacity | 2.55–2.73 hours |
| Five-fighter capacity | 8.34–8.43 hours |
| All demo purchases | **16.14–16.60 hours / 2,819–2,853 fights** |

The continuous-booking baseline fits the previous **12–18 running-hour target**. Manual booking adds downtime; economy balance needs another playtest before treating that target as validated for events. This prototype leaves existing rewards and prices intact.

## Reusable assets

- `asset/` — original art, audio, models, textures, and shaders.
- `fonts/` — original fonts.
- `resources/` — authored sprite animations, UI textures/themes, and particle resources.
- `vfx/` — standalone effect scenes, shaders, and their supporting scripts.
- `icon.svg` and `icon.jpg` — existing project artwork.

Third-party editor tools remain in `addons/`. Gameplay does not depend on them.

## Previous prototype

The previous committed prototype remains on `codex/farm-fight-redesign`. Its uncommitted work was saved before the reset in Git stash `64b9c5f6845bb4f6991925cf5d3e6e7774d19a48`, named `Before Fight club reset: farm-fight-redesign work in progress`.
