Validation before handing changes back ONLY WHEN NEEDED:

```bash
just lint test
git diff --check
timeout 5s quickshell --no-color -p .
```

`quickshell --reload` is not available in QuickShell v0.3. Use Reload (config) or Relaunch in Settings › About, or restart the process.

## Architecture

- `shell.qml` starts strict config loading, applies validated global settings, and gates either `Runtime` or `ConfigErrorWindow`.
- `core/` composes the runtime (IPC, notification server) and holds the launcher, wallpaper, OSD, toast, and config-error windows.
- `bar/` is the bar on each screen: its buttons, the workspaces, the media controls, the tray, and the dropdown that hosts one panel at a time.
- `panels/` holds the panels the bar opens, one `<Name>Panel.qml` each and the parts they share; `panels/settings/` holds the Settings pages.
- `services/` holds singleton system integrations and shared state. `PanelService` knows the panels and opens them; `HyprlandService` is the only way to Hyprland, so everything Hyprland-only degrades on other compositors.
- `components/` holds reusable QML UI primitives; `theme/` the default palette and geometry/typography tokens.
- `assets/icons/` holds the pinned Tabler SVG subset (`tabler/`, with its license) and Speshell's own icons in its style (`speshell/`); `components/Icons.js` names them.
- `extras/` contains the shipped `themes/`, `effects/`, and shared `lib/`, plus the unshipped `paintings/` (shaders that render the theme wallpapers) and `lab/` (offscreen harness). `extras/README.md` maps who edits what; `extras/effects/README.md` is the effects API. Shaders compile with `just shaders`.

QML imports its modules as `qs.<dir>` (`import qs.services`); Quickshell generates their `qmldir`s, and `just lint` builds the same tree for qmllint. JavaScript libraries are imported by relative path.

Prefer deleting unused QML modules over keeping broad helper surfaces. This repo should stay small and direct.

- Style through `Theme` tokens: spacing, control heights, icon sizes, radii, and interaction states (`controlFill`, `selectedFill`, `tint*`, `disabledOpacity`, `Theme.alpha()`). Add a token only when several components share the value.
- When UI changes system state, call a small domain service (for example `AudioService.stepOutputVolume()` or `BrightnessService.setPercent()`) instead of running processes or writing backend objects from panels.

## Packaging Notes

The Arch `PKGBUILD` uses the Git repository source, so plain `makepkg -si` is for normal package installs. Use `just local-package-install` when pacman must install a package built from the dirty checkout. It does not restart Speshell; a running one keeps the shaders it already loaded until restarted.

The package owns `/usr/share/speshell` and `/usr/bin/speshell`, which is installed from `bin/speshell`. User config and data live under:

- `~/.config/speshell/config.ini`
- `~/.local/share/speshell`

Package upgrades and removal should not overwrite those user files.
