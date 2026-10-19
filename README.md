# Speshell

This is Speshell, pronounced *special*. My [Quickshell](https://quickshell.outfoxxed.me/) config. Why is it special, you may ask? Well, because it's mine. Borrow whatever is useful.

<p align="center">
  <img src=".github/screenshot.png" width="100%" alt="Speshell's bar with the clock panel open and a timer running, in the Fire theme" />
  <img src=".github/screenshots/cosmos.jpg" width="100%" alt="The launcher picking a theme, in the Cosmos theme" />
</p>

<p align="center"><a href=".github/screenshots/README.md">See every theme</a></p>

## Features

- A bar on every screen: workspaces, the clock with the weather and your timers, the playing track, the tray, and a button for each panel
- Clock panel: a clock face in the theme's style beside the month
- Weather panel: the conditions now, the next hours, and the week
- Panels for audio output and input, displays and brightness, network (Wi-Fi, and NetworkManager's VPN and WireGuard profiles), Bluetooth, battery, notifications with Do Not Disturb, media, power, Markdown notes, clipboard history, and tools
- Launcher: apps, a calculator, web searches and your own bangs, themes and wallpapers
- Tools: timers, dictation, copy text from the screen (OCR), screenshots, screen recording, QR codes, color picker
- What's running, as chips in the bar: screen recording, dictation, and anything that publishes over IPC
- Themes with wallpapers and animated effects, and other apps themed to match

Panels for missing hardware or tools hide themselves. Speshell runs on any Wayland compositor with layer-shell; on [Hyprland](https://hyprland.org/) it also shows workspaces in the bar and arranges displays.

## Requirements

Quickshell ≥ 0.3, PipeWire/WirePlumber, NetworkManager, BlueZ, libnotify.

Optional: Hyprland (workspaces, the Displays panel), `brightnessctl`, `openconnect` (OpenConnect VPN logins), `libsecret` (remembering VPN passwords in the keyring), `hyprlock`, `matugen` (app themes), `cliphist`, `wl-clipboard`, `xdg-utils`, and the tools' programs below.

## Install

On Arch:

```bash
git clone https://github.com/vcoscrato/speshell.git
cd speshell
makepkg -si
```

Start it with your session, and bind the launcher to a key. On Hyprland:

```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("speshell --no-duplicate --daemonize")
end)

hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("speshell launcher toggle"))
hl.bind("SUPER + C", hl.dsp.exec_cmd("speshell panel toggle clock"))
```

The first run seeds `~/.config/speshell/config.ini`; upgrades never touch it or `~/.local/share/speshell`.

## The bar

The Speshell mark at the left opens the launcher, followed by the screen's workspaces. The clock sits in the middle and opens the clock panel; the playing track sits before it, its cover opening the player, and the weather, your timers, and what's running after, opening the forecast and each timer. A dictation or a screen recording shows there as a chip with its running time: click it to finish, and right-click a dictation to discard it. The tray and the panel buttons fill the right. Scroll over the speaker, microphone, or display button to change the volume or brightness, and right-click the speaker or microphone to switch devices.

`speshell panel open|toggle NAME` opens a panel from a keybinding; `speshell panel list` names them.

## Configuration

Common options are in the **Settings** panel. Everything else is in `~/.config/speshell/config.ini`, documented by [`config.example.ini`](config.example.ini). Edits apply on save; an invalid file keeps the previous settings and shows the error.

The weather, on with `[Weather] enabled`, comes from [Open-Meteo](https://open-meteo.com/) for `[Weather] location`, or, left empty, for where [ipinfo.io](https://ipinfo.io/) places your IP address. Click the place in the weather panel's header to change it. Units follow your locale's measurement system.

## Launcher

`speshell launcher [open|close|toggle]`

| Input | Result |
|---|---|
| text | Apps by name, initials, or fuzzy match; a web search if nothing matches |
| `2 * (8 + 4)`, `= sqrt(144)` | Calculator; Enter copies the result |
| `!yt query` | A bang from `[Launcher.Bangs]` |
| `? query` | Search with `[Launcher] searchUrl` |
| `!theme`, `!wall` | Pick a theme or wallpaper |
| `!mirror` | Mirror the displays, or extend them again |

Unknown bangs go to the search engine, so its own bangs work too.

## Tools

The **Tools** panel sets up timers and runs each tool whose programs are installed; the others don't show. Areas are picked with a selection in the theme's colors, and results arrive as toasts. A tool run from the panel closes it first; run from a keybinding, it leaves an open panel on screen, so a screenshot can show it.

Its Timer row puts a new timer in the bar and opens it there: name it if you like, then pick a preset, or type a length like `25`, `1h30`, or `90s`, or an end time like `at 21:30`. Each timer stays in the bar until it ends, when a notification arrives even through Do Not Disturb. Click one to rename it, add 1, 5, or 10 minutes, pause, or stop it; scroll over it to change it by a minute, and right-click to pause or resume. `speshell timer` starts and controls timers too, acting on the one that ends first when given no name.

| Tool | Does | Needs |
|---|---|---|
| Dictation | Records until run again, then types and copies what you said | `pipewire`, `whisper.cpp`, `wtype`, `wl-clipboard`, `curl` (model download) |
| Copy text | Copies the text in an area | `grim`, `slurp`, `tesseract` and a `tesseract-data-*` per language, `wl-clipboard` |
| Screenshot | Saves an area or the screen to Pictures/Screenshots and copies it; Annotate opens it in Swappy | `grim`, `slurp`, `wl-clipboard`, optionally `swappy` |
| Record | Records an area or the screen, with sound, to Videos/Recordings until run again | `wf-recorder`, `slurp` |
| Scan code | Copies a QR code or barcode, offering to open links | `grim`, `slurp`, `zbar`, `wl-clipboard` |
| Pick color | Copies a pixel's hex color | `hyprpicker`, `wl-clipboard` |

`[Tools]` in the config sets the OCR and dictation languages, dictation vocabulary, and Whisper model. Bind them with `speshell tool`:

```lua
hl.bind("SUPER + D", hl.dsp.exec_cmd("speshell tool dictate"))
hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("speshell tool dictate cancel"))
hl.bind("Print", hl.dsp.exec_cmd("speshell tool screenshot"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("speshell tool ocr"))
hl.bind("SUPER + R", hl.dsp.exec_cmd("speshell tool record"))
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("speshell tool record screen"))
```

## Themes

Speshell ships Cosmos (the default), four elements (Fire, Air, Water, and Earth), and Relâmpago, a racing theme. Each has a palette, a wallpaper, launcher and wallpaper effects, a still painted backdrop behind the bar and its panels, themed slider and switch knobs with small effects as you use them, and a clock face (see [extras/](extras/README.md)). Pick one in Settings › Appearance or with `!theme`.

Set `drawWallpaper = true` under `[Appearance]` to let Speshell draw the desktop background. It is off by default so another wallpaper tool can stay in charge. `launcherTransitionSpeed`, `wallpaperTransitionSpeed`, and `controlEffectsSpeed` (0–3, default 1) speed up or slow down each kind of effect, and 0 turns it off. `[Power] mode` sets their frame rate: `maximum` animates at the display's refresh rate, `balanced` (the default) at 60 fps, and `saver` turns the effects off along with the interface's own motion. `shuffleAtLaunch` picks at random each time Speshell starts: `wallpaper` (another wallpaper of the theme), `theme` (another theme), or `both`; the default is `off`. Settings › Appearance sets all of these.

Each theme remembers the wallpaper last set for it, so switching back to a theme brings that wallpaper back; a theme you have not picked a wallpaper for starts with its first.

A theme is a folder with an optional `theme.ini` and any images. Add your own under `~/.config/speshell/themes`; a folder named after a shipped theme adds wallpapers to it, and its `theme.ini` replaces the shipped one.

```ini
# ~/.config/speshell/themes/sunset/theme.ini
[Theme]
name = Sunset
effects = fire

[Colors]
base = #1d1315
text = #f3e3d3
accent = #f0702f
```

Colors use the keys of [`extras/themes/cosmos/theme.ini`](extras/themes/cosmos/theme.ini); missing ones come from Cosmos. Custom effects go in `~/.local/share/speshell/effects` (see [extras/effects](extras/effects/README.md)).

### App themes

Other apps can follow the theme. Speshell writes the active palette to `~/.local/share/speshell/palette.json` in [matugen](https://github.com/InioX/matugen)'s JSON format and, when it changes, sets GTK's `color-scheme` to the theme's light or dark and runs `matugen json` on it if `~/.config/matugen/config.toml` exists. matugen renders the templates listed there and runs their hooks, so which apps follow, and how they reload, is up to that config. If matugen fails, a notification shows its error.

Templates see each color under Speshell's names (`{{colors.accent.default.hex}}`, `colors.base`, `colors.surface0`, …), under the Material names matugen templates use (`colors.primary`, `colors.surface_container`, `colors.on_surface`, …), and as base16 (`{{base16.base0d.default.hex}}`), so templates written for matugen work as they are. Each hue also comes as tints over `base` for apps without transparency: `colors.green_15`, `green_30`, and `green_50` are green at that percent. `{{mode}}` is `dark` or `light`, from the theme's `base` color.

The file is rewritten only when the palette changes, so restarting Speshell leaves the apps alone. After editing the matugen config, run `matugen json ~/.local/share/speshell/palette.json` to render it.

## CLI

```bash
speshell launcher [open|close|toggle]
speshell panel list | open NAME | toggle NAME | close
speshell theme list | get | set ID | shuffle [ID] | rescan
speshell wallpaper get | set PATH
speshell tool list | dictate [cancel] | ocr | screenshot [region|screen] | record [region|screen] | qr | color
speshell timer get | start LENGTH [NAME] | add LENGTH [NAME] | pause|resume|toggle|stop [NAME]
speshell activity set ID STATE LABEL [DETAIL] [ICON] [TONE]
speshell activity list | clear ID | refresh
```

## Development

```bash
just lint test
just shaders   # compile effect shaders; needed once in a checkout
just shot fire # the bar in a theme with each panel open, offscreen, and a contact sheet
```

`bin/speshell` run from a checkout uses that checkout. Hardware behavior is checked by hand with [`tests/manual.md`](tests/manual.md); agent notes are in [AGENTS.md](AGENTS.md).

Icons are a subset of [Tabler Icons](https://github.com/tabler/tabler-icons) (MIT), in `assets/icons/tabler/`, and a few of Speshell's own in their style, in `assets/icons/speshell/`.
