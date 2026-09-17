# Running checks

Run commands from the project root with Godot 4.6.3. Set `$godot` to your console executable. Always pass `-- --test` to checks: the town autoload then skips the player's save. Companion checks use separate test save paths.

For complete isolation, put Godot's user-data directory inside the ignored project cache for this shell session:

```powershell
$godot = '<absolute path to Godot console executable>'
$env:APPDATA = Join-Path $PWD '.godot/test_userdata'
$env:LOCALAPPDATA = $env:APPDATA
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
& $godot --headless --editor --import --path . --quit -- --test
```

## Farm and Fight

```powershell
& $godot --headless --path . res://tests/companion/farm_fight_checks.tscn -- --test
& $godot --headless --path . res://tests/companion/farm_fight_ui.tscn -- --test
& $godot --headless --path . res://tests/companion/farm_fight_balance.tscn -- --test
& $godot --headless --path . res://tests/companion/farm_fight_endurance.tscn -- --test --duration=1800
```

Rules checks cover transactions, recruitment cooldowns, assignments, class roles, continuous combat, conquest, caps, exact progress to JSON precision, earlier saves, and corrupt-save recovery. UI checks use real mouse clicks on skill nodes and the detail card, verify non-overlapping graph controls, pack theme states, worker delivery routes, the opening guide, and bounded land loading. The balance check verifies that the unattended first three minutes stay contested, limits 1,200 rapid recruit clicks to three purchases in a minute, and follows a two-gold/two-wood opening through a Warrior upgrade, hiring, and further upgrades; first conquest must take 180–360 seconds. Endurance simulates thirty minutes across multiple conquests and checks bounded combat storage.

The native companion check below routes into the same UI suite, adding real Windows window checks. Tests do not write player saves.

## Legacy prototype, army-town, and editor checks

```powershell
& $godot --headless --path . --script res://tests/companion/rules_checks.gd -- --test
& $godot --headless --path . --script res://tests/companion/return_checks.gd -- --test
& $godot --headless --path . res://tests/town/rules_checks.tscn -- --test
& $godot --headless --path . res://tests/town/ui_checks.tscn -- --test
& $godot --headless --path . res://tests/town/progression_checks.tscn -- --test
& $godot --headless --path . res://tests/editor/editor_workflow_checks.tscn -- --test
```

The legacy companion rules/return scripts above exercise the retained expedition prototype. The editor workflow checks modify temporary copies of authored scenes/resources, reload them, and verify that their edits survive startup. `fixtures/return_departure.json` is input data; generated JSON and captures go under `.godot/`.

## Native windows

These require a Windows desktop; headless runs cannot validate window size, transparency, or taskbar placement.

```powershell
& $godot --path . --script res://tests/companion/companion_checks.gd -- --test
& $godot --path . --script res://tests/menu/main_menu_checks.gd -- --test
& $godot --path . res://tests/town/desktop_checks.tscn -- --test
```

## Balance and endurance

```powershell
& $godot --headless --path . res://tests/town/balance_checks.tscn -- --test
& $godot --headless --path . res://tests/town/endurance_smoke.tscn -- --test --duration=10
```

Endurance defaults to 1,800 seconds if no duration is supplied. Balance checks simulate purchasing policies; they do not replace human playtesting. Inspect both the check summary and engine errors, since a script error can occur even when the process exits with code zero.

The scenes in `game/previews/` are manual F6 previews, not automated checks. They disable persistence without requiring `--test`.
