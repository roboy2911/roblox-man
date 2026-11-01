# Publishing Web Creature

Follow these steps in order. Steps marked **(required)** stop things from breaking for players.

## 1. Build the place file

In the `roblox-man` folder:

```bash
rokit install
```

```bash
rojo build -o WebCreature.rbxl
```

Open `WebCreature.rbxl` in Roblox Studio. (Or keep using `rojo serve` + the Rojo plugin on an open place; both work.)

Delete the default `Baseplate` part if your place has one. The game builds its own city.

## 2. Publish the place

**File > Publish to Roblox**. Give it a name (e.g. *Web Creature*) and create a new experience.

## 3. Game settings (required)

Open **Home > Game Settings**:

- **Avatar**: set **Avatar Type** to **R15**. Poses, suits and gear are built for R15.
- **Security**: turn on **Enable Studio Access to API Services**. Without it, progress isn't saved while testing in Studio (published servers save regardless).
- **Permissions**: set the game to **Public** when you're ready.

## 4. Gamepasses (optional, for Robux)

1. Go to the [Creator Dashboard](https://create.roblox.com/dashboard/creations), open your game, then **Monetization > Passes**.
2. Create two passes, give each an image and description, and set a price:
   - **VIP**: Gold suit + double coins
   - **Rainbow Webs**: webs cycle through colors
3. Copy each pass's ID (the number in its URL) into `src/shared/Config.luau`:

```lua
Config.Gamepasses = {
	VIP = 123456789,
	RainbowWebs = 987654321,
}
```

While an ID is `0`, that pass shows as "Coming soon" in the shop.

## 5. Sounds (optional)

Every sound slot is empty, so the game is silent until you fill them. In Studio open **View > Toolbox > Audio**, find sounds you like, right-click > **Copy Asset ID**, and paste them into `Config.Effects.Sounds` in `src/shared/Config.luau`:

```lua
Shoot = { Id = "rbxassetid://1234567890", Volume = 0.35, Speed = 1 },
```

Slots: `Shoot`, `Stick`, `Release`, `Whoosh`, `Zip`, `AirJump`, `Wind` (looping), `Punch`, `Hit`, `LevelUp`, `Coins`, `CrimeAlert`, `Click`.

Only use sounds that are free to use (Roblox's own or ones marked public in the Creator Store).

## 6. Test before going public (required)

1. **Test > Clients and Servers**, start **2 players**. Check:
   - Both players see each other's webs and swing poses.
   - Crimes appear (a red **!** in the sky within ~15 seconds), thugs fight back, and stopping a crime gives both players coins and XP.
   - Buying and equipping a suit works, and the suit stays after rejoining.
2. Test on a phone screen: in Studio, open the **Device** emulator and pick a phone. Check that the Web / Zip / Dive / Punch buttons and menus fit.
3. Watch **View > Output** for red errors.

## 7. Store page

In the Creator Dashboard, under your game:

- **Icon** (512x512) and **thumbnails** (1920x1080): screenshots of swinging between towers work well. In Studio, press **Play**, hide the UI, and take screenshots.
- **Description**, for example:

  > Swing through a huge city as the Web Creature! Chain swings, wall run, dive and zip between skyscrapers, stop crimes to earn coins and XP, and unlock new suits.
  >
  > PC: Hold LMB to swing, E to zip, F to punch, Q to dive.
  > Mobile and console supported.

- **Genre**: Action / Adventure. Fill in the **Maturity & Compliance** questionnaire (fighting with fists: mild violence).

## 8. Go public

**Game Settings > Permissions > Public**. Done!

## After launch

- Tuning numbers for everything (swing feel, crime rewards, suit prices, thug strength) are in `src/shared/Config.luau` and `src/shared/Suits.luau`.
- Changing `STORE_NAME` in `src/server/DataService.luau` resets everyone's progress, so leave it alone once players have data.
