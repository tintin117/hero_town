# Fight club — Game Design Document

Version 0.1 · 2026-09-29 · Status: **design proposal, not implemented.** [README.md](../README.md) describes the current prototype; this document describes where the design is going.

All numbers below are **tuning placeholders** unless marked as reused from the prototype. Validate them with economy simulations (see [Validation](#17-validation)) before treating them as fixed.

---

## 1. Vision

You are the promoter of a small, run-down fight club. Fighters brawl on their own; **you build the business around the show**: the hype, the crowd, the stories, the money.

**One-line pitch:** an idle desktop-strip game where every fight night is a crop, hype is how long it takes to grow, and the stories your fighters create are what you harvest.

### Design pillars

1. **The show is the product.** Money comes from crowd × excitement. Everything the player buys makes the show bigger, better or more automatic.
2. **Waiting is the game.** Progress is gated by hype building up, not by chores. The player decides *when to harvest*, not how to keep fighters alive.
3. **Stories ripen.** Fighters generate rivalries, streaks and comebacks on their own. Every check-in answers "what's ripe?".
4. **Glanceable and low-maintenance.** The whole state reads in two seconds on a 1280×420 strip. Nothing punishes the player for looking away.
5. **A legacy, not a reset.** Long-term progress is enshrining champions in the Hall of Fame.

### Non-goals

- No per-fight fatigue, injury or feeding chores in normal play.
- No stat-heavy equipment system.
- No real-time player control of fights.

---

## 2. Narrative frame

You start with two fighters (Bram and Ivo) and a small arena. The pitch to yourself: *"I want to start a business here."* Fights make money, money buys the next thing, and the club grows through four **Fame tiers**:

| Tier | Name | Feel |
| --- | --- | --- |
| 1 | Basement Club | Two fighters, a hundred folding chairs |
| 2 | Local Arena | Real stands, first sponsors |
| 3 | City Stadium | Broadcast rights, big rivalries |
| 4 | Grand Coliseum | Legends fight here |

---

## 3. Platform and session model

- **Desktop strip window**, 1280×420 default, 960×420 minimum (reuse the Sunnyside town from the prototype).
- **Idle by default.** Fights run automatically. The player checks in every few minutes for decisions and can leave for hours.
- **Session shape:** minutes of waiting, a handful of decisions, then leave. A check-in should take 10–60 seconds.
- **Offline progress:** capped, reduced and abstract (see [§10](#10-offline-progress)).

---

## 4. Core loop

Three timescales:

| Scale | Loop | Player role |
| --- | --- | --- |
| Seconds–minutes | **Promote → Fight → Aftermath** | Mostly watching. Optionally pick the matchup and a prop. |
| Minutes–hour | **Cash in stories, buy upgrades** | Spend gold, choose what is ripe. |
| Hours–days | **Rise through Fame tiers, enshrine champions** | Long-term goals and prestige. |

### One fight night

1. **Promote (passive).** Hype builds toward 100 on its own curve (§5).
2. **Book.** The player, or the manager once hired, starts the bout. Matchup, prop and Main Event are chosen here.
3. **Bell.** The crowd size is set from the hype at that moment. The fight plays out automatically.
4. **Payout.** Gold from tickets × excitement, tips per skill, concessions.
5. **Aftermath.** Hype resets to a small afterglow. XP, stories and Fame are awarded. Repeat.

---

## 5. Hype: the growth timer

Hype is a 0–100 meter for how eager the crowd is right now.

- **Growth:** `dHype/dt = (100 − hype) / τ`, with `τ = 50 s` at the start. It rises fast at first and slows near the top, like a plant reaching full growth.
- **At the bell:** `attendance = seats × (0.10 + 0.90 × hype / 100)`.
- **After the bell:** hype drops to `afterglow = 0.30 × final excitement` (0–30). A great fight leaves the crowd already warm.
- Hype does not grow during a fight.

### The central decision: when to harvest

Because growth slows near the top, waiting always costs more time than it gains. Illustrative income rate for a 60-second fight, starting from 15 hype (verify by simulation):

| Book at hype | Time to build | Relative income rate |
| --- | --- | --- |
| 50 | 27 s | 0.58 |
| 70 | 52 s | **0.62** |
| 85 | 87 s | 0.58 |
| 95 | 142 s | 0.47 |

The best default is about 65–70. A manual player who reads the situation can beat that (for example, holding out for a ripe Main Event), and an idle player loses very little by using the manager's default. Upgrades shift the curve (§9).

**Manager setting:** *Book at hype ≥ X.* Default 70, adjustable by the player.

---

## 6. Fight, excitement and payout

Reuse the prototype's combat simulation, skills and excitement rules.

- **Reused from the prototype:** excitement builds from fight time (max 20) plus 8 per executed skill; caps at 100. Multiplier: below 25 = ×1, 25–59 = ×1.25, 60+ = ×2.5. Each executed skill tips 10 gold immediately.
- **Ticket income:** `ticket price × attendance × excitement multiplier`. Start ticket price at 1 gold per seat and treat price as a tuning lever (the prototype's base is 100 gold at 100 seats).
- **Concessions:** paid per attendee (§9), unaffected by the excitement multiplier.
- **No stamina and no injury** in normal fights. Fighters simply fight again.

---

## 7. Fighters

Roster of named heroes, recruited once each (reuse the prototype's eight, templates and prices as a starting point).

- **Progression:** 10 XP per fight, +10 for winning; level cap 10; +5% HP and attack per level (prototype rules).
- **Traits:** each fighter has one or two traits that change how they contribute to the *show*, not the raw stats.

| Trait | Effect |
| --- | --- |
| Showman | Skills add +50% excitement |
| Brawler | Fights end faster; more damage |
| Crowd Pleaser | Afterglow ×1.5 |
| Grudge Holder | Rivalries with this fighter ripen faster |
| Underdog | Bonus excitement when facing a stronger opponent |

- **Retirement:** a fighter at the level cap with enough wins can retire into the Hall of Fame (§11).

---

## 8. Matchmaking, preview and props

### Matchmaking

Before each bout, the player picks the fighters (or leaves it to the manager's preference list).

### Excitement preview

The booking screen shows a **1–5 star excitement estimate** for the chosen matchup, computed from traits, skills, level gap and any ripe story.

- It is an **estimate**, shown as a range. Higher Promotion Office levels narrow it.
- Mismatched fights are cheap and dull. Well-matched, trait-synergistic fights are exciting.
- Exciting matchups should cost something: a valuable fighter, an expensive prop, or a story that will be spent.

### Stage props

One consumable prop per fight, bought from the shop after the fight:

| Prop | Effect |
| --- | --- |
| Fireworks | Start the fight with excitement 15 |
| Announcer | Skills add +50% excitement |
| Spotlights | Afterglow ×1.5 |
| Ringside Bar | Concessions ×2 this fight |
| Underdog Poster | Betting pool ×2 (once Betting is unlocked) |

Props are a gold sink and a decision, with no new stat system. Prices scale with seats.

---

## 9. Stories and buildings

### Stories (the "crops")

Fights create stories automatically. Each story has a **ripeness** from 0 to 100.

| Story | Created when | Ripens by |
| --- | --- | --- |
| Win Streak | A fighter wins 3 in a row | Each further win |
| Rivalry | Two fighters have met twice with a split result | Each meeting |
| Grudge | A fighter loses to a rival | Time and rematches |
| Comeback | A fighter wins after 3 losses | Time |
| Legend | A high-level veteran keeps winning | Wins and time |

- **Cash in** by booking the story's matchup as a **Main Event**: payout ×`(1 + 2 × ripeness / 100)`, up to ×3, and Fame `+ ripeness / 10`.
- **Overripe:** a story that stays at 100 for 10 fights goes cold and loses ripeness gradually. This makes check-ins matter without punishing absence heavily.
- **Badge:** a "story is ripe" mark on the strip tells the player something is worth doing.

### Buildings (revenue and upgrades)

Buildings are unique, placed on the estate, and have three levels (reuse the placement system).

| Building | Role | Unlock |
| --- | --- | --- |
| Arena | Seats: 100 → 150 → 200 and beyond by tier | Start |
| Recruitment Hall | Roster capacity | Start |
| Promotion Office | Hype growth (`τ` down), preview accuracy, story slots | Tier 1 |
| Gym | Trains benched fighters (lower XP than fighting), clickable to speed up | Tier 1 |
| Restaurant / Concessions | Gold per attendee; food props | Tier 1 |
| Manager's Office | Auto-booking, threshold setting, offline progress | Tier 2 |
| Merch and Sponsors | Passive hourly income scaled by Fame | Tier 2 |
| Betting Booth | Audience bets on fights; random upsets pay off | Tier 3 |
| Broadcast Tower | Multiplier on every fight | Tier 3–4 |
| Hall of Fame | Prestige (§11) | Tier 2 |
| Hospital | Only needed for Bloodsport mode (§12) | Optional |

Each level upgrade should visibly change the scene, not just a number.

---

## 10. Automation and offline progress

### Manager

Hiring a manager automates booking. It is the "tractor" upgrade: early on the player books each fight by hand, later the club runs itself. The manager uses the preferred fighter list and the *book at hype ≥ X* threshold.

### Offline progress

Requires the Manager's Office.

- Cap of **8 hours**, at **50%** of the online income rate.
- Simulated abstractly: expected income per cycle at the manager's threshold, not full combat.
- Fighters gain XP; **stories may ripen but are never cashed in** while away.
- On return: a short summary ("the club ran a quiet night"). Nothing is lost.

---

## 11. Prestige: the Hall of Fame

Retire a champion to enshrine them.

- **Requirements:** level cap, plus thresholds on wins and losses and on gold earned. Titles can require a *loss* count (for example, "Punching Bag" for a fighter the crowd loves to see lose).
- **Reward:** each enshrined fighter gives a permanent club perk (for example, crowd draw, training speed, faster hype growth) and a title with a small mechanical effect.
- **No wipe.** The club keeps its buildings and gold. A new prospect can start with an inherited bonus.
- **Later option (out of scope for now):** *Franchise* — open a club in a new city for a larger reset.

---

## 12. Optional: Bloodsport mode

A late, optional booking type. It exists because a business should be able to take risks.

- Higher payout multiplier and higher excitement floor.
- Defeats build an **injury meter**; a third defeat injures a fighter, who needs the Hospital.
- The Hospital, injury recovery and any food buffs live here, so they only matter when the player chooses risk.
- Reuse the prototype's fatigue and injury code for this mode.

---

## 13. Progression map (target: 12–18 running hours)

| Phase | Goal | Unlocks |
| --- | --- | --- |
| First 10 minutes | Fight, watch hype fill, buy a third fighter | Recruitment, first props |
| First hour | Fame tier 1 → 2 | Promotion Office, Gym, Restaurant, first stories cashed |
| Hours 1–4 | Automation | Manager, Merch, Hall of Fame |
| Hours 4–10 | Tier 3 | Betting, Broadcast, big rivalries |
| Hours 10–18 | Tier 4, legacy | Coliseum, enshrine several champions |

---

## 14. User interface (1280×420)

- **Top bar:** Gold, Fame tier and progress, and a **Hype gauge**.
- **Scene:** the arena with crowd, fighters and buildings; the crowd grows visibly as hype rises.
- **Badges:** "story ripe", "shop open", "upgrade affordable".
- **Panels:** Booking (matchup, star preview, prop, Main Event), Roster, Build, Hall of Fame. Opening a panel never pauses the simulation.
- **Menu** pauses and saves (prototype behaviour).

---

## 15. Relationship to the current prototype

| Keep | Change | Drop or defer |
| --- | --- | --- |
| Combat simulation, skills and templates | The fixed **ten-fight event** becomes continuous fights gated by hype | Per-fight stamina and injury in normal play (move to Bloodsport) |
| Excitement rules and tips | Seats become **attendance** driven by hype | The manual "booking" step becomes optional once a manager is hired |
| Building placement, levels and save system | Gym, Hospital and Restaurant are repositioned as in §9 | |
| Sunnyside art and layout | Recruitment: the prototype's fixed named roster stays | |

---

## 16. Build order

1. **Hype slice:** hype growth, attendance-based payout, manager-style *book at hype ≥ X*.
2. **Stories and preview:** traits, ripeness, Main Events, star preview, one prop.
3. **Passive income and automation:** Restaurant, Merch, Manager, capped offline progress.
4. **Hall of Fame prestige.**
5. **Bloodsport, Betting, Hospital.**

Ship and playtest after each step. If step 1 does not feel good, the rest will not fix it.

---

## 17. Validation

Extend the existing checks under `game/check_*.gd`; keep logs and captures under the ignored `.godot/`.

- Sweep the hype curve and check that the income-rate peak sits near the intended booking threshold.
- Simulate full progression at seeded runs for pacing against the 12–18 hour target.
- Check that offline income stays at or below online income.
- Check that cashing in a story is always better than skipping it, and never worse than the base fight.

---

## 18. Open questions

1. Is the starting ticket price a fixed number, or a player setting?
2. Should stories be limited to a small number of slots to keep the strip readable?
3. How visible should the excitement preview's uncertainty be?
4. Does the Hall of Fame perk pool need to be random, or fully chosen by the player?
5. How long is a typical fight night in real time? Long fights slow hype timing, so this affects `τ` tuning.
