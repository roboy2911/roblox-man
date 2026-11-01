# Web Creature

A Roblox web-swinging game. You play as the Web Creature, a blocky Roblox-style hero with a suit,
big white eyes and four mechanical spider legs on its back. Swing through a huge city, stop
crimes, level up and unlock suits.

**Ready to publish? See [PUBLISHING.md](PUBLISHING.md).**

## Setup (development)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder
   (installs Rojo, Selene and StyLua at the versions in `rokit.toml`).
2. Install the Rojo plugin in Roblox Studio (`rojo plugin install`).
3. Run `rojo serve`, open a place in Studio, and click **Connect** in the Rojo plugin.
4. Set **Game Settings > Avatar > Avatar Type** to **R15**, and turn on
   **Game Settings > Security > Enable Studio Access to API Services** so progress saves.
5. Press **Play**.

## Gameplay

- **Swing** around a city of 24x24 blocks with five downtown skylines.
- **Crimes** pop up near you (red **!** in the sky). Thugs fight back. Knock them all out to earn
  coins and XP. Swing in and punch while moving fast to knock a thug out in one hit.
- **Level up** from crimes and tricks. Each level gives bonus coins and your level shows over your head.
- **Suits**: 8 suits, unlocked with coins once you reach their level (Gold comes with VIP).
- **Gamepasses**: VIP (Gold suit + double coins) and Rainbow Webs.
- **Multiplayer**: everyone sees each other's webs, poses and spider legs.
- **Settings**: camera follow/tilt/shake, speed zoom, speed lines, control hints. Saved per player.

## Controls

| Action | PC | Gamepad | Mobile |
|---|---|---|---|
| Swing (hold) | Left mouse | R2 | "Web" button |
| Web zip | E | L1 | "Zip" button |
| Punch | F | X | "Punch" button |
| Double jump + flip | Space (in the air) | A (in the air) | Jump (in the air) |
| Dive (hold, in the air) | Q | L2 | "Dive" button |
| Point launch | Space right as a zip ends | A right as a zip ends | Jump right as a zip ends |
| Wall run | Fly fast alongside a wall | same | same |
| Wall jump | Space while wall running | A | Jump |
| Hide help | H | | |
| Steer | WASD | Left stick | Thumbstick |

## Code layout

```
src/shared/   Config (every tuning number), Suits, Progression (levels), Remotes (network),
              MathUtil, Signal, Cleaner
src/server/   CityBuilder (city), DataService (saving, coins, XP, gamepasses), ShopService,
              CharacterSpawner (suits, nameplates), WebCreatureLook (character model),
              CrimeService (crimes, thugs, combat), MotionRelay (multiplayer)
src/client/   Movement: MovementState, InputController, LocomotionController, SwingController,
                        TrickController, CombatController
              Visuals:  PoseController, GearAnimator, WebVisuals, Effects, CameraController,
                        NPCAnimator, RemoteViews (other players), MotionSync
              UI:       Menu (main menu, shop, settings), HUD, Notifications, CrimeMarkers,
                        UIKit, Sounds, Settings, Profile
```

Poses, animations and sounds are all code-driven, so nothing needs uploading. Sounds are empty
slots until you add IDs (see PUBLISHING.md).
