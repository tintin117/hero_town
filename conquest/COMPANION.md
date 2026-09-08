# Taskbar companion version

Run **res://conquest/companion.tscn** with F6. Keep Godot's Embed Game on Play disabled for native desktop behavior. The original **conquest.tscn** remains the full-window version.

The companion is a native 960×220 borderless transparent window, centered just above the current monitor's Windows usable-work-area boundary. It does not draw a fake taskbar or change Windows settings. It stays above other windows. On narrower work areas it scales down proportionally. Popups expand the same window upward to 960×500, preserve the settlement's bottom edge when space permits, and clamp to the work area.

Click the castle, barracks, academy, army or red frontier tower for details. Only gold and active timers remain on the strip. `>>` means working/deployed; `II` means paused/recovering. Building indicators never include project names. Gold opens the retained offline/battle report. Notices fade after a few seconds. The frontier popup previews the reward before deployment. Battle effects and two health bars fit in the strip.

Small controls, left to right at the lower right: `>` frontier; `::` drag; `v` dock; `-` minimize; `x` save and close. Restore a minimized companion from its Windows taskbar entry. Close popups with their x or Escape. Empty desktop above the settlement is outside the native mouse interaction outline. The outline is conservative around sprites; this is not per-pixel click-through between every branch or soldier.

## Save behavior

On its first launch only, the companion copies the full-window prototype's current progress into **user://conquest_companion_v1.json**. Thereafter the two versions progress independently. No original save is reset or overwritten. Do not expect subsequent progress to synchronize between versions. All rules, costs, spells, income, recovery and offline calculation reuse `conquest_state.gd` unchanged. The full-window return-summary fix remains intact; the companion additionally retains the summary behind the gold button after its short welcome notice fades.

## Validation

- Godot 4.6.3, live editor session hero-town@b809; same editor stayed open.
- Measured native window: 960×220 at (2400,812) on work area (1920,0,1920,1032); bottom exactly1032, above the taskbar.
- Actual Windows computer-use capture confirmed composited desktop visible behind sprites.
- Actual mouse inputs verified building popup, training choice, frontier preview/deployment, Escape, drag from (2400,812) to (2321,784), dock back to (2400,812), minimize mode1, restore mode0, and close (window disappeared while editor remained).
- QA gameplay used a separate save. A chosen warrior project paused during battle, gold increased, saved battle resolved after restart, training resumed during recovery, and the project later completed automatically. Original/companion review saves were not advanced by QA actions.
- `companion_checks.gd`: **34 checks, zero failures**. Native dimensions, transparency, alpha-zero corner, excluded empty input area, included controls, taskbar placement, all six popup boundaries/text/action separation, close restoration, project pause/resume, gold, JSON roundtrip, battle timeline and completion.
- Final live game logs contained no gameplay errors. Sandboxed standalone tests emitted the existing certificate/cache/legacy-autoload user-directory permission messages; assertions passed.
- An early native drag implementation failed the fast mouse-drag test and was replaced with event-position-based dragging. A strict floating-point save comparison was corrected to approximate comparison; the model was unchanged.

Run the focused check with `godot --path . --rendering-method gl_compatibility --log-file <absolute-log-path> --script conquest/companion_checks.gd`.

## Evidence and limitations

`companion-compact.png`, `companion-training.png`, `companion-frontier.png`, `companion-battle.png` are native-sized framebuffer captures (transparent surroundings). `companion-native.jpg` is the bounded Windows composite capture showing the desktop behind the strip. The taskbar itself is outside that capture; placement is verified by native work-area coordinates. Delivery of an outside click to a separate application was not independently tested; the native polygon and visible transparency were checked. Layout is tested on this host, not every Windows DPI/driver combination. Up to30 troops are drawn; all trained troops participate in battle math. No enjoyment or retention claim is made.


Screenshots referenced here are local review artifacts and are not part of the source commit.
