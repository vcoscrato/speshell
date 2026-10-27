# Previews

Offscreen renders of Speshell for working on it locally: the effects in each scene, the paintings, the real bar with its panels, and the effects' GPU cost. Nothing here ships or is loaded by the shell.

- `scenes/` holds the harness, `shell.qml`, which renders a scene through an invisible 1×1 overlay with virtual time, and the scenes: launcher, wallpaper, controls, picks, clock, a painting, and the many-copies scene the benchmark measures.
- `preview.sh` renders an effect's scene into a video and a contact strip, for `just preview` and `just check`; `bench.sh` measures the effects' GPU time, for `just bench`; and `shot.sh` runs `shot.qml`, the real shell with each panel open, for `just shot`. `just paint` renders a theme's painting with the painting scene.

Run every recipe from the repository root. They need a Wayland session, plus `qt6-shadertools`, ffmpeg, and ImageMagick. Output goes to `~/.cache/speshell-preview/` (`PREVIEW_OUT`), outside the checkout.

```bash
just preview fire launcher               # ~/.cache/speshell-preview/fire-launcher.mp4 and a contact strip
just preview water wallpaper
just preview earth clock                 # the clock face, at the panel's size and at twice it
just preview earth controls              # sliders, switches, and picks, at twice the size
just preview earth picks                 # picks up close: a bar's clock clicked near its end, a row, a button
just check                               # every effect in every scene but picks
just bench fire                          # GPU time per frame at 1080p, phase by phase
just bench -a HEAD earth                 # the same, against the last commit
just shot fire                           # the real bar with each panel open, and a contact sheet
just shot earth network settings         # only those panels (or `launcher`)
```

Scenes drive `EffectClock` with virtual time, 1/60 s per frame, so captures match real playback, and every scene draws in the colors of the theme named like the effect. The wallpaper scene hosts this checkout's `shell/core/WallpaperView.qml`. The clock scene shows the face over the backdrop, at the clock panel's size and at twice it, ticking from 10:09:30 and keeping still from 3 s, as in power saver. The controls scene plays a script on mock controls in those colors: a slider dragged and let go twice, another stepped by the wheel, an audio device and a segment picked, a switch turned on and off, and a square button picked. Env knobs:

- `WALL_A` and `WALL_B`: your own wallpapers.
- `CLOSE_AT`, `REOPEN_AT`, `SWITCH_AT`, and `SPEED` for the scenes; `SWITCH_AGAIN_AT` switches the wallpaper back mid-transition, to see one cut short.
- `THEME_INI`: another theme's `theme.ini`, to see the effect in its colors.
- `KEEP_FRAMES=1` keeps the frames, about 700 MB per run; `EVERY_FRAME=1` captures at 60 fps instead of 30.
- For shot, `SHOT_CONFIG`: another `config.ini` than yours, `SHOT_QUERY`: what to type into the launcher or the theme gallery, and `SHOT_MEDIA=1` to show the playing track, hidden by default since its cover is someone else's art. Shots run from a copy of the tree with a fresh data directory, with a timer and a screen recording running, and land in `~/.cache/speshell-preview/shots/<theme>/`.
- For bench, `-a REF` to compare against a commit, `-p` to pick phases (`open`, `motion`, `wallpaper`, `controls`, `clock`), `-r` for the runs per phase, and `-m` for the Markdown Cost table. It renders on the NVIDIA GPU of a hybrid laptop; `BENCH_GPU=default` leaves the choice to the system.

`just clean` removes compiled shaders and everything in `~/.cache/speshell-preview/`.

**Try it in the real shell.** Quickshell reloads QML when its files change, but Qt keeps every shader it has loaded until the process exits. Restart Speshell after a shader change, including after `just local-package-install`.
