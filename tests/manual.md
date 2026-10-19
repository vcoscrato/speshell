# Manual checks

What the unit tests can't reach: windows, devices, and the compositor. Run the checks
for the areas a change touches on a real session, after `just lint test`: on
Hyprland, and for anything outside the workspaces and Displays, on another
layer-shell compositor too.

## Bar

With `[Bar] position = top`, then `bottom`, each with `margin = 0` and `16`, on
every monitor:

- Tiled windows stay clear of the bar; fullscreen windows cover it. Toasts and the
  volume OSD stay clear of it too.
- The bar is framed on every side that doesn't touch the screen's edge: docked at
  full width only toward the windows, at 50 % on three sides, floating at 50 % on all
  four. At full width it spans the whole screen. With `outline = full`, the frame
  runs along the screen's edges too, as thick as elsewhere.
- Workspaces show this monitor's; clicking one shows it, and hovering one names its
  last focused window, current after a retitle. Off Hyprland, the workspaces and
  their separator don't show.
- The mark opens and closes the launcher and stays lit while it's open.
- Each panel button, the clock, the weather, each timer, and the track's
  cover open their panel under or over the button, kept on screen at either end, with the
  theme's backdrop, knobs, and control effects. A click outside, Escape, or the
  same button closes it; another button switches to its panel. Typing a Wi-Fi
  password works.
- Play/pause and the track's cover sit left of the clock, and the weather and the
  timers right of it; the clock doesn't move when any appears. Play/pause
  toggles without opening anything, the cover dims while paused, and hovering it
  names the track. Switching players, or pausing one while another plays, shows the
  playing one. At `width = 20` with music, the weather, and timers, the bar grows
  to fit and nothing overlaps.
- Scrolling over the speaker, microphone, or (with a backlight) display button
  changes it; right-clicking the speaker or microphone switches device. Tray menus
  and hover labels open toward the screen's middle and stay on screen.
- `speshell panel toggle clock` opens the clock panel on the focused monitor and
  closes it again; `speshell panel open display` without Hyprland fails with a
  message.

## Clock panel

- The face is the theme's: switch themes with it open. The second hand ticks into
  each second, and the hour and minute hands creep with the time. In power saver the
  face keeps still and shows no seconds.
- The month starts on the locale's first weekday, the wheel and the arrows change
  it, and Today comes back. Left open past midnight, today moves along.

## Weather

- With weather on, the bar shows its icon and temperature, and a moon after sunset.
  The panel shows the conditions now, the next hours, and the coming days. An unknown
  location says so in the panel, and its bar button stays to open it. Clicking the
  place in the panel's header changes the location: Enter saves, Escape cancels, and
  an empty field locates by IP address. Offline, it retries, and Try again works.
  Reopened after a long sleep, the panel refreshes it.

## Timer

- Timer in Tools puts a "New timer" in the bar's timer well and opens it there with
  the name field focused. A preset starts it under the typed name; so does a typed
  length or end time (`25`, `1h30`, `bread at 21:30`) with Enter or Start, which
  stays dimmed until the text is a length. Enter in the name field moves
  to the length field while it is empty. Starting closes the panel; Escape, a click outside, or
  another chip throws the unset timer away.
- Several timers sit side by side in creation order, each showing its name and time
  left, with a pause icon while paused. Opening one shows its name (click to edit;
  the chip follows as you type, "Add a name" when empty), the time left and when it
  ends, and a bar of the time left; paused, the time and bar grey out, "Paused"
  replaces the end time, and Resume turns accent. +1, +5, and +10 min, scrolling
  over the time, Pause/Resume, and the red Stop act on that timer only. Switching
  chips shows each timer's own name.
- Scrolling over a chip changes it by a minute, never below a second left;
  right-clicking pauses or resumes it.
- `!timer` is not a launcher bang; it searches like any unknown bang.
  `speshell timer start 1m tea`, `start at 7`, `add 1m tea`, `toggle`, `get` (a line
  each), and `stop tea` work; without a name they act on the timer that ends first.
- At the end, a notification titled with the timer's name appears even with Do Not
  Disturb on, and its chip goes; an open panel on it closes.

## Launcher

- `speshell launcher open|close|toggle` works on each monitor.
- Apps, the calculator, your own bangs, `!theme`, `!wall`, `!mirror`, and web search
  all work with mouse and keyboard. **Tab** completes a bang, and `vsc` finds Visual
  Studio Code.
- A `Terminal=true` app such as `btop` opens in a terminal.
- The search field stays where it is while typing changes the results, from many to
  one to none.
- Launch counts still order the results after a relaunch.
- With a launcher transition, typing works during the entrance. Closing with
  **Escape** or by launching an app plays the exit, clicks pass through during
  it, and reopening mid-exit works.

## Themes

- Switch themes with `!theme`, Settings › Appearance, and `speshell theme set ID`,
  including a theme without effects. Colors, wallpaper, the backdrop, the clock
  face, and transitions follow, and the old launcher exit finishes.
- After a relaunch, the chosen theme's colors are there from the first frame.
- Toasts, the volume OSD, and the config error window show the theme's backdrop,
  as the bar and its dropdowns do; a hovered toast still lightens.
- Tooltips, dropdown menus (Settings, Displays), a tray app's right-click menu
  with its submenus, scrollbars, and selected text all draw in the theme's
  colors, and so do the effects of a theme that borrows another theme's effects.
- A wallpaper added under `~/.config/speshell/themes/<shipped theme>/` joins
  that theme.
- A bad color in `theme.ini` or a broken `Effects.qml` raises a notification, and
  the launcher still opens.
- With **Draw wallpaper** off, the background is left alone and `!wall` isn't
  offered. Toggling it in Settings › Appearance adds and removes the background.

## Displays

- Apply a change and press **Keep Changes**: it stays.
- Apply a change and wait 15 s: it reverts, both with the panel open and closed.
- Apply a change and press **Revert**: it reverts at once.
- Unplug a monitor during the countdown: the displays still connected roll back.
- When a rollback fails, **Retry Revert** stays available.
- `!mirror` mirrors the displays and opens the Displays panel to keep it, and
  running it again extends them. Both Hyprland config syntaxes apply changes.
- Brightness controls the configured or auto-detected backlight.

## Settings and config

- Changing a toggle, a choice or a dropdown applies at once and flashes **Saved**.
- A panel whose content grows or shrinks while open (a Settings page, a Wi-Fi scan,
  a notification expanding) resizes smoothly; opening or switching panels shows
  each at its size at once.
- At 150 % text size, the bar's dropdowns widen, wide controls move under their
  labels, and tooltips stay on screen.
- Editing `config.ini` in an editor applies on save without Reload. An invalid
  edit keeps the old settings and shows the error in Settings. A later change in
  Settings keeps your edits in the file.
- An invalid `config.ini` at launch opens the error window and leaves the file
  untouched.
- **Edit** in About opens the config, with and without `$EDITOR` set.

## Notes

- Create, edit, switch, delete, undo and permanently delete notes.
- Editing the open note in another editor shows the new text, or a warning if
  there are unsaved edits.
- Relaunching right after typing loses nothing.

## Audio, network, Bluetooth, clipboard

- Volume, mute, device choice and quick switch work for output and input.
- Volume keys show the OSD on the focused monitor, merge repeated presses, and
  never take focus. Changes from Speshell's own slider or the bar's wheel don't
  show it.
- Network and Bluetooth only scan after refresh and stop scanning when you leave
  the panel. Connect and disconnect devices, including a secured network and a
  wrong password.
- VPN and WireGuard profiles connect and disconnect from the Network panel. A
  login's questions show on the profile's row, and a failed saved password can be
  typed again.
- Clipboard history lists, selects and clears entries. Without `cliphist` or
  `wl-clipboard`, the panel explains what's missing.

## Notifications and activity

- Transient, persistent, actionable, resident and critical notifications follow
  DND, expiry, dismissal and the toast limit. DND survives a relaunch, and
  critical notifications still show while it's on.
- `notify-send -p`, then `notify-send -r <id>`, updates the toast and history
  in place.
- Toasts open on the focused monitor. Long bodies and unbroken strings wrap, and
  the expanded list scrolls.
- `speshell activity set test active Test` shows a Test chip with its running
  time in the bar's well beside the timers, on every monitor, and
  `speshell activity clear test` removes it; the well goes when it's empty.
  Running `wf-recorder` shows a red Recording chip, and clicking it stops it.
- `speshell tool dictate` shows a Dictation chip with the microphone and, run
  again, a spinning one without delay, then types the text into the focused
  window; hovering it says which. Clicking the chip while it listens types it out
  too; right-clicking it and `speshell tool dictate cancel` drop it without typing.
- Nothing floats over the windows while dictating or recording.

## Tools

- The panel lists only installed tools; one installed while Speshell runs appears
  the next time the panel opens.
- A tool run from the Tools panel closes it before it selects or captures, so it
  doesn't show in the result. Run from a keybinding (`speshell tool screenshot`)
  with a panel open, the panel stays and shows in the screenshot; dictation still
  closes it, so it types into the window. The selection uses the theme's accent.
- Copy text, Scan code, Screenshot (area and screen) and Pick color copy their
  result and toast it; cancelling the selection does nothing. A screen screenshot
  or recording takes the focused monitor. Screenshot's Annotate opens Swappy, and a
  link's Open opens the browser.
- Record shows in the panel with its time and in the bar's chip; a click on
  either, or `speshell tool record`, saves it and toasts Open.
- `speshell tool ocr` without tesseract toasts what to install.

## Power

- Lock works. Other power actions arm on the first click (a double-click only arms
  them) and disarm when the countdown runs out. Log out ends the session on
  Hyprland and elsewhere.

## Missing tools

- A missing backlight or a missing locker each show in one warning after launch and
  in Settings › About.
- A desktop without a battery or the optional tools shows no startup warning.
