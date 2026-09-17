# Class research UI

> **Historical preview documentation.** The active remaster uses `game/town/town_hud.gd` and the resource nodes in `data/town/research/`. Purchases now execute authoritative transactions for individual building IDs. See [REMASTER.md](../TOWN.md). The standalone preview scenes described below are retained only as prototype references.

This implementation is a visual prototype. The player can inspect nodes, switch tabs/classes, preview training, and choose among three sample hero cards. Those actions do **not** spend currency, upgrade a real building, alter stats, recruit heroes, roll randomness, or save progression.

## Try it

Run the project, choose Play, then click a class building or use the four class buttons at the bottom right. The Warrior Barracks, Cleric Sanctuary, Mage Tower and Rogue Lodge are preplaced. Town Hall and Portal keep their existing panels.

Research is an in-game Control overlay, nominally 460 × 640 pixels, centered over the town. Drag its title to move it; X, Escape, or a click outside closes it. In Compact mode, the same game window temporarily expands upward while research is open, then returns to its previous size and position. No separate window is created. Hero contains the scrollable tree. Manage contains the upgrade preview, existing move-building action, and preview reset.

Select the gold next-building milestone, then **Preview upgrade** to see three sample candidates. Choosing a card advances only the displayed preview tier. Class switching or reopening resets this temporary preview. The three portraits intentionally reuse the current class sprite; names and specialties are mock data, not newly authored heroes.

## Edit the visuals in Godot

- `scenes/class_research_panel.tscn`: editable Control/container hierarchy, tabs, detail pane and candidate overlay.
- `resources/research_theme.tres`: font, frame, button and scrollbar styles.
- `scripts/research_tree.gd`: five rarity bands; each has a building milestone and four two-rank stat branches (45 clickable nodes). HP, defense and attack are shared; the fourth branch is skill power, agility or healing according to class. Layout spacing lives in `BAND_HEIGHT`, `ICON_SIZE`, and `_build_tier()`.
- `scripts/research_node.gd`: small white pixel glyphs drawn as rectangles. No generated concept image is used as a runtime asset.
- `scripts/class_research_panel.gd`: presentation state, selections, tabs and sample candidate cards.
- `scripts/research_overlay.gd`: in-game backdrop, dragging, responsive sizing, and temporary Compact-mode expansion.
- `scenes/canvas_layer.gd`: building-click routing and class shortcuts.

## Connect gameplay later

The panel exposes `training_previewed(building_id, node_data)`, `upgrade_previewed(building_id, rarity)` and `hero_choice_previewed(building_id, rarity, candidate_index)`. They currently have no gameplay listeners. Treat them as future integration seams, not authoritative transactions. Replace preview state and mock candidates with validated game state before connecting currency or combat.

Rarity indices are zero-based. Each node dictionary identifies `kind`, `tier`, `key`, and (for stat nodes) `stat` and `rank`. Building levels displayed in the UI are one-based. All stat values and upgrade costs still need design and gameplay implementation; no new combat formulas, defense behavior, rarity bonuses, selection probabilities, or persistence have been added.

The intended future flow is building upgrade → unlock next rarity → roll three heroes from that rarity → choose one. Each rarity's stat branches apply to heroes of that rarity. The former separate shard recruitment draft was removed when the scope changed to UI only.

## Verification

Godot runtime checks exercised all four classes, 45 nodes per class, both tabs, scrolling, all four upgrade previews, three-card selection and the maximum-tier state. Assertions confirmed currency, actual building levels and hero count were unchanged by all preview actions.
