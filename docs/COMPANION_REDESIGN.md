# Desktop companion redesign — 8 September 2026

Implemented directly in D:/Optics Team/Godot/hero-town through the original Godot AI session hero-town@b809 (Godot 4.6.3). The additional worktree editor was closed; no game changes were transferred from it.

## Presentation

- Native companion surroundings are transparent. A conservative scenery outline plus the control strip defines the native mouse region; management temporarily restores full-window interaction. The outline deliberately includes sprite padding, so this is not per-pixel click-through inside the town.
- Options offers Waterside village, Terraced castle town, and Scattered hamlet. Each uses authored edge profiles and the inspected Tiny Swords artwork. The castle has a decorative raised terrace; all combat remains on the original uninterrupted ground.
- Trees, bushes, sheep and the waterside duck provide bounded ambient animation. Reduced effects freezes this scenery animation.
- The companion uses one centered 820 x 44 control strip at a 1920-pixel display width. Contextual hints appear above it when needed. Start-now and challenge/farm controls remain in expanded play; compact combat stays automatic. Boss HUD is shown in expanded play.
- Management uses a solid readable panel. The former wood-table crop incorrectly included gaps between atlas pieces.

No combat rules, formation coordinates, placement cells, costs, rewards, or progression pacing changed. Landscape is an additive integer setting; saves without it default to waterside and keep their progression.

## Validation

| Check | Result |
|---|---|
| Game/persistence suite | 169 checks, 0 failures, including legacy saves and landscape save/reload |
| UI suite | 162 checks, 0 failures; five viewport sizes, logical scaling, all three terrain footprints and unchanged army records/gold on switching |
| Native desktop suite | 21 checks, 0 failures; transparent viewport and native flag, alpha-zero corner, mouse-region coverage, management expansion, height adjustment, restoration and opaque full-window mode |
| MCP native interaction | Research button click opened panel; Escape restored 1920 x 260 at (0,772); mouse placement at cell (7,2) added exactly one barracks and restored compact size |
| Native capacity run | 60.009 s, 3,600 frames, 2 rounds, 48 soldiers and 20 enemies; no population failures; p95 frame interval 16.67 ms |

Capacity run: Forward+ / D3D12 on NVIDIA GeForce RTX 4060 Ti. Peak nodes 261; static memory 53.17 MiB initially, 56.98 MiB peak, 55.38 MiB final. This was a short full-window native graphics run, not a new thirty-minute soak or a guarantee for other GPUs.

Tests use -- --test and isolated .godot/remaster_tests files. The dedicated companion_preview.tscn also disables persistence before loading GameState, allowing safe launch through MCP project_run without custom CLI arguments. MCP confirmed persistence was disabled throughout preview and interaction checks. The normal player save was never loaded by these preview runs.

The UI and native suites emitted host sandbox certificate/cache warnings; their assertions passed. An initial new-setting validation failure was fixed before the final 169-check run.

## Rendered artifacts

These are native game framebuffer captures at actual size, including alpha, captured through Godot AI. They are not desktop-composited screenshots.

- [Waterside, 1920 x 260](screenshots/companion-waterside.png)
- [Castle, 1920 x 260](screenshots/companion-castle.png)
- [Hamlet, 1920 x 260](screenshots/companion-hamlet.png)
- [Research, 1920 x 720](screenshots/companion-research.png)

Native OS delivery of an outside click to a different application has not been independently exercised. The configured native polygon excludes outer empty areas, and the game receives clicks on its controls. Computer-use desktop capture approval timed out, so no claim is made that framebuffer alpha alone proves desktop compositing or cross-application click delivery on every driver.

## Review

Keep Embed Game on Play disabled for native companion mode. To review without touching player progress, run res://tests/companion_preview.tscn; it creates temporary demonstration armies and mutes audio. Normal play remains scenes/main_menu.tscn. Landscape selection is in Options.
