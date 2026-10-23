# Ashen Idle – The Cinder Reckoning

Portrait-mode Godot 4.3 Android idle RPG. The repository includes the game source and a GitHub Actions workflow that checks the project and exports an installable debug-signed APK.

**Download builds:** Open the **Actions** tab, select **Build Android APK**, then download the `AshenIdle-Android-APK` artifact from a successful run. Extract its ZIP to get the APK.

## Heroes and evolution

Choose **Cinder Knight**, **Ash Ranger**, **Ember Mage** or **Dusk Reaper** at startup. Once battle starts, that class is locked for the current session. Fully exit and restart the game to select a different class; save progress is retained.

Each class has three distinct evolution paths with class-specific names and passives. At **levels 75, 170, 250 and 500**, the EVOLVE menu presents three choices. Each milestone awards one permanent choice, with stronger effects at later milestones. Paths can be combined over the four evolutions.

- **Assault:** attack and critical damage, additional cleave attacks, class-specific combat bonuses.
- **Guardian:** maximum health, defense and healing from kills, with class-specific protection.
- **Mystic:** spell strength, MP recovery and reduced cooldowns, with class-specific spell bonuses.

Evolution choices persist in `save_v2.json` independently for each class. The UI shows completed and upcoming milestones.

## Art direction and licensing

The game uses cinematic charcoal-and-copper UI, a physically-based weathered stone floor, human-proportioned 3D characters and high-intensity elemental effects for portrait Android.

- Character GLB sources: [Quaternius CC0](https://quaternius.com/) animated knight, humanoid, skeleton, ghost, demon. Converted GLB files are retrieved from [warptracker](https://github.com/ilrein/warptracker) (see its [ASSETS.md](https://github.com/ilrein/warptracker/blob/main/ASSETS.md)).
- Dungeon PBR stone texture from [Poly Haven Stone Floor](https://polyhaven.com/a/stone_floor), CC0.
- KayKit fallback models and stylized dungeon ruin props, CC0.
- Sound effects procedurally synthesized at runtime, without third-party recordings.
- Cinzel fantasy display font, SIL Open Font License, stored with license.
- No paid services required for development; Android release requires play-testing, performance reviews and store-ready signing.

This project is a playable development build; it is not represented as a professionally finished commercial game.
