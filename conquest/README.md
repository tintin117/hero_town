# The Growing Banner

Open `res://conquest/conquest.tscn` and press **F6** (Run Current Scene).
The original main scene is unchanged. All prototype code and assets references are in this folder; the existing Tiny Swords package supplies the art.

Click the home, barracks or academy artwork/buttons to prepare. Launch an expedition on the right. Projects cost gold once, finish automatically and pause during battle. Gold continues online and offline. Each result starts a tunable 120-second recovery, during which preparation continues. Skip only shortens the presentation; the result was already calculated and saved.

Opening route: conquer the meadow with your three warriors; build the academy (60 gold), train two warriors (20 gold / 30 seconds) and a mage (30 gold / 60 seconds) in parallel during recovery. Five warriors and Fireball clear the quarry. Invest in income or more troops and Healing. Seven warriors with Fireball lose at River Watch; seven with Healing win, and nine with Fireball also win. The battle simulation uses frontline health, living warriors' damage, surviving enemy attacks and spell effects; outcomes are not stage-scripted.

Home development costs 60 gold and adds 5 gold/min without a plot. Additional warriors cost 40 gold / 180 seconds. Healing costs 60 gold / 300 seconds; equip it or Fireball instantly at the academy. Only one mage is included. Free plots remain available after the academy; later construction types are outside this opening prototype.

Persistence uses `user://conquest_v1.json`, independent of the existing game's save. Writes use a temporary file and rename. The battle timeline, committed ownership reward and remaining presentation are saved together. Offline time resolves the remaining battle pause, then recovery and projects, without repeating completed projects. Wall-clock rollback grants no extra elapsed time.

Run logic checks with Godot:

```
godot --headless --path . --log-file <absolute-path-to-log> --script conquest/checks.gd
```

Validated in Godot 4.6.3: first victory; parallel completion; no duplicate projects; pause/resume; continued battle income; save/load mid-battle; offline completion and no repeats; affordability; defeat preservation; spell switching; deterministic outcomes. The live editor run and popup/battle captures had no new editor or game errors. Sandboxed CLI runs emitted pre-existing autoload/user-directory permission warnings; normal editor execution saved successfully.

Art/layout intentionally uses a fixed 1280×720 canvas matching this project. Up to forty warriors are drawn; every trained warrior participates in the simulation. This is an opening-loop prototype, not an endless campaign.
