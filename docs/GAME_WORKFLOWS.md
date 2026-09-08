# Hero Town workflows

The game is an idle town builder: heroes fight automatically while the player manages buildings and progression. The diagrams below separate working gameplay from the proposed research system. **The class research interface currently previews progression; it does not execute it.**

## 1. Idle combat and rewards — implemented

```mermaid
flowchart TD
    P["Player opens Portal"] --> A["Summon an enemy or enable Auto"]
    A --> S["Portal spawns enemies; Auto respects its slot limit"]
    S --> F["Heroes seek enemies and fight automatically"]
    F --> E{"Who is defeated?"}
    E -->|Enemy| R["Earn gold and shards"]
    R --> N["A Portal slot becomes available"]
    N -->|Auto enabled: next timer tick| S
    R --> U["Spend gold on Portal upgrades"]
    U --> T["Unlock stronger enemy tiers and improve spawning"]
    T --> S
    E -->|Hero| D["Hero rests for 5 seconds"]
    D --> V["Revive at full HP"]
    V --> F
```

Currently the existing Barracks spawns the warrior squad. The other three class buildings are present for UI review; their recruitment and squad mechanics are not connected. Enemy drops use their authored gold/shard ranges. Portal summoning and Auto controls remain in the existing Portal panel.

## 2. Building upgrades and hero choice — planned gameplay

```mermaid
flowchart TD
    W["Warrior Barracks"] --> B["Choose a class building"]
    C["Cleric Sanctuary"] --> B
    M["Mage Tower"] --> B
    R["Rogue Lodge"] --> B
    B --> U["Upgrade that building"]
    U --> T["Unlock its next hero rarity"]
    T --> G["Roll 3 candidates from that class and rarity"]
    G --> P["Player chooses 1 hero"]
    P --> S["Recruit / deploy the selected hero"]
    S --> F["Fight and earn resources"]
    F --> U
```

Gacha belongs to the building-upgrade reward, with no separate recruitment purchase in this design. Costs, candidate pools, probabilities, deployment rules, and persistence still need gameplay implementation. The current preview shows fixed sample cards instead of random draws.

## 3. Rarity-specific research — planned effects, current visual tree

```mermaid
flowchart TD
    L1["Lv 1: Common"] --> L2["Lv 2: Uncommon"]
    L2 --> L3["Lv 3: Rare"]
    L3 --> L4["Lv 4: Epic"]
    L4 --> L5["Lv 5: Legendary"]
    L3 --> H1["Rare HP I"] --> H2["Rare HP II"]
    L3 --> D1["Rare Defense I"] --> D2["Rare Defense II"]
    L3 --> A1["Rare Attack I"] --> A2["Rare Attack II"]
    L3 --> X1["Rare class specialty I"] --> X2["Rare class specialty II"]
    H2 --> B["Bonuses apply to matching-class Rare heroes"]
    D2 --> B
    A2 --> B
    X2 --> B
```

Rare is shown as one example; each rarity has its own branches. The UI has five building milestones and forty stat nodes per class. The fourth branch shows skill power for Warrior/Mage, agility for Rogue, and healing for Cleric. These are presentation labels, not implemented combat effects. Rank prerequisites, values, and research prices remain to be designed and connected.

## 4. Research UI navigation — implemented preview

```mermaid
flowchart TD
    O["Click a class building or class shortcut"] --> P["Research panel opens inside the game"]
    P --> H["Hero tab: scroll the rarity tree"]
    P --> M["Manage tab: building details and controls"]
    H --> N["Select a node to inspect details"]
    N --> S["Preview stat training"]
    N --> U["Preview next building upgrade"]
    M --> U
    U --> C["See 3 sample hero cards"]
    C --> K["Choose a card: advance displayed tier only"]
    K --> H
    M --> V["Move building using existing placement controls"]
    P --> X["Close with X, Escape, or outside click"]
    X --> G["Return to the town"]
```

Training and hero-choice previews never change currencies, actual building levels, or hero stats/counts. Reopening or switching class resets preview state. In Compact mode the same game area temporarily expands for research, then returns to its prior size on close. No separate research window is created.

See [Class research UI](CLASS_RESEARCH_UI.md) for the editable scenes and future gameplay integration points.
