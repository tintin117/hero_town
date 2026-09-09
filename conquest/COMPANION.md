# Taskbar companion version

For the current scene-based layout, villager assignment, gathering economy, and editable balance assets, see [the designer guide](../docs/DESIGNER_GUIDE.md). The notes and measurements below describe the earlier companion version.

Press **F5** to open the main menu, then choose **Resume** to continue or **New Game** to start fresh. New Game keeps the previous companion save in a `.previous` backup. Keep Godot's Embed Game on Play disabled for native desktop behavior, and select **Game → Input**, not the 2D/3D inspection modes, to interact with buttons. The original **conquest.tscn** remains the full-window version (F6).

## Painting terrain

Open `res://conquest/terrain.tscn` to paint the Ground, Cliff, CastleTerrace, VillageTerrace, and FrontierTerrace TileMapLayer nodes. In the TileMap editor's Terrains tab, use terrain set 0: `ground` for grass and `cliff` for rock faces. Terrain Connect chooses neighboring edge tiles automatically. The `companion_terrain.tres` is based on the main menu's terrain definitions. It is independent of the restored menu, so companion terrain edits do not change the menu.

The terrain scene is instanced under the companion and moves with the settlement when panels expand. Keep terrain within the 960×220 compact view and the existing mouse outline when repainting. `scenes/main_menu.tscn` retains the visual menu from main; Resume and New Game open this companion. The menu water and foam are hidden at runtime, and its borderless window has a transparent background.

The companion is a native 1280×293 borderless transparent window, centered just above the current monitor's Windows usable-work-area boundary. It does not draw a fake taskbar or change Windows settings. It stays above other windows. On narrower work areas it scales down proportionally. Popups expand the same window upward to 1280×667, preserve the settlement's bottom edge when space permits, and clamp to the work area.

Click the castle, barracks, academy, army or red frontier tower for details. Only gold and active timers remain on the strip. `>>` means working/deployed; `II` means paused/recovering. Building indicators never include project names. Gold opens the retained offline/battle report. Notices fade after a few seconds. The frontier popup previews the reward before deployment. Battle effects and floating damage numbers show each combat step without health bars. Yellow numbers show damage to enemies, red numbers show damage to your army, and green numbers show healing.

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

Menu and companion share a preferred 1280-pixel display width. The menu renders its original layout at 1280×720, while the companion scales its 960×220 logical layout up to 1280×293. Both shrink together on smaller monitors, reserving room for expanded panels. The shared sizing policy is in scripts/presentation_scale.gd.

## Screen-wide town and scrolling

The companion now fills the current monitor's usable width while retaining the preferred sprite scale. The landscape is at least 2880 logical pixels wide, with extra open terrain for future building expansion. Roll the mouse wheel to explore left and right; arrow keys also work. There is no visible scrollbar. Gold, frontier access, and window controls remain fixed. Scrolling stops at the map edges and pauses while a management panel is open. Extra terrain does not add new building types or change saved progression.

## Minimized sparring scene

The minus control folds the town into a small transparent scene just above the taskbar. Two warriors spar while a cleric casts behind them; this is cosmetic and does not change combat outcomes, troops, or rewards. Income, training, and expeditions continue normally. Clicking the animated characters restores the screen-wide window and scroll position. The slim preview sits in the bottom-right corner of the current monitor, directly above the taskbar, with no button row beneath the characters. This uses a small visible window instead of Windows' fully hidden minimize state.

## Animated working hamlet

The first 480 logical pixels are a decorative woodcutting, gold-mining, and food-gathering hamlet. Pawns work, carry resources to nearby piles, and return with their tools on staggered loops. The castle, barracks, academy, training drill, army, and their click areas move right together. Worker loops do not generate currency or alter training and combat rules.


Restoring remembers the original monitor and positions the window inside that monitor before expanding, preventing jumps to adjacent displays. The mining source uses a large gold deposit; the smaller gold, wood, and meat sprites represent gathered supplies.

Closing the game completely pauses training, battles, recovery, and gold income. Reopening resumes the saved remaining time, without offline catch-up. Minimizing to the visible sparring scene keeps the game running and progress continues.

Drag the minimized characters left or right to reposition them along the current monitor's taskbar edge. A short click restores town; dragging does not. The position is remembered per monitor for the current game session, and movement stays inside that monitor.

Combat swings run at a fixed 10 FPS, independently of simulation-step duration. Every swing distributes a portion of the recorded battle damage into small 1–2 point popups; counters are offset slightly. Numbers fade quickly and the total damage and battle results remain unchanged.
