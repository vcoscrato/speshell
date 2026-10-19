Validation before handing changes back ONLY WHEN NEEDED:

```bash
just lint test
git diff --check
timeout 5s quickshell --no-color -p .
```

`quickshell --reload` is not available in QuickShell v0.3. Use Reload (config) or Relaunch in Settings › About, or restart the process.

## Architecture

- `shell.qml` starts strict config loading, binds the theme to the active palette and text scale, and gates either `Runtime` or `ConfigErrorWindow`.
- `core/` composes the runtime (IPC, notification server) and holds the launcher, wallpaper, OSD, toast, and config-error windows.
- `bar/` is the bar on each screen: its buttons, the workspaces, the media controls, the tray, and the dropdown that hosts one panel at a time.
- `panels/` holds the panels the bar opens, one `<Name>Panel.qml` each and the parts they share; `panels/settings/` holds the Settings pages.
- `services/` holds singleton system integrations and shared state. `PanelService` knows the panels and opens them. Hyprland-only services (`HyprlandService`, `WorkspaceService`, `DisplayService`) gate on `HyprlandService.running`, so everything Hyprland-only degrades on other compositors.
- `components/` holds reusable QML UI primitives; `theme/` the default palette and geometry/typography tokens.
- `assets/icons/` holds the pinned Tabler SVG subset (`tabler/`, with its license) and Speshell's own icons in its style (`speshell/`); `components/Icons.js` names them.
- `extras/` contains the shipped `themes/`, `effects/`, and shared `lib/`, plus the unshipped `paintings/` (shaders that render the theme wallpapers) and `lab/` (offscreen harness). `extras/README.md` maps who edits what; `extras/effects/README.md` is the effects API. Shaders compile with `just shaders`.

QML imports its modules as `qs.<dir>` (`import qs.services`); Quickshell generates their `qmldir`s, and `just lint` builds the same tree for qmllint. JavaScript libraries are imported by relative path.

Prefer deleting unused QML modules over keeping broad helper surfaces. This repo should stay small and direct.

- Settings come from `ConfigService.settings`, shaped as config.ini's sections (`settings.bar.height`) and never null; each service reads its own. A new key goes in `Config.js`'s `build()` with its default, and nowhere else.
- Write text as `Label` with a `role` (body, title, caption, section, heading, display) rather than a bare `Text`; override size, weight, or color only when it means something. Times and lengths go through `components/Format.js`.
- Reuse the shared pieces: `Field` for text input, `ActionTile` for a toned tile that runs something, `DeviceRow` for a device or connection, `IconDisc` for a row's icon, `HeaderButton` for icon actions in a panel's header, `Tab`, `EmptyState`, and `SettingRow` with `SegmentedControl`, `SelectMenu`, or `ToggleSwitch`. Small popups use `Theme.popupFill`/`popupBorder`.
- Whether a command is installed is `FeatureSupport.hasCommand()`; add what a service needs to `wantedCommands`.
- Check UI changes with `just shot <theme> [panels…]`, which renders the real bar offscreen.
- Style through `Theme` tokens: spacing, control heights, icon sizes, radii, and interaction states (`controlFill`, `selectedFill`, `tint*`, `disabledOpacity`, `Theme.alpha()`). Add a token only when several components share the value.
- When UI changes system state, call a small domain service (for example `AudioService.stepOutputVolume()` or `BrightnessService.setPercent()`) instead of running processes or writing backend objects from panels.

## Packaging Notes

The Arch `PKGBUILD` uses the Git repository source, so plain `makepkg -si` is for normal package installs. Use `just local-package-install` when pacman must install a package built from the dirty checkout. It does not restart Speshell; a running one keeps the shaders it already loaded until restarted.

The package owns `/usr/share/speshell` and `/usr/bin/speshell`, which is installed from `bin/speshell`. User config and data live under:

- `~/.config/speshell/config.ini`
- `~/.local/share/speshell`

Package upgrades and removal should not overwrite those user files.
