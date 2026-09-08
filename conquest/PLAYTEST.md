# Real-duration leave-and-return playtest — 9 September 2026

Status: complete. All gameplay preparation used runtime mouse input. No accelerated clock or elapsed-time mutation.

## Isolation

User save backed up to `user-save-before-playtest.json`. The original state contained seven warriors, one mage, Healing learned, two lands and one development level. The test uses `playtest.tscn` and the separate `user://conquest_playtest_20260909.json` save. The editor stays open throughout.

## Preparation observed

- Won Sunlit Meadow with three warriors.
- Built academy, trained two warriors and first mage through their popup buttons.
- Won Amber Quarry with five warriors and Fireball mage; result reported 120 Fireball damage.
- Chose the longer two-warrior project (40 gold / three minutes) and Healing (60 gold / five minutes).
- Before-leaving snapshot at 00:30:41.379 Bangkok: 83.728 gold; +20/min; five warriors + one mage; two lands; one free plot; warrior remaining 137.218 seconds; Healing remaining 288.066 seconds; recovery remaining 44.554 seconds.
- Closed only game at 00:30:50 Bangkok. Earliest permitted reopen: 00:40:50.
- River Watch preview clearly showed +10 gold/min, two plots, and a hint that a deeper frontline and healing could help.

One malformed diagnostic eval used mixed indentation and paused the debugger before the longer-project phase. Only the isolated game was restarted. This was test instrumentation error, not a game-code failure.

## Return and conquest

Completed below. State and screenshots were recorded before any preparation action.

## Return result

Reopen requested at 00:41:03 Bangkok, **10 minutes 13 seconds after stopping the game**. The first recorded running state at 00:41:12.908 had 294.237333 gold, seven warriors, one mage, Healing learned but Fireball still equipped, no projects and zero recovery. Ownership and existing army were preserved.

The before/after state timestamps span 631.528 seconds (including the seconds recording/closing and reopening). Observed gain: 210.509333 gold. Expected at 20/min: 210.509333 gold; numerical difference under 0.000000001. Projects completed once. No collection click or repeat project was required.

**Objective bug found and fixed:** `_ready()` produced a detailed offline summary, but `_process()` consumed the same completion events and immediately replaced it with the generic completion message. Offline completions now keep their building highlights while leaving the return summary intact. Gains are shown first, followed by a compact last-outcome/feedback block so the footer fits. The saved full battle result is retained.

`return_check.gd` replays the unmodified departure snapshot against the real current clock and asserts the summary remains after processing frames, both projects finished and recovery ended. It passed, with a screenshot. This is a regression replay after the real ten-minute test, not a substitute for the measured absence; its gold figure is higher because additional real time had passed.

## Preparation choice and conquest

Clicked Academy → Equip Healing → Close → Launch expedition. No currency deduction or additional training timer was needed to equip. River Watch won through its complete normal presentation: Healing restored 400 health, frontline ended at 86 health, every trained troop remained owned. Permanent income rose from 20 to 30/min and free plots from one to three. The result explicitly reported 400 health restored. No active skill input or battle skip was used.

## Prioritized friction and recommendations

1. **Fixed: return gains disappeared.** This hid both gold earned and the fact Healing unlocked. Summary now remains visible until a subsequent action replaces it.
2. **Next usability improvement: explain spell effects in the academy.** The frontier hint makes Healing a reasonable choice and equipping shows the selected spell, but the academy does not state healing amount/cadence or Fireball damage/cadence. Add a short plain-language effect description before adding any more systems.
3. **Battle result is visually disclosed early.** The frontier marks River Watch owned and shows the final valley message while combat is still animating, because the outcome is committed first for persistence. Consider showing an expedition-in-progress state until the presentation ends while keeping the save transaction unchanged.
4. **Terminal reward has limited use in this prototype.** The two new plots are awarded, but the only buildable plot-consuming building is the already-built academy. Estate development and warrior training remain available, yet there is no next conquest. This is a known opening-loop boundary; do not interpret it as evidence of long-term retention.

The next conquest reward was clear before leaving; the return state was accurate; the corrected summary communicates the gains; the preparation choice produced a visible healing effect and successful conquest. These are concrete observations, not verification of subjective enjoyment or retention.

## Preservation and validation

The original user save was not used by the isolated playtest. At the end it still had seven warriors, one mage, Healing learned, Fireball equipped, two lands, one free plot and one development level. Its only change between initial backup and game shutdown was 5.4 seconds of normal income (+2.25 gold). The original scene was reopened at the end, applying its own legitimate offline income; all non-gold/timestamp progression fields match the original backup. Same Godot editor process 30392 throughout; no editor restart.

The final playtest game logs and editor cursor showed no new gameplay errors. Regression replay passed. Earlier diagnostic indentation error was isolated to the testing command and recovered before the real absence.

Evidence: `playtest-before.png`, `playtest-return.png` (bug), `playtest-return-fixed.png` (regression replay), `playtest-river.png`, `playtest-victory.png`; machine-readable before/return/battle states are alongside them.


The regression departure fixture is versioned at fixtures/return_departure.json. Raw QA snapshots, save backups, and screenshots referenced above are local evidence artifacts and are not part of the source commit.
