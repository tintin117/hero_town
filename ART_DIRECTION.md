# Art Direction Change — Cardboard Diorama (HD-2D style)

Status: **Proposed, not yet implemented.** Decided in conversation on 2026-06-29, carried over to continue work on another machine.

## The Idea

Change the visual style so every asset (heroes, enemies, buildings, terrain) looks like
hand-drawn cardboard cutouts, arranged like a physical diorama — a long cardboard strip
with **3 rails** where heroes/buildings get placed at different depths.

## Why 3D (not just 2D z-index tricks)

Initially considered faking depth in 2D with `z_index` layering — cheaper, no rewrite.
But the 3 rails are an actual **gameplay axis** (placement depth for heroes/buildings),
not just a visual layering trick. That makes 3D the right call architecturally, not just
for art's sake.

Camera will be **locked** — no player rotation, fixed orthographic-style angle, like a diorama.

## Technique: "HD-2D" (Octopath Traveler style)

Keep sprites flat 2D pixel art, but place them inside a real 3D scene:

1. **Sprites stay 2D, world becomes 3D.** Characters/enemies remain flat pixel-art sprites,
   but live on `Sprite3D` planes inside a `Node3D` scene. Environment (ground, rails,
   buildings) is built from real 3D meshes ("cardboard" cutout planes/props).
2. **Billboarding** — `Sprite3D` set to always face the camera, so sprites never look
   rotated/distorted even though they exist in 3D space.
3. **Camera locked, orthographic (or near-orthographic).** Never rotates/orbits — keeps the
   flatness of sprites hidden, gives the fixed painterly diorama angle.
4. **3D unlocks what 2D can't fake well:**
   - Real depth-sorting between rails (near rail occludes/is occluded by far rail correctly)
   - Real-time lighting/shadows cast by flat sprites onto 3D ground/props (the signature
     HD-2D look)
   - Depth-of-field blur on background layers
5. **Preserve pixel crispness deliberately** — nearest-neighbor texture filtering, pixel-snap
   sprite positions, so characters stay crisp pixel art instead of blurring like 3D textures.

## Downsides / Costs of Going 3D (accepted trade-offs)

- Physics/collision moves from 2D (`CharacterBody2D`, `Area2D`) to 3D (`CharacterBody3D`,
  `Area3D`) — more complexity even though gameplay is still mostly along rails.
- Lose 2D's automatic pixel-snapping; must be set up manually (Nearest filter + orthographic
  camera + pixel-snap).
- Lighting is real-time by default in 3D; flat cardboard look needs deliberate light/shadow
  setup rather than Godot's 2D unlit-by-default canvas.
- UI/HUD (health bars, hero cards, building panels) stays 2D (`Control`) regardless — so the
  project becomes a 3D world + 2D UI hybrid, more moving parts than pure 2D.

## Scope Impact

This is a **structural rewrite**, not a quick patch. Affects:
- Scene roots: `Node2D` → `Node3D` (`main.tscn`, `hero.tscn`, `enemy.tscn`)
- `hero.gd`, `enemy.gd`: `CharacterBody2D` → `CharacterBody3D`
- `main.gd`: `GROUND_Y` constant → a rail/Z-depth system (3 fixed rail positions)
- Sprites: `Sprite2D` → `Sprite3D` (billboard mode), nearest-neighbor filtering
- Camera: new locked `Camera3D` (orthographic projection, fixed angle, no rotation input)

Treat as a dedicated mini-project. Per [CLAUDE.md](CLAUDE.md) mentor-mode rules, this should
be planned/taught step by step rather than auto-implemented — the user (Long) wants to do the
actual node wiring themselves.

## Status / Next Steps

- [ ] Decide when to start: after Build 1 acceptance, or fold into Build 2 art pass?
- [ ] Prototype: single rail + 1 cardboard cutout hero as `Sprite3D` with locked orthographic
      camera, verify pixel crispness and lighting/shadow look before committing further.
- [ ] If prototype looks right: plan full conversion of `main.tscn`, `hero.tscn`, `enemy.tscn`.
- [ ] Update `CLAUDE.md` tech stack section once 3D conversion actually begins (currently says
      2D-only / `CharacterBody2D`).
