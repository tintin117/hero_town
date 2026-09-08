# Remaster validation — 8 September 2026

Tested with Godot 4.6.2 on Windows. Automated tests pass `-- --test`, which disables loading the player's save. Persistence checks use isolated files inside `.godot/remaster_tests/`.

## Functional checks

| Suite | Result | Coverage |
|---|---:|---|
| `remaster_tests.tscn` | 166 checks, 0 failures | All four armies and five rarities; independent duplicate buildings; crew, slot, gold and research limits; combat abilities and allegiance; boss telegraphs and reinforcement cap; victory settlement; farming and queued challenges; save replacement, backup recovery, offline cap and clock rollback |
| `remaster_ui_tests.tscn` | 152 checks, 0 failures | HUD and panels at five viewport sizes, including 800 × 260; logical scaling at 100%, 125% and 150%; placement input and cancellation; duplicate selection; purchases, moves and construction during battle; next-round recovery and stat updates |
| `remaster_desktop_tests.tscn` | 14 checks, 0 failures | Native companion window, 260-pixel opening height, management expansion and restoration, adjustable height, full-window restoration, always-on-top, and logical scaling |

Native desktop tests used the project's Forward+ / Direct3D 12 renderer on an NVIDIA GeForce RTX 4080 SUPER. Logical content scaling was exercised programmatically; changing Windows monitor DPI settings was not part of these tests.

## Progression simulation

The balance harness uses the same fixed-step battle simulation as the visible game and includes the configured preparation and results durations. Its purchasing policy reserves funds for unlocked army types, then purchases affordable improvements.

| Milestone | Simulated elapsed time |
|---|---:|
| First research purchase | Immediately affordable |
| Second army | 2.61 minutes |
| Gate Captain, stage 5 | 8.8 minutes |
| Ranger Captain, stage 10 | 28.2 minutes |
| Lancer Captain, stage 15 | 40.3 minutes |
| Warlord, stage 20 | 64.78 minutes |

These measurements support the approximate one-hour target for that policy. They are not a human playtest or a promise that every formation and purchase order will finish in one hour. Ordinary combat duration varies with army strength; the untrained opening army wins in about 9.6 seconds, or 8.2 seconds with the policy's first damage purchase, to provide a quick first reward.

## Thirty-minute unattended capacity check

The full town scene completed **1,800.004 seconds and 51 rounds** headlessly, with 48 soldiers and 20 enemies at each battle's start. Farming, recovery, effects, and entity cleanup continued without population failures or gameplay errors.

- Peak scene nodes: **248**. Between-round population repeatedly returned to **173**, including the 29-minute checkpoint.
- Godot static memory: **51.03 MiB** at startup, **65.5 MiB** after the first minute, **69.52 MiB** peak, and **68.86 MiB** at completion during battle.
- The harness retained **107,999 frame samples**; measured 95th-percentile frame interval was **16.67 ms** at the configured cap. Headless timing does not measure GPU performance.

The initial resource warmup and the harness's growing frame-sample array contribute to the memory increase. Entity counts stayed bounded; this observation is not a proof that every possible long-session leak is absent. The long run began before the final UI/audio shutdown refinements; functional regressions and the subsequent native graphics run covered those final changes.

## Native graphics capacity check

A 60-second run exercised the full town presentation with 48 soldiers and 20 enemies at the start of each battle, with effects enabled and audio muted. It completed two rounds without population failures or runtime/shutdown errors.

- 3,602 rendered frames; 95th-percentile frame interval: **16.67 ms** at the configured 60 FPS cap.
- Peak scene nodes: **244**; between-round population returned to **173** nodes.
- Godot static memory: **51.47 MiB** initially, **55.40 MiB** peak, **53.80 MiB** at completion.

This is a short native graphics check on the listed GPU, not a performance guarantee for lower-end hardware. The memory figures are Godot's static-memory monitor, not total process or GPU memory.

## Reproduce

Commands and scene responsibilities are in [REMASTER.md](REMASTER.md). When running inside a filesystem sandbox, supply a separate writable log path for each process, for example:

```powershell
& $godot --headless --path . --log-file '.godot/remaster-tests.log' res://tests/remaster_tests.tscn -- --test
```

The host prints a root-certificate-store warning during headless initialization. This is separate from the game's checks and does not occur in the native graphics run.

Human review remains useful for combat readability, sound balance, companion-mode comfort, and progression choices. No game screenshots were captured; layout validation used control bounds and native window properties.
