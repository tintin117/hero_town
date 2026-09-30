# Fight club — balance report (gate G5)

Pacing measured with a deterministic bot against the GDD targets (§5 hype, §13 progression map, §17 validation).
Everything here is `.tres` tuning; no rules code changed.

## How to rerun

```
<godot console exe> --headless --path . --script res://game/tests/report_progression.gd -- --seeds=7,42,123
```

Runs the real `Game` + `CombatSim` through public commands only (policy documented at the top of `game/tests/sim_bot.gd`):
replant at once, strongest lineup, cash any ripe story as Main Event, buy the cheapest affordable item by fixed
priority (recruits, Hall, Gym, Restaurant, Office, seats, fighter capacity, upgrades; props only when one costs <= 15 % of gold),
bell threshold 70. Idle waits jump to the exact bell time (hype is closed form); fights advance to their end.
3 seeds x 18 h + the threshold sweep takes ~3-4 min (one 18 h seed ~30 s). Output: stdout summary,
`.godot/progression_<seed>.json`, `.godot/progression_sweep.json`.

Options: `--hours=`, `--sweep=0|1`, `--sweep-seeds=`, `--fight-step=0.016667` (replay fights at 60 Hz),
`--set=hype_tau=40,series_pause=8` (tuning), `--price=gym:2=30000` / `--hero=6=470000` / `--effect=restaurant:3=4.0`
(in-process overrides for experiments), `--skip=gym,props,...` (ablation: the bot never buys that category).

Step-size check: a 2 h run with fights replayed in 1/60 s steps gives exactly the same totals as the one-jump-per-fight run
(457,501 gold, 79 series, 8 main events; 0.0 % difference). Sim outcomes are precomputed per bout, so step size only moves
when the bot may spend, and gold only changes at a bout's end.
The bot's total gold reconciles with the game (`gold check 0`; a few tens of gold of mid-fight tips appear only when the horizon
cuts a bout).

## Result (median of seeds 7 / 42 / 123, final tuning)

| Milestone | Time |
|---|---|
| First bell (series starts) | 42 s |
| First bout paid / 3rd fighter (Nia) | 52 s |
| First building (Restaurant) | 69 s |
| First series finished | 86 s |
| Recruitment Hall L1 | 86 s |
| 4th and 5th fighters (Tuck, Rook) | 2.3 min, 2.6 min |
| Gym, Promotion Office L1 | 3.7 min, 4.0 min |
| Hall L2, 6th fighter (Aldric) | 5.1 min, 5.3 min |
| All four props stocked | 6.4 - 7.7 min |
| First story ripe / first Main Event | 8.3 min |
| Fighter capacity 3 | 9.1 min |
| Seats 150 | 13.5 min |
| Fame tier 2 (Local Arena) | 16.7 min |
| Gym L2 / Office L2 | 25 min / 37 min |
| Gym L3 | 74 min |
| Restaurant L2 | 2.0 h |
| Fame tier 3 (City Stadium) | 2.2 h |
| Seats 200 | 3.3 h |
| Fighter capacity 4 / 5 | 4.5 h / 6.0 h |
| Hall L3, Vera, Oswin | 7.5 h, 8.0 h, 8.6 h |
| Office L3 | 11.3 h |
| Fame tier 4 (Grand Coliseum) | 12.4 h |
| Restaurant L3 = every purchase bought | 14.3 h |

| Metric | Value |
|---|---|
| Series per hour | 36-40 in hours 0-5, 22-26 in hours 6-13 (more fighters = longer series) |
| Bouts per series | 3.6 (first 2 h), 5.3 (whole run) |
| Series cycle | hype build 29 s + fights 61 s early (~90-95 s); 20 s + 103 s late |
| Gold per hour (income) | 168k (hour 1), 565k (hour 4), 920k (hour 10) |
| Income split | tickets 83 %, tips 1.5 %, concessions 4.8 %, main-event uplift 10.9 % |
| Stories | 400-900 created, 41-45 cashed per run (about 3 per hour, one per ~15-20 min), kinds: comeback 19, legend 14, rivalry 5-9, grudge 2-3, win streak 1-3 |
| Wall time | ~30 s per 18 h seed |

### Hype threshold sweep (bell threshold, first 2 h, mean of 6 seeds, same bot)

| Threshold | 50 | 55 | 60 | 65 | 70 | 75 | 80 | 85 | 90 | 95 |
|---|---|---|---|---|---|---|---|---|---|---|
| Income / h (compounding buys) | 254k | 255k | 260k | 261k | 259k | 261k | 252k | 241k | 219k | 184k |
| Frozen (no buys, 2 fighters, 100 seats) | 61.5k | 62.4k | 61.9k | 60.9k | 59.3k | 57.8k | 54.8k | 51.6k | 45.9k | 39.0k |

The live curve is a plateau from 60 to 75 (within 1 %, the argmax hops between 65 and 75 with seed noise) and falls off
above 80; centre of the plateau ~67, matching the GDD's 65-70. The frozen curve (start of the game, no Office) is flat from 50 to 65.
Before tuning the peak was 50 and monotonic (see below).

## What changed (all in `.tres`)

Baseline = the tuning at commit 718f3dd (seed 7 unless noted).

### Stories: ripened every other series, 64 % of income

Before: 230 Main Events in 237 series, main-event uplift 64 % of income, first cash at 2.8 min, gold/hour 575k in hour 1.
Cause: `story_time_seconds = 6` (a timed story gained 10 ripeness per minute) plus per-bout steps of 10-25 on a 2-4 fighter
roster that meets constantly, so the same rivalry / streak was re-created and re-ripened every series.

| Key | Before | After |
|---|---|---|
| `story_time_seconds` | 6 | 240 |
| `story_streak_step` | 25 | 3 |
| `story_rivalry_step` | 20 | 1.5 |
| `story_grudge_step` | 15 | 1.5 |
| `story_comeback_step` | 15 | 0.4 |
| `story_legend_step` | 10 | 0.5 |
| `story_start` | 20 | 15 |

After: 41-45 cashes per 14 h (5 per hour in hour 0 while only two fighters exist, 1-5 per hour later), first at 8.3 min,
uplift 10.9 % of income. Steps were chosen so no kind dominates (comeback and legend still lead because the bot's small
roster produces them most; win streaks need ~13 straight wins, so they rarely ripen).
`story_ripe_threshold` (60) and `main_event_bonus` (2.0, x3 at 100) are untouched; the bot cashes at the threshold, so the
average multiplier is ~x2.2-2.4.

### Hype: series every ~1.5 min and best threshold near 70

Before (`hype_tau` 50, `afterglow_factor` 0.3, `series_pause` 3): with a ~50 s bo5 the crowd re-warms to ~35-45 hype from
the afterglow, so waiting was cheap to skip: the income curve fell monotonically from a threshold of 50
(3 seeds: 366k/h at 50, 334k at 70, 180k at 95). The optimum is where `tau / (100 - thr)` equals
`(B + F) x 0.9 / (10 + 0.9 thr)` (build time B, series time F), so a shorter tau and a longer series pull it up to 70.

| Key | Before | After | Why |
|---|---|---|---|
| `hype_tau` | 50 | 40 | first bell at 42 s instead of 52 s; pushes the optimum up |
| `afterglow_factor` | 0.3 | 0.2 | restarts near the GDD's "from 15" (afterglow 0.2 x ~90 excitement = ~18 hype); low thresholds no longer skip most of the build |
| `series_pause` | 3 | 8 | bouts breathe (crowd chatter); series 61 s of fights instead of ~50 s |

After: first bell 42 s, series every 89-98 s early (GDD target 1.5-3 min), plateau peak at 60-75.
`hype_start` (15) unchanged.

### Prices and effects: content took 6 h, Gym and Restaurant did nothing

Ablation (`--skip=<category>`, income by hour 10 relative to the bot that buys everything, final tuning, 2 seeds):

| Category the bot never buys | Income by 10 h | By 14 h |
|---|---|---|
| Recruits (heroes) | -79 % | -80 % |
| Fighter capacity | -79 % | -80 % |
| Seats | -47 % | -51 % |
| Promotion Office | -15 % | -13 % |
| Recruitment Hall | -10 % | -21 % |
| Building upgrades | -8 % | -17 % |
| Restaurant | -2 % | -3 % |
| Props | -2 % | -2 % |
| Gym | +5 % | -2 % |

Before tuning, Gym (L2 150k, L3 1M) and Restaurant (L3 7M, 1.5 gold/fan) were dead weight (skipping either gave *more* income
at 10 h; concessions were 2 % of income) and Restaurant L3 alone was half of the 14.4M price list; all purchases were done
at 5.96 h.

| Key | Before | After |
|---|---|---|
| Gym L2 / L3 cost | 150,000 / 1,000,000 | 30,000 / 160,000 |
| Restaurant effect L1 / L2 / L3 (gold per fan per bout) | 0.3 / 0.8 / 1.5 | 0.5 / 2.0 / 4.0 |
| Restaurant L2 / L3 cost | 300,000 / 7,000,000 | 270,000 / 3,400,000 |
| Recruitment Hall L3 cost | 900,000 | 1,200,000 |
| Promotion Office L3 cost | 2,000,000 | 2,700,000 |
| Vera / Oswin price | 350,000 / 500,000 | 470,000 / 675,000 |
| `fame_tier_points` tier 4 | 30,000 | 20,000 |

The late prices (>= 100k) that stayed on the list were scaled by about x1.35 (Hall L3, Office L3, Vera, Oswin; Restaurant L2 by x0.9
after its effect grew 2.5x) so all purchases land at 14.3 h (target 12-18). Seats (5,500 / 600,000) and fighter capacity
(1,500 / 700,000 / 1,200,000) are untouched. Restaurant now pays 4.8 % of income (was 2 %), still a small, honest category; Gym
stays a low-priced convenience (see concerns). Tier 4 fame moved so the Coliseum arrives at 12.4 h (GDD: hours 10-18); it was
unreachable in a 14 h demo with 30,000.

## Remaining concerns and recommended code changes

1. **Excitement saturates.** From three fighters on, about two thirds of late bouts end at excitement 100 (x2.5), the rest above 60.
   Fireworks, Announcer, Showman and Brawler therefore do almost nothing after minute ~10, which is why Props are only worth ~2 %.
   Recommend: raise the top tier (a 4th tier at 90+, or scale thresholds with fighters in the lineup) or let props/traits
   add multiplier, not just excitement. `excitement_thresholds` / `excitement_multipliers` are .tres values, but they are the
   prototype's ported combat rules, so I left them.
2. **Fighters / recruits dominate** (-79 % if skipped). The jump comes from excitement (2 fighters end at 40-59 = x1.25, 3+ at 70+ = x2.5)
   on top of the per-hero income terms (`income_per_level`, `income_per_win`: a lineup of five maxed heroes is 15x the
   base income). Cheap-to-tune alternative: lower `income_per_level` / `income_per_win` and raise `base_income`; the real fix is
   smoothing the tier jump (see 1).
3. **Gym has no economic weight**: XP raises stats and the +5 income per level, which is < 3 % of a late lineup's income. Its
   price is now tiny so it does not drain the budget, but it is optional content. Recommend code: trainees also ripen stories or
   give a passive income term. (The bot buys Gym L2 before Office L2 by "cheapest first", which is why skipping Gym shows +5 %.)
4. **Series length is fight-dominated** (103 s of fights vs 20 s of hype build late). The bell threshold matters less as the game
   progresses; the Promotion Office L3 (tau x 0.55) is worth -13 % income by 14 h. If the hype decision should stay meaningful
   late, consider a series pause / afterglow that scales with tier.
5. **Bot limits.** It cashes a story the moment it ripens (multiplier ~x2.2-2.4) and never waits for x3, never rotates lineups for
   story heroes, and buys props by a simple rule; a human beats it. Bout outcomes for equal-level heroes are close to a coin
   toss per seed, so single-seed sweep argmax moves by one step (differences < 1 %).
6. **First 10 minutes are very fast**: the third fighter (Nia, 100 gold) is bought 52 s in and five buildings/heroes by 5 min. The
   GDD only asks for "a third fighter in the first ~10 minutes", so I did not slow it; if it feels too easy raise Nia / Tuck /
   Rook prices (100 / 150 / 250) and Hall L1 (200).
