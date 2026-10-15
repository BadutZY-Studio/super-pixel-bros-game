<div align="center">

<img src="assets/ui/logo.png" height="90" alt="SUPER PIXEL BROS">

# SUPER PIXEL BROS

**A Retro Pixel Platformer with 20 Levels, Power-Ups, Chiptune Music, and a Cosmetic Shop**

[![Engine](https://img.shields.io/badge/Engine-Godot%204.7-478CBF?style=for-the-badge&logo=godotengine&logoColor=white)]()
[![Language](https://img.shields.io/badge/Language-GDScript-355570?style=for-the-badge&logo=godotengine&logoColor=white)]()
[![Renderer](https://img.shields.io/badge/Renderer-GL%20Compatibility-FF4040?style=for-the-badge)]()
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-0078D6?style=for-the-badge)]()
[![Levels](https://img.shields.io/badge/Levels-20-A855F7?style=for-the-badge)]()
[![Assets](https://img.shields.io/badge/Assets-100%25%20Generated-F59E0B?style=for-the-badge)]()

[About](#about) • [Getting Started](#getting-started) • [Gameplay](#gameplay) • [Shop and Cosmetics](#shop-and-cosmetics) • [Controls](#controls) • [Development](#development) • [Configuration](#configuration) • [Project Structure](#project-structure) • [Credits and License](#credits-and-license) • [Disclaimer](#disclaimer)

---

## About

SUPER PIXEL BROS is a classic side-scrolling pixel platformer. You run, jump, stomp enemies, break bricks, grab power-ups, and race to the flagpole across 20 hand-designed levels split into 2 chapters and 9 world themes. The game features modern jump physics (variable jump height, coyote time, and jump buffering), a chiptune soundtrack, and a complete pixel-art interface.

Every coin you pick up also fills a permanent wallet that is spent in the **SHOP** on skins, suits, hats, face items, back items, and particle trails. Owned items can be mixed freely, and the equipped look is used in every level.

Every sprite, tile, background, sound effect, and music track is generated from scratch by the Python scripts in `tools/`, so the project contains no third-party game art or audio. The game runs on Godot 4.7 with the GL Compatibility renderer, and every screen works with keyboard, mouse, and game controller.

---

## Getting Started

The simplest way to play is to export a build for your platform (see [Exporting a Build](#exporting-a-build)) or to run the project directly from the Godot editor (see [Development](#development)).

### System Requirements

| Item | Requirement |
|---|---|
| Operating System | Windows (x86_64), Linux (x86_64), or macOS |
| Graphics | Any GPU with OpenGL compatibility support (the game uses the GL Compatibility renderer) |
| Display | 400x224 pixel base resolution, opened in a 1200x672 window and scaled to any window size or fullscreen |
| Input | Keyboard, game controller, or both. Mouse and touch input work in all menus |
| Players | 1 player |

### Quick Play

1. Launch the game and choose **START GAME**.
2. Pick an unlocked level on the level select screen.
3. Run to the flagpole before the timer runs out.
4. Collect coins along the way and spend them in the **SHOP** from the main menu.
5. Clearing a level unlocks the next one. Clearing level 10 opens Chapter 2.

---

## Gameplay

### Chapters and Levels

| Chapter | Levels | Unlocked By | New Elements |
|---|---|---|---|
| Chapter 1 | 1 to 10 | Available from the start | Core mechanics, 7 world themes, checkpoints, moving platforms |
| Chapter 2 | 11 to 20 | Clearing level 10 | Warp pipes, bats, springs, star blocks, fire bars, falling platforms, crushers, jungle and space themes |

Use the `<` and `>` buttons (or Q / E, LB / RB) on the level select screen to switch chapters. Levels unlock in order, and each level card shows a medal when the level is cleared, plus the best score.

| No. | Level | Theme | Time | No. | Level | Theme | Time |
|---|---|---|---|---|---|---|---|
| 1 | Green Hills | Grass | 300 | 11 | Warp Valley | Jungle | 330 |
| 2 | Dune Run | Desert | 320 | 12 | Vine Run | Jungle | 340 |
| 3 | Crystal Cave | Cave | 340 | 13 | Bat Cave | Cave | 350 |
| 4 | Frosty Peaks | Snow | 340 | 14 | Spring Dunes | Desert | 350 |
| 5 | Midnight Run | Night | 330 | 15 | Ice Steps | Snow | 360 |
| 6 | Sky High | Sky | 320 | 16 | Moonwalk | Space | 340 |
| 7 | Ancient Ruins | Desert | 350 | 17 | Crater Crush | Space | 360 |
| 8 | Blizzard Pass | Snow | 360 | 18 | Midnight Bats | Night | 370 |
| 9 | Fire Fortress | Castle | 380 | 19 | Lava Forge | Castle | 400 |
| 10 | Final Castle | Castle | 420 | 20 | King's Return | Castle | 440 |

Each theme has its own sky colors, parallax backgrounds, decorations, music, and atmosphere effects (snow, dust, or embers). The Space theme uses low gravity.

### Hero Forms and Power-Ups

The hero has three forms. Taking a hit as Big or Fire shrinks the hero back to Small with a short period of invincibility. Taking a hit as Small costs a life.

| Form | How To Get It | Abilities |
|---|---|---|
| Small | Default | Dies when hit |
| Big | Mushroom | Breaks bricks from below and survives one hit |
| Fire | Fire Flower | Throws fireballs with the run button (up to 2 on screen) |

| Item | Effect |
|---|---|
| Coin | Gives 200 points and adds 1 coin to the shop wallet. 100 coins in one run give 1 extra life |
| Mushroom | Grows the hero to Big |
| Fire Flower | Turns the hero into Fire |
| Star | 9 seconds of invincibility (from star blocks in Chapter 2) |
| 1UP | Adds one extra life |

### Blocks, Hazards, and Enemies

| Category | Elements |
|---|---|
| Blocks | Brick (breaks when Big), coin block, power-up block, star block, hard block |
| Platforms | Static one-way platforms, horizontal and vertical moving platforms, falling platforms |
| Hazards | Spikes, lava, bottomless pits, fire bars, crushers, and slippery ice in snow levels |
| Helpers | Springs (hold jump for full height), warp pipes that lead to bonus rooms or shortcuts, checkpoints |
| Enemies | Goomba-like walker, Koopa-like walker (stomp it and kick the shell), Piranha plant that rises from pipes, and flying bats (Chapter 2) |

Enemies can be defeated by stomping, fireballs, a shell kick, or star invincibility. To use a warp pipe, stand on top of the pipe with the bobbing arrow and press **DOWN**.

### Scoring, Lives, and Progress

| Rule | Detail |
|---|---|
| Lives | A new run starts with 3 lives. 100 coins or a 1UP item give an extra life |
| Stomp combo | Consecutive stomps without touching the ground score 100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, and up to 8000 |
| Flagpole | Grabbing the pole higher gives more points, then the hero walks into the castle |
| Time bonus | 50 points for every second left on the clock. A warning plays when the time is low |
| Checkpoints | Touching a checkpoint flag saves your position for the current level |
| Best score | The best score for every level is saved and shown on the level cards |
| Clear reward | Every course clear pays 10 bonus coins into the shop wallet |

Pausing opens a menu with **RESUME**, **RESTART LEVEL**, **LEVEL SELECT**, and **MAIN MENU**.

---

## Shop and Cosmetics

The **SHOP** is opened from the basket button on the main menu (or with the **B** key). It shows a live animated preview of your hero, category tabs, an item grid, and an info bar. Buying an item asks for confirmation first. Equipped items are applied immediately and used in every level.

| Category | Items | Price Range (coins) | Notes |
|---|---|---|---|
| Skin | 12 | 40 to 250 | Full color sets. Classic is free |
| Suit | 12 | 25 to 200 | Outfits such as Farmer, Pirate, Ninja, Royal, and Rainbow. Original is free |
| Hat | 11 | 15 to 200 | Beanie, Top Hat, Wizard Hat, Halo, Crown, and more |
| Face | 7 | 15 to 60 | Glasses, masks, eyepatch, and big beard |
| Back | 7 | 30 to 160 | Backpack, capes, angel and demon wings, jetpack |
| Trail | 6 | 25 to 120 | Bubbles, snowfall, sparkle, hearts, flames, rainbow |

In total there are 55 cosmetic items (2 free, 53 purchasable). Skin and suit always have one item equipped, while hat, face, back, and trail can be removed. All cosmetics are drawn at runtime from the same pixel maps as the base hero, so no extra image files are needed. The wallet, owned items, and equipped loadout are saved automatically.

---

## Controls

All keyboard keys and gamepad buttons below are the defaults and can be changed in **OPTIONS > CONTROLS**.

### Keyboard

| Action | Default Keys |
|---|---|
| Move | Left / Right arrows, or A / D |
| Jump (hold for a higher jump) | Space, Z, or Up arrow |
| Run and throw fireball | Shift or X |
| Enter warp pipe, crouch down | Down arrow or S |
| Pause | Esc or P |
| Open How To Play | H |
| Open Shop (main menu) | B |

### Game Controller

| Action | Default Binding |
|---|---|
| Move | Left stick or D-pad (fixed) |
| Jump | A or Y |
| Run and throw fireball | X, B, or right trigger |
| Pause | Start |
| Menu select and back | A or X to select, B to go back |

| Feature | Description |
|---|---|
| Rebinding | Every action has 3 keyboard slots and 3 gamepad slots that can be rebound, with conflict checking |
| Button labels | Labels automatically follow the connected controller style: Xbox, PlayStation, or Nintendo |
| Analog triggers | Triggers can be used as bindings |
| Menu navigation | Mouse, keyboard, touch, and controller all work in every menu. If nothing is focused, the first pad press restores focus |

### Options

| Setting | Description |
|---|---|
| Music | Music volume slider |
| Sound | Sound effect volume slider |
| Fullscreen | Fullscreen on or off |
| Controls | Keyboard and gamepad rebinding editor |
| How To Play | Help sheet that shows your current bindings |
| Reset Progress | Clears campaign progress after a second confirmation press |

---

## Core Features

| Feature | Description |
|---|---|
| 20 Levels | 2 chapters of 10 levels across 9 world themes |
| Modern Physics | Variable jump height, coyote time, jump buffering, skidding, and run speed |
| Three Hero Forms | Small, Big, and Fire with fireballs |
| Varied Enemies | Walkers, shell enemies, piranha plants, and flying bats |
| Rich Level Elements | Warp pipes, bonus rooms, springs, fire bars, crushers, falling and moving platforms, ice, lava, and spikes |
| Cosmetic Shop | 55 items across skins, suits, hats, face items, back items, and trails |
| Persistent Progress | Unlocked levels, best scores, settings, bindings, wallet, and loadout are saved |
| Animated Interface | Pixel-wipe scene transitions, animated title screen, themed level cards, and a polished HUD |
| Full Input Support | Keyboard, mouse, touch, and gamepad with complete rebinding |
| Original Audio | 8 chiptune music tracks and 21 sound effects generated by script |
| Generated Assets | All sprites, tiles, backgrounds, and audio are produced by the Python tools, so there are no copyright concerns |

---

## Game Content at a Glance

| Content | Amount |
|---|---|
| Levels | 20 (2 chapters of 10) |
| World Themes | 9 (Grass, Desert, Cave, Snow, Night, Sky, Castle, Jungle, Space) |
| Hero Forms | 3 (Small, Big, Fire) |
| Cosmetic Items | 55 across 6 categories |
| Music Tracks | 8 |
| Sound Effects | 21 |
| Backgrounds | 23 parallax layers |
| Tilesets | 9 |

---

## Save Data

All progress is stored in one JSON file in Godot's `user://` directory, separate from the game files.

| File | Contents |
|---|---|
| `super_pixel_bros.json` | Unlocked levels, best scores, volumes, fullscreen, key bindings, gamepad bindings, shop wallet, owned items, and equipped loadout |

Default location of the `user://` folder:

| Platform | Path |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\Super Pixel Bros` |
| macOS | `~/Library/Application Support/Godot/app_userdata/Super Pixel Bros` |
| Linux | `~/.local/share/godot/app_userdata/Super Pixel Bros` |

Deleting the file resets all progress, settings, and shop data. Progress can also be cleared from **OPTIONS > RESET PROGRESS**.

---

## Technology

| Layer | Technology |
|---|---|
| Game Engine | Godot 4.7 |
| Language | GDScript |
| Renderer | GL Compatibility (desktop and mobile settings) |
| Base Resolution | 400x224 with `canvas_items` stretch mode and pixel snapping |
| Autoloads | `Game` (state, save data, input map, shop wallet), `Audio` (music and sound effects), and `UI` (shared interface kit and scene transitions) |
| Main Scene | `scenes/menu.tscn` |
| Level Format | ASCII tile maps generated into `scripts/levels_data.gd` |
| Typography | Press Start 2P (SIL Open Font License) |
| Graphics | PNG sprites with nearest texture filtering, plus cosmetics baked at runtime |
| Audio | WAV music and sound effects generated by script |
| Asset Tooling | Python with Pillow and NumPy (maintainers only) |

---

## Development

### Prerequisites

- [Godot 4.7](https://godotengine.org/download) (the standard build is enough, no .NET build is needed)
- Git, for cloning the project
- Python 3 with Pillow and NumPy (optional, only to regenerate assets or levels)

### Installation

```sh
git clone <this-repository-url>
cd SuperPixelBros
```

### Running the Project

1. Open Godot and choose **Import**.
2. Select the `project.godot` file in the project folder.
3. Open the project and wait for the first asset import to finish.
4. Press **F5** to run. The main scene is `scenes/menu.tscn`.

### Exporting a Build

Export presets for **Windows Desktop** (x86_64), **Linux** (x86_64), and **macOS** are included in `export_presets.cfg`. The Windows and Linux presets embed the game data into a single executable.

1. Install the Godot 4.7 export templates from **Editor, Manage Export Templates**.
2. Open **Project, Export**.
3. Change the export path of each preset to a folder on your machine. The saved paths point to a `Games/Super Pixel Bros` folder outside the project and will probably not exist on your computer.
4. Press **Export Project** for the platform you want.

---

## Configuration

Most tuning lives in a few files, so common changes only need small edits.

| Task | Where |
|---|---|
| Change hero speed, jump strength, gravity, coyote time, or jump buffer | Constants at the top of `scripts/player.gd` |
| Change default keyboard keys | `DEFAULT_KEYS` in `scripts/game.gd` |
| Change default gamepad buttons | `DEFAULT_PAD` in `scripts/game.gd` |
| Add or remove a rebindable action | `REBINDABLE` and `REBINDABLE_PAD` in `scripts/game.gd` |
| Change the shop coin bonus per level clear | `CLEAR_BONUS` in `scripts/game.gd` |
| Change chapter layout | `CHAPTERS` in `scripts/game.gd` |
| Change stomp combo scores | `STOMP_SCORES` in `scripts/level.gd` |
| Change world themes (colors, decorations, gravity, effects) | `THEMES` in `tools/gen_levels.py` |
| Edit or add levels | `lvl1()` to `lvl20()` in `tools/gen_levels.py`, then run the generator |
| Add or edit shop items and prices | `_build_catalog()` in `scripts/cosmetics.gd` |
| Change shop layout (columns, cell size) | Constants at the top of `scripts/shop.gd` |
| Change menu buttons and options panel | `scripts/menu.gd` |
| Change the pause menu and HUD | `scripts/hud.gd` |
| Change the controls editor | `scripts/controls_panel.gd` |
| Change music or sound effects | Edit `tools/gen_audio.py` or replace the files in `assets/audio/` |

### Asset Pipeline

The sprites, tiles, backgrounds, audio, and level data are produced by the Python tools in `tools/`. The folder contains a `.gdignore` file, so Godot does not import it. Do not edit `scripts/levels_data.gd` by hand. Change the generator and run it again:

```sh
pip install pillow numpy
python3 tools/gen_levels.py
```

| Tool | Purpose |
|---|---|
| `gen_assets.py` | Chapter 1 sprites, tiles, backgrounds, and UI art |
| `gen_assets_ch2.py` | Chapter 2 sprites and themes (needs Pillow, reuses helpers from `gen_assets.py`) |
| `gen_audio.py` | Music tracks and sound effects (needs NumPy) |
| `gen_levels.py` | Level designs written in an ASCII map format, exported to `scripts/levels_data.gd` |

The level legend is documented at the top of `tools/gen_levels.py`.

---

</div>

## Project Structure

```
SuperPixelBros/
|-- assets/
|   |-- audio/                  # 8 music tracks and 21 sound effects (.wav)
|   |-- bg/                     # Parallax background layers per theme (sky, far, near)
|   |-- fonts/                  # Press Start 2P
|   |-- sprites/                # Hero forms, enemies, items, decorations, and objects
|   |-- tiles/                  # One tileset per theme
|   `-- ui/                     # Title logo
|-- scenes/
|   |-- menu.tscn               # Main menu, options, controls, and shop entry (main scene)
|   |-- level_select.tscn       # Level grid with chapters
|   `-- level.tscn              # Level gameplay
|-- scripts/                    # All game logic (GDScript)
|-- tools/                      # Python asset and level generators (ignored by Godot)
|-- export_presets.cfg          # Windows, Linux, and macOS export presets
|-- icon.png                    # Project icon
|-- project.godot               # Godot project configuration
`-- README.md
```

### Scripts Overview

| Script | Responsibility |
|---|---|
| `game.gd` | Autoload with chapters, input map, key and pad rebinding, save and load, shop wallet, and run state |
| `audio.gd` | Autoload that plays music and sound effects |
| `ui.gd` | Autoload with the pixel interface kit: buttons, sliders, toggles, panels, and wipe transitions |
| `menu.gd` | Animated title screen, options, help panel, and shop button |
| `controls_panel.gd` | Keyboard and gamepad rebinding editor |
| `level_select.gd` | Level cards, chapter switching, medals, and best scores |
| `level.gd` | Level core: builds the map from data, timer, camera, flag, scoring, warps, and bonus rooms |
| `levels_data.gd` | Generated level maps and world themes (do not edit by hand) |
| `player.gd` | Hero movement, jumping, forms, fireballs, damage, and animation |
| `enemy.gd`, `piranha.gd`, `bat.gd` | Enemy behavior |
| `item.gd`, `block.gd` | Collectibles and interactive blocks |
| `fireball.gd`, `firebar.gd` | Projectiles and rotating fire hazards |
| `platform.gd`, `falling_platform.gd`, `crusher.gd`, `spring.gd` | Moving and interactive level objects |
| `hud.gd` | In-game HUD, pause menu, course clear, and game over screens |
| `scroller.gd`, `tile_layer.gd`, `debris.gd` | Parallax scrolling, tile drawing, and brick debris |
| `cosmetics.gd` | Shop catalog and runtime sprite baking for all cosmetics |
| `shop.gd` | Shop interface with preview, tabs, grid, and purchase confirmation |

### Scene Flow

```
menu
 |-- START GAME ---> level_select ---> level ---> next level or back to level_select
 |-- SHOP (overlay on the menu)
 |-- OPTIONS (music, sound, fullscreen, controls, how to play, reset progress)
 |-- HOW TO PLAY (H)
 `-- QUIT (hidden in web builds)
```

---

## Credits and License

SUPER PIXEL BROS is an original project. All game art, tiles, music, and sound effects are generated by the scripts in `tools/` and are original to this project.

| Asset | License |
|---|---|
| Press Start 2P font | SIL Open Font License 1.1 |
| Sprites, tiles, backgrounds, music, and sound effects | Generated by the project tools |

Please check the font license before redistributing it together with a build.

---

<div align="center">

## Disclaimer

SUPER PIXEL BROS is an independent game inspired by classic side-scrolling platformers. It is not affiliated with, authorized, or endorsed by any third-party game publisher. All artwork, characters, music, and sound effects are original and created for this project. Third-party names and logos (such as Godot Engine, Windows, macOS, and Linux) belong to their respective owners.

---

*Built with Godot Engine.*

[Back to Top](#super-pixel-bros)

</div>