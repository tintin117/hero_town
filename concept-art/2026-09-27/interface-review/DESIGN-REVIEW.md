# Fight Club — visual and game design review
27 September 2026 · Concepts for review · Gameplay unchanged

**Recommendation:** use A's sunny festival world and compact bottom controls, with B's excitement board built into the rear grandstand. Treat C as a future compact viewing mode for the same game.

These are generated art-direction mockups, not executable screens or production sprite sheets. Exact hero appearances, small decorative text, and some icons are illustrative; implementation should retain the existing hero sprites and use native readable UI text. No new shops, currencies, equipment, docking, or attendance mechanics are implied by the scenery.

## What the current design gets right

The loop is understandable: book three heroes, watch them fight, receive instant tips, collect the result, and expand the venue. Mana makes the next exciting moment predictable. Participation XP prevents a loss from feeling completely wasted. Those foundations should stay.

## What needs improvement

| Current issue | Why it matters | Proposed change |
| --- | --- | --- |
| A small arena sits inside a large interface. | The player came to watch a fight, but panels command attention. | Make the world the main surface and the arena its largest, brightest shape. Move detailed management into drawers. |
| The excitement meter resembles another resource bar. | Its connection to the audience is weak. | Mount it above the grandstand and pair threshold changes with a crowd reaction. Keep HP green, mana blue, excitement amber, and money gold. |
| Base income, projected income, tips, bank, and formulas compete. | It is easy to confuse money already received with money still pending. | Bank means available coins; “At finish” means pending fight payout; “Tips paid” means money already in the bank. Put the formula behind an income-details control. |
| All five roster cards stay large during combat. | Stats useful while booking consume space when merely watching. | Show three compact active portraits and two reserves; expand Heroes only when choosing or inspecting. |
| Expansion mostly changes a number and adds tiny seats. | Spending money has a weak visible payoff. | Give seating upgrades distinct silhouettes: benches, covered stand, then a larger decorated grandstand. Keep the logical combat floor unchanged. |
| Level and victory growth can favor the same trio indefinitely. | Booking may become “always choose the strongest” instead of an interesting choice. | Before adding systems, compare actual earnings per minute and win distribution by trio. Use existing skill identities to tune meaningful tradeoffs later. |
| Time and healing can produce more excitement. | A long, safe fight could out-earn a lively fight and reward stalling. | Keep the existing time cap and test earnings per minute. If stalling wins, tune time/cast gains before adding more excitement sources. |

## A — Festival Grounds

![Festival Grounds](<D:/Optics Team/Godot/hero-town/concept-art/2026-09-27/interface-review/a-festival-grounds.png>)

**Best default direction.** A bright arena surrounded by a modest town, with compact management along the bottom. It matches the existing blue-roof, timber-and-stone sprite palette and makes expansion feel inviting.

- Strongest fit for the arena-owner fantasy: people visibly arrive, queue, and watch.
- The pale floor gives attacks and movement a quiet, readable background.
- The active trio stays easy to access without five permanent stat cards.
- Refine before production: reduce ornamental signage and fine texture, shrink the title, and lower the front wall so it never hides a fighter.

## B — Lantern Club

![Lantern Club](<D:/Optics Team/Godot/hero-town/concept-art/2026-09-27/interface-review/b-lantern-club.png>)

**Best atmosphere and excitement presentation.** The warm arena is the focus of a subdued evening town. The crowd board belongs to the venue; management sits in one side column.

- More intimate and theatrical; a skill cast can light up faces in the crowd.
- A fixed side column gives room for readable management in the expanded window.
- Refine before production: the board is oversized and the side column repeats hero health already shown on the floor. Remove that duplication.
- Tradeoff: the night palette needs careful contrast, and the side column translates less naturally into a taskbar strip. Consider this a later night-time visual variant rather than a separate game.

## C — Desktop Promenade

![Desktop Promenade](<D:/Optics Team/Godot/hero-town/concept-art/2026-09-27/interface-review/c-desktop-promenade.png>)

**Best long-term idle format.** A shallow arena strip runs below the work area. Heroes opens a temporary popover; management is otherwise tucked away.

- The arena remains most of the game strip, with smaller supporting buildings.
- Keep only bank, excitement, pending payout, and the stop control persistently visible.
- The initial oversized draft was revised to preserve substantially more desktop space.
- Tradeoff: tiny fighters cannot support the same detailed effects and labels as the expanded view. Offer an expanded arena view for deliberate watching. The popover should inherit the game's visual language rather than the generic white styling shown here.
- Docking remains a future implementation decision. This image only explores its layout.

## Recommended whole-game experience

**Watch by default.** The main view is a living venue: three fighters, a clear arena floor, nearby spectators, and a small income HUD. The player can leave it running without responding to alerts.

**Book intentionally.** Heroes opens a drawer with all five portraits, the three selected slots, level/XP, one skill description, and current HP/attack. Keep the existing stop-after-fight behavior; selection changes between fights. A hero's level and skill should be easy to compare before extra stats are introduced.

**Improve the venue.** Arena opens a drawer showing current seats, the next upgrade's cost, its income effect, and a visual preview of the next stand. At first the tavern, armorer, and ticket booth are scenery. They should not look like clickable shops until they have a real function.

**Celebrate without interrupting.** A win produces a compact result ribbon: winner, fight payout, already-paid tips, combined earnings, and XP/level-ups. It leaves the arena visible during the existing three-second break and never requires a confirmation to repeat.

**Grow something visible.** Keep the short loop of fights and levels inside the longer loop of venue expansion. Each purchase should change the place the player watches. Saving and desktop docking are future work; neither is needed to approve this visual direction.

## Arena and excitement details

- Use the current circular simulation and oval projection. Surround it with rear and side stands, a low front boundary, two entrances, banners, and a ticket path.
- Maintain a clear center and readable fighter silhouettes. Do not place visitors, props, trees, or opaque effects on the combat floor.
- Preserve the true Sweep radius; use a thin ground outline and a quick impact flash. Other skills keep their existing spatial behavior.
- Put the excitement gauge above the back stand: **EXCITED · 58/100 · x1.25**, with visible 40/80 markers and **Wild at 80** as the next goal. The icon and text must communicate the tier without depending on color.
- Normal: light audience movement. Excited: a short cheering wave and raised flags. Wild: a stronger one-shot cheer and a few streamers, then settle back to calm ambient motion.
- Skill cast: the existing immediate **+10** coin burst, plus a smaller excitement cue. Keep popups apart and avoid repeating the same information in several large overlays.
- Keep the current scoring and payouts for the visual pass. Random bonuses and rarity should be separate design decisions, not hidden inside a UI redesign.
- Make animation and sound restrained by default, with mute and reduced-effects options in a later presentation pass.

## Placeholder background for the first implementation

Use existing trees, grass, blue-roof buildings, and paths around the arena. Start with a tavern silhouette on one side, a barracks/armorer on the other, and a few spectator/visitor sprites. Add a chimney puff, occasional walking visitors, gently moving banners, and crowd reactions. Background movement should be slower and lower contrast than combat.

Keep buildings modular and the scenery decorative. Reserve expansion room near the stands, but do not add empty shop grids or new management systems simply to fill the screen.

## Review choice

Choose **A for the main layout**, **B for mood or the crowd-board treatment**, or **C to prioritize the compact desktop experience**. My preferred combination is **A + B's crowd board now; C later as a second viewing mode**.

Images were generated with the built-in Imagegen tool. The exact prompt set is saved in [PROMPTS.md](<D:/Optics Team/Godot/hero-town/concept-art/2026-09-27/interface-review/PROMPTS.md>). The current prototype screenshot is preserved as [current-prototype.png](<D:/Optics Team/Godot/hero-town/concept-art/2026-09-27/interface-review/current-prototype.png>).
