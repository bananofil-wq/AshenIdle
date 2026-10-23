# Third-party asset licenses

Ashen Idle builds its art from legally reusable source assets.

## KayKit Adventurers Character Pack 1.0
- Creator: Kay Lousberg (KayKit)
- Repo: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0
- Files downloaded at build time: Knight.glb, Rogue.glb, Mage.glb, Barbarian.glb
- License: CC0 1.0 Universal
- Contains rigged and animated low-poly fantasy characters.
- License text: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/blob/main/LICENSE.txt

## KayKit Skeletons Character Pack 1.0
- Creator: Kay Lousberg (KayKit)
- Repo: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0
- Files downloaded at build time: Skeleton_Minion.glb, Skeleton_Warrior.glb, Skeleton_Rogue.glb, Skeleton_Mage.glb
- License: CC0 1.0 Universal
- Contains rigged and animated low-poly skeletons.
- License text: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0/blob/main/LICENSE.txt

These assets are downloaded automatically in the GitHub Actions build and are not required from the end user. Original creators retain attribution above, although CC0 does not require credit.

The game is a development prototype, and these stylized assets are not intended to replicate photorealistic advertising footage.

## KayKit Dungeon Remastered 1.0
- Creator: Kay Lousberg (KayKit)
- Repo: https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0
- Files downloaded at build time: floor_tile_large, floor_tile_large_rocks, floor_tile_small_broken_A, pillar_decorated, wall_broken and torch_lit (glTF GLB formats)
- License: CC0 1.0 Universal
- License text: https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0/blob/main/LICENSE.txt

## Kenney RPG Audio, Impact Sounds and Sci-fi Sounds
- Creator: Kenney (https://kenney.nl/assets/)
- Original packs: https://kenney.nl/assets/rpg-audio , https://kenney.nl/assets/impact-sounds , https://kenney.nl/assets/sci-fi-sounds
- Selected original OGG recordings are downloaded by `scripts/fetch_audio.py` during CI before Godot import.
- Source mirror: https://github.com/GeorgeQLe/assets-sfx-combat
- License: Creative Commons CC0 1.0 Universal. No attribution required.
- Used for sword attacks, boss/impact audio, looting, class abilities, and concrete/snow/grass/wood footsteps.
- The game also includes an original synthesized audio fallback if any OGG is unavailable in a development environment.

## Poly Haven CC0 photographic biome PBR maps (V3)
- Creator: Poly Haven authors (https://polyhaven.com), CC0 1.0 Universal.
- Each Android build downloads 1k JPG diffuse, OpenGL normal and roughness maps (when available) via `scripts/fetch_pbr.py`.
- Assets: `stone_floor` (Crypt), `snow_02` (Frost), `forrest_ground_01` (Thornwild), `rock_face_03` (Void), `volcanic_rock_tiles` (Molten).
- License: https://polyhaven.com/license
- The generator uses procedural biome fallback if a remote 1k channel is missing.
- Mobile: only 1k source materials, normal/roughness maps use optional fallbacks.
