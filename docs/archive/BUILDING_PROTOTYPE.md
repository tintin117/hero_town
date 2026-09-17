# Building gameplay prototype — 2026-09-08

Implemented in the original project through Godot MCP. Normal player saves were not loaded or modified by test scenes. The isolated companion preview is left running.

## Behavior

- Army placement starts combat automatically; rewards transition in 0.8 seconds.
- Buildings integrates class role, crew, rarity, training, cost progress, and upgrade pinning.
- Arrange holds the next battle; refunds require the current battle to finish. Resume restarts automatic combat.
- Recruitment appears immediately at home; purchases, moves, and specialization affect the next snapshot.
- Barracks has free reversible Balanced, Bulwark (+30% HP, -10% damage, 40% guard), and Vanguard (+30% damage, -10% HP, 15% guard) choices. Balanced guard is 25%; specialty training scales guard.
- Persistent objectives and the first-boss fourth army plot guide progress.
- Offline income remains half the latest five ordinary victory rates, capped at eight hours. New samples use battle time plus 0.8 seconds; historical durations remain unchanged until replaced.

## Validation

Godot 4.6.3, native Forward+ renderer, existing editor session hero-town@b809. Focused prototype: 29 assertions passed. Game/save regression: 169 checks passed. UI: 177 checks passed, including small viewport layouts. Native desktop: 21 checks passed. Preview confirms persistence disabled, transparency and transparent background enabled, compact size 1920×260, expanded workshop 1920×720, and compact restoration. Workshop screenshot visually inspected. No fresh endurance run was performed for this gameplay update; earlier companion performance results remain historical.

| Deterministic shopping policy | First boss | Second boss | Stage 20 |
|---|---:|---:|---:|
| Balanced | 3.6 min | 15.3 min | 37.4 min |
| Bulwark | 3.8 min | 12.9 min | 36.8 min |
| Vanguard | 3.2 min | 13.7 min | 35.0 min |

These are simulation times, not observed human play times. The second army arrives around 0.8–1.1 minutes. The farming stretch before boss 10 remains the main first-15-minute playtest question; no arbitrary 65-minute target or untested economy retuning was imposed.

## Review

Open Buildings, compare Barracks choices, pin an upgrade, and improve it during combat. Observe waiting recruits and next-battle effects. Close the workshop, choose Arrange, wait for battle completion, then move/refund and Resume. Defeat boss 5 and build on the fourth army slot. Review whether the first 15 minutes make the next meaningful purchase clear.

Screenshots: [workshop](../screenshots/building-prototype-workshop.png), [companion](../screenshots/building-prototype-companion.png).

Native OS click delivery to another application through transparent space was not independently verified. The native configuration tests cover transparency and input-region setup. No captain system, adjacency rules, prestige, additional currency, or expanded class roster was added.
