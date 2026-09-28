# Project-style arena concept

Created with the built-in image_gen tool on 2026-09-27. These are generated visual concepts, not production sprite sheets or an implemented Godot scene.

## Asset review

The active prototype loads `resources/art/unit_library.tres` from `game/main.gd`. That library contains the Tiny Swords warrior, lancer, archer and monk SpriteFrames in blue and red variants. The existing UI theme also references Tiny Swords buttons. This makes Tiny Swords the grounded default for the requested project art style.

Visually inspected: Tiny Swords House1, Barracks, Warrior_Idle, Tilemap_color1 and Tree1; the older `asset/hero_town/main_house.png`; and `asset/hand_draw/level/castle_1_townhall.png` plus `asset/hand_draw/chracter/knight.png`.

- Tiny Swords: dark blue-gray outlines, pixel-stepped silhouettes, compact characters, blue roof shingles, warm timber/plaster, olive grass and turquoise stone cliff tiles. Used for this direction.
- `hero_town`: very simple thick-line painted shapes; a separate visual family.
- `hand_draw`: pencil-textured paper-cutout characters and architecture; also a separate visual family.

## Direct image references

All paths below are relative to the project root.

1. `asset/Tiny Swords (Free Pack)/Buildings/Blue Buildings/House1.png`
2. `asset/Tiny Swords (Free Pack)/Buildings/Blue Buildings/Barracks.png`
3. `asset/Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior_Idle.png`
4. `asset/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color1.png`
5. `concept-art/2026-09-27/arena-centered-park.png` — composition edit target only.

## Deliverables

- `project-style-arena-park.png`: panoramic arena-first design interpreted in the current project sprite style.
- `project-style-arena-desktop.png`: compact desktop-scale mockup.

The central arena, carousel, booths and crowd arrangements are newly generated concepts; their exact sprites would still need production work. The source images above were supplied directly to imagegen, rather than relying only on verbal descriptions.

## Final close-up prompt

Use case: style-transfer.
Asset type: asset-grounded concept illustration for an idle medieval fight-arena tycoon.
INPUT ROLES:
Image 1: ACTUAL PROJECT ASSET, a blue-roofed house. Primary reference for exact outline language, roof tiles, timber colors, cream plaster, stylization and pixel rendering.
Image 2: ACTUAL PROJECT ASSET, a barracks. Primary reference for stone/timber construction, chunky roof shapes, blue-gray outline and simple pixel shading. Use these construction details to invent a matching arena.
Image 3: ACTUAL PROJECT ASSET, a warrior idle spritesheet. Primary reference for character proportions, helmet, shield, plume, outline and sprite scale. Its repeated figures are ANIMATION FRAMES OF ONE HERO, not a queue of separate heroes. Do not reproduce the spritesheet.
Image 4: ACTUAL PROJECT ASSET, grass and cliff tiles. Primary reference for the lime/olive grass surface, irregular scalloped edge, turquoise stone cliffs, chunky tile geometry and restricted color shading. Do not reproduce the tilesheet.
Image 5: EDIT TARGET for COMPOSITION ONLY: the new arena-centered layout with surrounding businesses. Keep its broad central arena, smaller side clusters, paths and expansion land. Completely REPLACE its detailed painterly rendering with the project sprite art style established by Images 1–4. Image 5 is NOT a style reference.
PRIMARY REQUEST:
Redraw the arena-centered park as if it belongs to the same 2D sprite asset pack as Images 1–4. This must look like a real cohesive Godot sprite-game environment assembled from the existing assets and newly drawn matching sprites, not a high-detail concept painting or a 3D diorama with a pixel filter.
STYLE:
Faithfully follow the provided assets: chunky dark blue-gray outlines, visible deliberate pixel-stepped edges, crisp consistent pixel scale, simple flat limited-shade color clusters, exaggerated cozy medieval shapes, cream plaster, honey timber, muted saturated blue/cyan roof shingles, bright olive grass and blue-teal cliff stones. Small top-down/front-facing 3/4 sprites, recognizable chubby Tiny Swords-like knight proportions. Neutral bright game lighting with simple dark oval ground shadows. No cinematic lighting, painterly brushwork, realistic material grain, tiny ornate carving, smooth 3D rendering, blur, bloom, or random pixel noise. Do not change this into an unrelated 8-bit style: match the resolution and rich chunky sprite language of the references.
COMPOSITION:
Ultrawide 3:1 panorama, ideally 3072x1024, showing ONLY the game strip close-up, not a full desktop. A narrow cohesive band of terrain on a plain unobtrusive slate background. The entire game is designed to be readable when scaled down to roughly 180–220 pixels high along a desktop edge. Keep all structures compact and reduce detail to what reads at that size.
The ARENA remains the clear focus, occupying approximately the middle 45 percent of the image width. A large readable golden-beige oval or softly octagonal sand floor, low timber/blue-gray-stone perimeter, horseshoe-shaped two-row stands at the back and sides, a short blue-and-cream canopy, modest red/blue pennants. Keep the front edge low and open to sight. Arena construction must look built out of the same wood and stone as the barracks reference, not Roman arches or elaborate monumental masonry. The broad bright floor and three tiny colorful fighting heroes are the highest-contrast focal area. Exactly three active heroes: blue shield knight matching the warrior, a red-accented swordfighter using the same proportions, and a hooded monk/staff fighter in the same sprite language. No gore, one small simple yellow pixel impact burst.
Place lower, smaller supporting buildings around the central arena in shallow asymmetrical clusters. Left: a food/tavern building strongly resembling the provided blue-roof house, a tiny medieval wooden-horse carousel rendered in the same chunky sprite style, a compact ticket awning. Right: an armorer based on the supplied barracks, an archery booth with three straw target circles, a little planted seating nook. Use simplified asset-sized versions, not richly detailed miniature buildings. Reserve two hero sprites by the arena side entrance. Small pawn-like crowd sprites stand in the stands and walk between facilities.
Use the ACTUAL terrain reference language for the foundation: grassy yellow-green top edge and distinct chunky blue-teal stone cliff sides, shallow foundation only. A tan pixel path links the businesses and arena entrances. A few simple teal-green conifers in the same chunky sprite language, placed sparingly. Bare grassy construction plots with simple wood-stake edges near both outer ends show expandability. Do not arrange every structure at equal importance or identical spacing.
No title, no text, no desktop windows, no large UI, no character cards, no labels, no watermark. The output is a style-matched concept for the supplied project assets, with the approved ARENA-FIRST spatial design.

## Final desktop prompt

Image inputs in order: `arena-centered-desktop.png`, the newly generated `project-style-arena-park.png`, Warrior_Idle, Tilemap_color1, and House1 from the asset paths above.

Use case: compositing.
Asset type: desktop-scale mockup for a medieval idle arena tycoon, matching the actual project's 2D sprite art.
Image 1 is the EDIT TARGET: preserve its desktop screenshot composition, document and calendar windows, blue desktop wallpaper, operating-system taskbar, and small bottom-of-screen game footprint.
Image 2 is the NEW PARK DESIGN AND STYLE REFERENCE: the broad central arena, side businesses, chunky outlined characters, blue roofs, grass and turquoise stone cliff platform. Transfer this entire park design into the compact bottom band of Image 1.
Image 3 is an ACTUAL PROJECT WARRIOR SPRITESHEET, reinforcing the compact proportions and dark outlined rendering. Its repeated figures are animation frames of one character; do not copy the whole sheet.
Image 4 is an ACTUAL PROJECT TERRAIN TILESET, reinforcing the lime/olive grass and blue-teal cliff-edge shapes, crisp sprite shading and pixel edges.
Image 5 is an ACTUAL PROJECT HOUSE SPRITE, reinforcing blue shingle roof, tan wood, cream plaster and thick blue-gray outline.
Change ONLY THE GAME STRIP to use the new project-matching art and arena layout. The surrounding work windows and operating-system UI stay clean and unchanged.
Keep every game object inside a shallow band approximately the lower 18 percent of the desktop, directly above the taskbar. No flags, roofs or game panels intrude higher than the original park. If necessary, simplify the geometry and reduce stands to two rows so it fits. The normal desktop work area must dominate the image's height, while the ARENA dominates the GAME BAND.
Park arrangement: the center contains a broad low oval arena with pale sand, timber stands along its back and sides, a short blue/cream canopy, red/blue pennants, exactly three small distinct fighting heroes, and a cheering crowd. The floor is the clearest brightest shape. The center arena is substantially wider than any side building and should take roughly 40 percent of the strip's width. Around it sit smaller muted-blue-roof medieval businesses: tavern, miniature wooden-horse carousel and ticket awning on the left, armorer, archery booth and garden seating on the right. Paths feed into the arena, tiny visitors circulate, grassy building plots at the outer edges leave room for expansion. A shallow grass-topped turquoise rock base ties everything together.
Visual style must closely match the provided ACTUAL PROJECT assets and Image 2: deliberately chunky 2D pixel-sprite rendering, dark blue-gray outlines, crisp pixel steps, simplified limited-shade surfaces, cute stocky armored heroes, bright yellow-green grass, cyan-blue roofs, warm timber. No realistic painterly grain, volumetric lighting, smooth 3D diorama shading, ornate miniature detail, dramatic bloom or blurry scaling. Strong simple shapes readable at actual idle-game size.
The coin/build/pause micro controls remain tiny; coin text is "180". No giant character cards or dashboards, no extra headings, no labels or watermark. Frontal 16:9 desktop screenshot, ideally 2560x1440. This should look like the existing project's game assets expanded into the new arena-centered tycoon design and living at the bottom of an ordinary desktop.

