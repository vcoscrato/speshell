# Prefer Qt 6 tools; on Arch, /usr/bin/qmllint may belong to Qt 5.
qt6_bin := shell('for d in /usr/lib/qt6/bin /usr/lib64/qt6/bin; do [ -d "$d" ] && echo "$d" && break; done; true')
qmllint := env("QMLLINT", if qt6_bin != "" { qt6_bin / "qmllint" } else { "qmllint" })
qmltestrunner := env("QMLTESTRUNNER", if qt6_bin != "" { qt6_bin / "qmltestrunner" } else { "qmltestrunner" })
qsb := env("QSB", if qt6_bin != "" { qt6_bin / "qsb" } else { "qsb" })

# The effects lab hosts this checkout's WallpaperView.
export SPESHELL_DIR := justfile_directory()
# Where the lab writes its renders.
export LAB_OUT := env("LAB_OUT", env("XDG_CACHE_HOME", env("HOME") / ".cache") / "speshell-lab")

[private]
default:
    @just --list

# QML module directories, imported as `qs.<dir>`.
modules := "bar components core panels services theme"

# Lint every QML module; any warning fails.
lint:
    #!/bin/sh
    set -e
    # Quickshell loads the shell through a module tree it generates, in which each
    # directory is the module `qs.<dir>`; qmllint lints the same tree, built here.
    tree=$(mktemp -d)
    trap 'rm -rf "$tree"' EXIT
    cp shell.qml "$tree/"
    for dir in {{ modules }}; do
        mkdir -p "$tree/$dir"
        for file in "$dir"/*.js; do
            [ -e "$file" ] && cp "$file" "$tree/$dir/"
        done
        {
            echo "module qs.$(echo "$dir" | tr / .)"
            for file in "$dir"/*.qml; do
                cp "$file" "$tree/$dir/"
                name=$(basename "$file" .qml)
                grep -q '^pragma Singleton' "$file" && echo "singleton $name 1.0 $name.qml" || echo "$name 1.0 $name.qml"
            done
        } > "$tree/$dir/qmldir"
    done
    mkdir "$tree/imports"
    ln -s "$tree" "$tree/imports/qs"
    # qmllint 6.12 reports some singletons that reference each other as missing from
    # their qmldir even though it declares them, and the warning can't be disabled.
    out=$(cd "$tree" && {{ qmllint }} -I "$tree/imports" shell.qml $(for dir in {{ modules }}; do echo "$dir"/*.qml; done) 2>&1 \
        | grep -v 'not declared as singleton in qmldir but using pragma Singleton' || true)
    [ -z "$out" ] || { printf '%s\n' "$out"; exit 1; }

# Run the QML unit tests.
test:
    QT_QPA_PLATFORM=offscreen QML_XHR_ALLOW_FILE_READ=1 {{ qmltestrunner }} -input tests

# Compile the effect and painting shaders that changed.
[working-directory: 'extras']
shaders:
    #!/bin/sh
    set -e
    for frag in effects/*/*.frag paintings/*.frag; do
        out="$(dirname "$frag")/qsb/$(basename "$frag" .frag).qsb"
        mkdir -p "$(dirname "$out")"
        if [ ! -f "$out" ] || [ "$frag" -nt "$out" ] || [ lib/common.glsl -nt "$out" ] \
                || [ paintings/landscape.glsl -nt "$out" ]; then
            echo "qsb $frag"
            {{ qsb }} --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$out" "$frag"
        fi
    done

# Render paintings/<name>.frag over each themes/*/<name>.jpg (else ~/.cache/speshell-lab/); no name: all (needs Wayland).
[working-directory: 'extras']
paint name="": shaders
    #!/bin/sh
    set -e
    name="{{ name }}"
    for frag in paintings/${name:-*}.frag; do
        [ -f "$frag" ] || { echo "no painting $frag" >&2; exit 1; }
        painting=$(basename "$frag" .frag)
        targets=$(ls themes/*/"$painting.jpg" 2>/dev/null || true)
        [ -n "$targets" ] || [ -z "$name" ] || targets="$LAB_OUT/$painting.jpg"
        for out in $targets; do
            echo "paint $painting -> $out"
            lab/paint.sh "$painting" "$out"
        done
    done

# Render an effect's scene offscreen into ~/.cache/speshell-lab/<effect>-<scene>.mp4 (needs a Wayland session).
[working-directory: 'extras']
preview effect="cosmos" scene="launcher": shaders
    lab/preview.sh "{{ effect }}" "{{ scene }}"

# Render every effect and scene; fail on QML errors, warnings, or a transition that never finishes.
[working-directory: 'extras']
check: shaders
    lab/check.sh $(cd effects && ls -d */ | tr -d /)

# Benchmark the effects' GPU time per frame at 1080p, phase by phase; see lab/bench.sh (needs Wayland).
[working-directory: 'extras']
bench *args: shaders
    lab/bench.sh {{ args }}

# Render the real bar in a theme with each panel open (all, or those named, or `launcher`) into ~/.cache/speshell-lab/shots/ (needs Wayland).
[working-directory: 'extras']
shot theme="cosmos" *shots: shaders
    lab/shot.sh "{{ theme }}" {{ shots }}

# Remove compiled shaders and lab output.
[working-directory: 'extras']
clean:
    rm -rf effects/*/qsb paintings/qsb "$LAB_OUT"

# Build and install a package from this checkout, uncommitted changes included.
local-package-install:
    #!/bin/sh
    set -e
    builddir=$(mktemp -d /tmp/speshell-local.XXXXXX)
    printf 'Building local package in %s\n' "$builddir"
    mkdir -p "$builddir/src/speshell"
    cp PKGBUILD "$builddir/"
    tar --exclude='./src' --exclude='./pkg' --exclude='./speshell' --exclude='./*.pkg.tar.*' \
        --exclude='qsb' \
        -cf - . | tar -C "$builddir/src/speshell" -xf -
    (cd "$builddir" && makepkg -efsi)
    echo "Installed. Restart Speshell to load new shaders."
