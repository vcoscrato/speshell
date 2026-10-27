Validation before handing changes back ONLY WHEN NEEDED:

```bash
just lint test
git diff --check
timeout 5s quickshell --no-color -p shell
```

`quickshell --reload` is not available in QuickShell v0.3. Use Relaunch in the Power panel's header, or restart the process.

## Layout

- `shell/` is Speshell, installed as is to `/usr/share/speshell`: the QML Quickshell loads, the scripts it runs, its two commands, its icons, and the themes and effects it ships with their shader sources. `/usr/bin/speshell` and `speshell-greeter` link into it.
- `tests/` holds the QML unit tests, run by `just test`.
- `preview/` renders Speshell offscreen for local work: the scenes behind `just preview`, `check`, `bench`, and `paint`, and the real bar for `just shot`. Nothing in it ships. `preview/README.md` explains the recipes.
- `packaging/` holds the `PKGBUILD` and what it installs outside `/usr/share/speshell`: the desktop entry, the units that copy a user's theme for the login screen, and its tmpfiles.

## Architecture

Paths below are under `shell/`.

- `shell.qml` starts strict config loading, binds the theme to the active palette and text scale, creates the services that act on their own (idle, battery, lid), and gates either `Runtime` or `ConfigErrorWindow`. The lock screen and the polkit agent sit outside that gate, so they work with an invalid config.
- `core/` composes the runtime (IPC, notification server) and holds the launcher, wallpaper, OSD, toast, and config-error windows, the lock screen and the polkit prompt, and `Gate`, the view the lock and login screens share.
- `speshell` is the CLI over the IPC targets in `core/Runtime.qml`; it runs the shell it sits in, so from a checkout it runs that checkout's.
- `greeter.qml` is the login screen, a second shell in the same tree that `greeter/speshell-greeter` runs for greetd in the Hyprland of `greeter/hyprland.lua`; `greeter/speshell-greeter-theme` is the root helper that copies a user's theme to `/var/lib/speshell`. It reads no config.ini and can't read the user's home.
- `bar/` is the bar on each screen: its buttons, the workspaces, the media controls, the tray, and the dropdown that hosts one panel at a time.
- `panels/` holds the panels the bar opens, one `<Name>Panel.qml` each and the parts they share. There is no Settings panel: options live in config.ini, and a panel writes one only where it changes state there (weather location, night light, power mode).
- `services/` holds singleton system integrations and shared state, `Theme` (the default palette and the geometry and typography tokens) among them. `PanelService` knows the panels and opens them. Hyprland-only services (`HyprlandService`, `WorkspaceService`, `DisplayService`) gate on `HyprlandService.running`, so everything Hyprland-only degrades on other compositors. `WindowService` matches windows and apps hidden in the tray to desktop entries and brings an app forward, for the launcher and notification clicks.
- `components/` holds reusable QML UI primitives.
- `tools/` holds the capture and input tools `ToolsService` runs, and the `lib.sh` they share.
- `icons/` holds the pinned Tabler SVG subset (`tabler/`, with its license) and Speshell's own icons in its style (`speshell/`); `components/Icons.js` names them.
- `themes/` holds the shipped themes, each with the painting that renders its wallpaper (`themes/README.md` lists them and how to make one), and `effects/` their effects, with `effects/common/`, the library they share; `effects/README.md` is the effects API. Effect shaders compile with `just shaders`.

QML imports its modules as `qs.<dir>` (`import qs.services`); Quickshell generates their `qmldir`s, and `just lint` builds the same tree for qmllint and runs shellcheck over the scripts. JavaScript libraries are imported by relative path.

Prefer deleting unused QML modules over keeping broad helper surfaces. This repo should stay small and direct.

- Settings come from `ConfigService.settings`, shaped as config.ini's sections (`settings.bar.height`) and never null; each service reads its own. A new key goes in `Config.js`'s `build()` with its default, and nowhere else.
- Write text as `Label` with a `role` (body, title, caption, section, heading, display) rather than a bare `Text`; override size, weight, or color only when it means something. Times and lengths go through `components/Format.js`.
- Reuse the shared pieces: `Field` for text input, `ActionTile` for a toned tile that runs something, `DeviceRow` for a device or connection, `IconDisc` for a row's icon, `HeaderButton` for icon actions in a panel's header, `Tab`, `EmptyState`, and `SettingRow` with `SegmentedControl`, `SelectMenu`, or `ToggleSwitch`. Small popups use `Theme.popupFill`/`popupBorder`.
- Whether a command is installed is `FeatureSupport.hasCommand()`; add what a service needs to `wantedCommands`.
- Check UI changes with `just shot <theme> [panels…]`, which renders the real bar offscreen.
- Style through `Theme` tokens: spacing, control heights, icon sizes, radii, and interaction states (`controlFill`, `selectedFill`, `tint*`, `disabledOpacity`, `Theme.alpha()`). Add a token only when several components share the value.
- Laptop hardware goes through its own services: `BatteryService` (charge, warnings, health), `IdleService`, `SessionService` (logind's lid and sleep), `BrightnessService` (backlight and keyboard), `RadioService` (rfkill), and `InputService` (touchpad). Each gates on the hardware being there, so a desktop shows none of it. Changes from outside Speshell's panels go to `OsdService`.
- When UI changes system state, call a small domain service (for example `AudioService.stepOutputVolume()` or `BrightnessService.setPercent()`) instead of running processes or writing backend objects from panels.

## Packaging Notes

`packaging/PKGBUILD` uses the Git repository source, so plain `makepkg -si` in `packaging/` is for normal package installs. arch-config keeps a copy as `sources/PKGBUILD-speshell`, which dcli builds; change both together. Use `just local-package-install` when pacman must install a package built from the dirty checkout. It does not restart Speshell; a running one keeps the shaders it already loaded until restarted.

The package owns `/usr/share/speshell`, installed from `shell/`, and the `/usr/bin/speshell` and `speshell-greeter` links into it. User config and data live under:

- `~/.config/speshell/config.ini`
- `~/.local/share/speshell`

Package upgrades and removal should not overwrite those user files.
