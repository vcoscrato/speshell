# Themes and effects

The themes and effects Speshell ships, the paintings behind their wallpapers, and the lab used to build and check them. Everything here is original work.

| Theme | Effects | Wallpaper (painting) | Launcher | Wallpaper change | Controls | Clock face |
|---|---|---|---|---|---|---|
| Cosmos (default) | `cosmos` | `spiral-galaxy` | Opens out of a flaring star; planets orbit it while open | Supernova | Planet knobs with a moon; star dust trails, glints, constellations drawn out from what you pick | An orrery: the hour's planet and the minute's ringed giant circle the sun, held to it like hands, and a comet runs the seconds |
| Fire | `fire` | `ember-dusk` | Burns in behind an ember's edge; flames simmer around it | Burns away from the middle | Ember knobs that flame when held; the track burns behind them, sparks, smoke; what you pick catches fire, with embers floating up | Charcoal cracked with embers inside a ring of flames; forged blades for hands and an ember running the seconds |
| Air | `air` | `cloud-sea` | Unwinds out of a whirlwind; a breeze with leaves circles it | Whirlwind eye | Spinning wind-ball knobs; wind from behind blows a dragged knob along, wisps and leaves, curls of wind | Cloud banks and circling wind over a compass rose; a leaf and a feather for hands, and a leaf riding round with the seconds |
| Water | `water` | `polar-night` | A water whip coils into it and clears through rippling caustics; two streams chase its border among orbs, currents, and mist held in the air | Ripple | Drop knobs that stretch as they move; water pours off as a slider goes down and rains onto it as it goes up, ripples; a drop splashes a crown up from what you pick, flinging drops that ripple where they land | A pool with drifting caustics; glassy currents for hands round a whirlpool, and a drop each second that ripples |
| Earth | `earth` | `jade-valley` | Punches up out of cracked ground as a stone slab; tumbling boulders with circling pebbles hover in a ring of dust and stones | Cracks and crumbles | Rolling stone knobs; kicked-up rock chips and dust, jade shards | Layered, cracked stone with jade at the hours; obelisks for hands, and a pebble rolling in a groove |
| Relâmpago | `relampago` | `thunder-road` | Races in from the left in a red streak with a bolt through it, brakes with sparks and skid marks, and stops in tire smoke as lightning strikes all around it; while open, speed lines stream past, electricity crackles on its border, and now and then a bolt strikes it; tears away on two trails of fire | Lightning splits it, and the halves race apart | Racing-wheel knobs carrying a zigzag bolt along the filled track, crackling live while held; sparks and arcs, discharges, lightning striking what you pick | A tachometer with a redline; needles on a checkered cap, and a bolt striking out to each second |

## Layout

| Path | Holds | Ships | Who edits it |
|---|---|---|---|
| `themes/<theme>/` | `theme.ini` (name, palette, `effects = <name>`) and the rendered wallpaper `<painting>.jpg` | yes | designers: palettes; artists: commit the wallpaper they render |
| `paintings/` | `<painting>.frag`, one shader per wallpaper, and `landscape.glsl`, the helpers they share | no | artists |
| `effects/<name>/` | The launcher and wallpaper transitions, the backdrop of Speshell's surfaces, the effects on its controls, and the clock face. See [effects/README.md](effects/README.md) | yes | effects developers |
| `lib/` | `common.glsl` (noise, signed distances, banding, compositing, Voronoi, rounded-rect borders), `EffectClock.qml`, `ClockTime.qml`, `Particles.qml`, and `Colors.js`, shared by every effect | yes | effects developers; a change here touches every effect |
| `lab/` | The offscreen harness, scenes, and scripts behind the `just` recipes; renders go to `~/.cache/speshell-lab/` (`LAB_OUT`), outside the checkout | no | anyone improving the tooling |

The package installs `themes/`, `effects/`, and `lib/` to `/usr/share/speshell/extras`. Nothing else in this directory ships. Keep sources and tools out of those three directories.

Names are lowercase-kebab for directories and paintings; QML components are PascalCase, and an effect's shaders take the name of the QML that draws them. A theme and an effect share a name (`fire`), and a painting for its scene (`ember-dusk`). Any theme can use any effects.

## Rules

- **Original work only.** No fan art, photos, fonts, or code under another license. Wallpapers come from shaders in `paintings/`, so their whole source is in the repository.
- **A wallpaper is committed with its painting.** After editing `paintings/<painting>.frag`, run `just paint <painting>` and commit the `.jpg` in the same change.
- **`just check` passes** before effects changes are merged. It fails on any QML error or warning, or a transition that never finishes.
- **Stay within the GPU budget:** under 0.5 ms per frame at 1080p in every phase (`just perf`). The current costs are in [effects/README.md](effects/README.md#cost).
- **Compiled shaders are build output.** `just shaders` writes them to git-ignored `qsb/` folders beside their sources, and the package build runs it.

## Workflows

Run every recipe from the repository root. The lab renders through an invisible 1×1 overlay, so it needs a Wayland session, plus `qt6-shadertools`, ffmpeg, and ImageMagick.

**Retune a theme's palette.** Edit `themes/<theme>/theme.ini`. Its keys are listed in `themes/cosmos/theme.ini`; missing ones fall back to Cosmos. Pick the theme in Speshell's Settings › Appearance to see it.

**Paint a wallpaper.**

```bash
just paint ember-dusk                    # renders paintings/ember-dusk.frag over themes/fire/ember-dusk.jpg
WIDTH=1920 HEIGHT=1080 just paint ember-dusk   # quicker draft while iterating
just paint                               # re-render every wallpaper that has a painting
```

A painting renders over each `themes/*/<painting>.jpg` of the same name. A new painting with no wallpaper yet lands in `~/.cache/speshell-lab/<painting>.jpg`; copy it into its theme folder once. Start a new painting from an existing one: it shows the uniform block, the `common.glsl` and `landscape.glsl` includes, and the header comment that describes the scene.

**Add a theme.** Create `themes/<theme>/` with a `theme.ini` and a wallpaper, usually from a new painting. Add it to the table above.

**Build or change effects.** Copy the closest effect directory (with its `common` symlink, made with `ln -s ../../lib common`) and follow [effects/README.md](effects/README.md). Then iterate:

```bash
just preview fire launcher               # ~/.cache/speshell-lab/fire-launcher.mp4 and a contact strip
just preview water wallpaper
just preview earth clock                 # the clock face, at the panel's size and at twice it
just preview earth controls              # sliders, switches, and picks, at twice the size
just preview earth picks                 # picks up close: a bar's clock clicked near its end, a row, a button
just check                               # every effect in every scene but picks
just perf fire launcher                  # GPU time per frame at 1080p
just shot fire                           # the real bar with each panel open, and a contact sheet
just shot earth network settings         # only those panels (or `launcher`)
```

Scenes drive `EffectClock` with virtual time, 1/60 s per frame, so captures match real playback, and every scene draws in the colors of the theme named like the effect. The wallpaper scene hosts this checkout's `core/WallpaperView.qml`. The clock scene shows the face over the backdrop, at the clock panel's size and at twice it, ticking from 10:09:30 and keeping still from 3 s, as in power saver. The controls scene plays a script on mock controls in those colors: a slider dragged and let go twice, another stepped by the wheel, an audio device and a segment picked, a switch turned on and off, and a square button picked. Env knobs:

- `WALL_A` and `WALL_B`: your own wallpapers.
- `CLOSE_AT`, `REOPEN_AT`, `SWITCH_AT`, and `SPEED` for the scenes.
- `THEME_INI`: another theme's `theme.ini`, to see the effect in its colors.
- `KEEP_FRAMES=1` keeps the frames, about 700 MB per run; `EVERY_FRAME=1` captures at 60 fps instead of 30.
- For shot, `SHOT_CONFIG`: another `config.ini` than yours, `SHOT_QUERY`: what to type into the launcher, and `SHOT_MEDIA=1` to show the playing track, hidden by default since its cover is someone else's art. Shots run from a copy of the tree with a fresh data directory, with a timer and a screen recording running, and land in `~/.cache/speshell-lab/shots/<theme>/`.
- For perf, `PERF_FROM` and `DURATION`. For example, `CLOSE_AT=30 PERF_FROM=1.5 DURATION=4.5 just perf air` measures only the open launcher.

`just clean` removes compiled shaders and all lab output.

**Try it in the real shell.** Quickshell reloads QML when its files change, but Qt keeps every shader it has loaded until the process exits. Restart Speshell after a shader change, including after `just local-package-install`.
