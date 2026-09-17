# Farm and Fight desktop companion

Press **F5**, then **New Game** or **Resume**. Disable Godot's **Embed Game on Play** so the transparent window can dock above the taskbar. The new campaign uses its own save; the previous expedition campaign is retained on disk.

## Play the loop

1. Click **Farm** or a gold/wood spot. Assign the four starting farmers: two to gold and two to wood is a useful opening.
2. A Warrior and its barracks are ready from the start. The opening view shows their first skirmish; the clickable guide introduces farming, your first upgrade, hiring, and conquest.
3. The barracks produces a Warrior every 20 seconds, while matched enemy waves keep the opening contested. Gold can buy an immediate extra hero, with a separate 20-second cooldown per tower.
4. Open **Research**, select an icon in the connected skill tree, then use the detail card to buy an upgrade or unlock Monk, Archer, or Lancer. A newly unlocked class still needs its tower built.
5. Destroy the enemy tower to capture its land. Your towers relocate automatically, survivors retain their health, and the next frontier starts.
6. Open the new farmland and assign workers to its richer spots. Older assignments keep producing.

There is no deployment button, battle timeout, recovery phase, or loss of owned land. Enemies reaching the rear defense are removed. Farming and management remain available during combat.

## Farmers and resources

Gold and wood spots are renewable and initially hold five workers each. Assign/remove one worker using the spot panel; removing a worker returns them to the shared idle pool. Hiring costs gold. Efficiency upgrades cost gold and wood and affect every farmer.

Each captured land adds one richer gold outcrop and one richer forest grove. Workers have separate work positions around the deposits and carry materials to a nearby camp. Use the farm panel's land number, Previous/Next, or Latest farmland to manage earlier territory. Workers stay assigned until moved; collection is automatic.

Towers and spawn-rate upgrades use gold and wood. Class unlocks, power/health upgrades, and immediate reinforcements use gold. Enemy kills do not award resources.

## Heroes and research

| Class | Role |
| --- | --- |
| Warrior | Melee defender; periodically protects nearby allies |
| Monk | Heals injured allies; attacks when no healing is needed |
| Archer | Ranged damage and volleys |
| Lancer | Melee reach and attacks that pierce multiple enemies |

Warrior's root starts unlocked. All four branches can eventually be purchased; there are no exclusive choices. The graph connects its central root to four class unlocks and their repeatable power, health, and spawn-rate improvements. Select any node, including a locked node, to inspect its current/next effect, level, cost, and requirement. Green nodes have been purchased; dim nodes require their class unlock.

There is one tower per class, built at its marked slot; new games include the Warrior barracks. Passive spawning is free. Paid reinforcements cost 55/80/65/70 gold for Warrior/Monk/Archer/Lancer and require that class's tower. The button displays its cooldown after purchase. A dead hero is lost; future spawns replace losses.

Each class initially supports twelve living heroes. At capacity, its tower holds one ready spawn, and buying another hero is disabled. Spawn upgrades preserve timer progress. Hero upgrades affect existing and future heroes; health upgrades preserve current health percentage.

## Desktop controls

Mouse wheel or arrow keys scroll the landscape. **Farm** returns to the selected farmland and opens worker management; **Fight** closes the panel and jumps to the active frontier; **Research** opens the tree. Panels expand upward and do not pause progress. Close them with x or Escape.

The compact HUD shows both resources, production rates, idle farmers, and the current frontier. When already viewing the frontier, conquest follows the army forward. While inspecting farms, the camera stays in place and a conquest notice appears.

Drag, dock, fold, and close controls remain on the right. Folding shows the retained cosmetic taskbar sparring scene while the real economy and battle keep running. Click the sparring characters to restore; drag them along the taskbar to reposition.

Yellow numbers show damage to enemies, red numbers damage to allies, and green numbers healing. Projectiles and health bars reflect the active simulation.

## Saves and previews

Farm and Fight uses `user://farm_fight_v1.json`, with atomic writes and a `.bak` recovery copy. New Game keeps the previous Farm and Fight save as `.previous`. It does not convert or overwrite the old `conquest_companion_v1.json`, `conquest_v1.json`, or army-town save.

Closing pauses everything. Resume restores resources, workers, research, towers and timers, active troops, projectiles, and enemy-tower health, without offline catch-up. An unreadable primary save falls back to its backup; if neither is valid, the original files are retained and the game reports the problem.

Earlier Farm and Fight saves still load; their existing troops, buildings and tower health are preserved. Use **New Game** to experience the new starting Warrior, barracks and low-resource opening. New Game backs up the previous campaign.

Run `game/previews/companion_preview.tscn` with F6 for a fresh campaign with saving disabled. See [editor workflow](EDITOR_WORKFLOW.md) for editable scenes/resources and [checks](../tests/README.md) for verification.
