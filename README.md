# Web Creature

A Roblox web-swinging movement demo. You play as the Web Creature, a blocky Roblox-style hero in a
black suit with red hands and feet, big white eyes and four mechanical spider legs on its back.

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder
   (installs Rojo, Selene and StyLua at the versions in `rokit.toml`).
2. Install the Rojo plugin in Roblox Studio (`rojo plugin install`).
3. Run `rojo serve`, open a new **Baseplate** place in Studio, and click **Connect** in the Rojo plugin.
4. Optionally delete the default `Baseplate` (the city builds its own ground and spawn).
5. Press **Play**.

The avatar type should be **R15** (Game Settings → Avatar). R6 works but loses some details.

## Controls

| Action | PC | Gamepad | Mobile |
|---|---|---|---|
| Swing (hold) | Left mouse | R2 | "Web" button |
| Steer | WASD | Left stick | Thumbstick |

- Hold to swing, let go to fling. You don't need to aim: the web picks the best building in the direction you're pressing (or where the camera faces if you aren't pressing anything).
- Steer mid-swing with WASD / the stick: it turns your swing without losing speed. Hold backwards to slow down.
- Webs wrap around building corners instead of passing through them, so you can swing around a building. Swing back and the web unwraps.
- Walls near you gently push you away, so you slide past buildings instead of crashing into them.
- Let go while rising at the front of the arc for a **perfect release** (bigger boost).
- Hold the button while falling and the web fires as soon as a building is in range.
- Hold backwards in the air to brake.

## Code layout

```
src/shared/   Config (every tuning number), MathUtil, Signal, Cleaner
src/server/   CityBuilder (test city), WebCreatureLook (character), CharacterSpawner
src/client/   MovementState (state machine), InputController, LocomotionController (Ground/Air),
              SwingController (web swing), WebVisuals, CameraController
```

To change how swinging feels, edit `Config.Swing` in `src/shared/Config.luau`.
