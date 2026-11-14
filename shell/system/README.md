# System

`speshell system` keeps a machine as its modules declare it: its packages, services, groups, files, and the commands that set it up. The modules are plain text, for a hand or an agent to change. `speshell-system` here is the command, which `speshell system COMMAND` runs: a Python program that reads pacman's database through pyalpm. `!apply` and `!update` in the launcher run its `apply` and `update` in a terminal.

## The files

```
~/.config/speshell/system/
  nave.conf          this machine, named after its hostname
  base.conf
  hyprland.conf
  code.conf
  files/
    base/            what base.conf places, and what its commands read
    hyprland/
```

A module is a `.conf` file, and the files it places are in `files/` under its name; a module that places none has no folder. A machine applies the module named after its hostname, in any case, and that module's `use` lines bring in the others, so one directory serves every machine.

## A module

```
use base hyprland code

linux-cachyos
paru                      # AUR helper
service nftables
user-service orca-serve.service
group docker
linger
file ~/.bashrc
file ~/.config/hypr
file /etc/greetd/config.toml greetd.toml
file /etc/NetworkManager/system-connections/home.nmconnection 600
on /etc/nftables*: nft -f /etc/nftables.conf
run rustup default stable
```

- `use MODULE...` brings in other modules, and the ones they use.
- A bare name is a package, from the repositories or the AUR (installed through paru or yay when there is one). A group is not a package: list its packages.
- `service UNIT` enables a system unit, and `user-service UNIT` one of yours. `%u` in UNIT is your user name, as in `speshell-greeter-theme@%u.path`.
- `group GROUP` puts you in GROUP, from your next login.
- `linger` starts your user services at boot, without a login.
- `file PATH [NAME] [MODE]` places the module's file NAME at PATH. NAME is PATH's own name without a leading dot unless given, so `file ~/.bashrc` places `bashrc`; one file can go to several paths. A directory places each file in it, under PATH.
- `on PATH: COMMAND` runs COMMAND once after an apply changes a file whose path matches: as root for a path under `/`, as you for one under `~/`.
- `run COMMAND` runs COMMAND once on each machine, and again when the line changes.
- `#` starts a comment.

A file under `~/` is linked, so editing either one edits the module. One under `/` is copied as root, since `/etc` and the login screen can't read your home: mode 644, 755 when the module's file is executable, and 440 under `/etc/sudoers.d`, unless the line gives MODE. A sudoers file visudo rejects never goes in, so a typo can't lock sudo out.

`on` lines hear the files of every module the machine uses, so a module can drop a file into another's directory, a firewall rule into `/etc/nftables.d`, say, and the `on` line that reloads the firewall hears it. Their paths are globs, and their `*` matches across `/` too.

A `run` line is for what no other line can say, since what it does stays when the module goes. It runs as you, from the module's folder in `files/` when it has one, so it can run a script kept there, and it may ask on the terminal. One that fails stops the apply, and runs again on the next.

## What apply does

`speshell system` shows what differs and what `apply` would do; `apply` does it, taking what leaves before what comes:

1. Disables the services the last apply enabled that no module has anymore, takes you out of the groups it put you in that no module has, and stops starting your services at boot when no module asks for it.
2. Removes what no module declares anymore, then installs what they do. A package declared at the last apply and no longer is removed with what only it needed, or kept as a dependency when another package needs it; removing first lets a package replace one that leaves (`pipewire-jack` for `jack2`). Declared packages are marked explicitly installed.
3. Places the files: links what isn't linked, copies what differs, and takes away what the last apply placed and no module has anymore. A file in your home that differs from its module's isn't touched; `adopt` takes it into the module, and `restore` links it again, keeping the replaced file under `~/.local/share/speshell/system/replaced/`.
4. Runs the `on` commands of the files that changed, after reloading systemd when a unit file changed.
5. Puts you in the modules' groups, starts your services at boot when a module asks, and enables the services that aren't enabled.
6. Runs the `run` lines this machine hasn't.

One apply or update runs at a time. `update` updates the whole system and then applies. Packages installed but never declared are only reported: declare them, or remove them with `apply --remove PACKAGE`.

`apply` and `update` ask as pacman, paru, and sudo always do, so they run in a terminal. What the last apply left is in `~/.local/share/speshell/system/state.json`.

## Commands

```
speshell system [status [--remove PACKAGE]...]   what differs, and what apply would do
speshell system apply [--yes] [--hold] [--remove PACKAGE]...
speshell system update [--yes] [--hold]
speshell system add MODULE PACKAGE...
speshell system remove PACKAGE...
speshell system enable MODULE | disable MODULE  on this machine's use lines
speshell system adopt FILE | restore FILE
speshell system init                            this machine's module, from what it has
```

`--yes` skips the question before applying, and `--hold` waits for Enter before the terminal closes.
