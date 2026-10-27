# Prefer Qt 6 tools; on Arch, /usr/bin/qmllint may belong to Qt 5.
qt6_bin := shell('for d in /usr/lib/qt6/bin /usr/lib64/qt6/bin; do [ -d "$d" ] && echo "$d" && break; done; true')
qmllint := env("QMLLINT", if qt6_bin != "" { qt6_bin / "qmllint" } else { "qmllint" })
qmltestrunner := env("QMLTESTRUNNER", if qt6_bin != "" { qt6_bin / "qmltestrunner" } else { "qmltestrunner" })
qsb := env("QSB", if qt6_bin != "" { qt6_bin / "qsb" } else { "qsb" })

# The shell the preview scenes host, as this checkout's WallpaperView and bar.
export SPESHELL_DIR := justfile_directory() / "shell"
# Where previews, shots, and paintings' compiled shaders go.
export PREVIEW_OUT := env("PREVIEW_OUT", env("XDG_CACHE_HOME", env("HOME") / ".cache") / "speshell-preview")

[private]
default:
    @just --list

# QML module directories under shell/, imported as `qs.<dir>`.
modules := "bar components core panels services"

# Lint every shell script and QML module; any warning fails.
lint:
    #!/bin/sh
    set -e
    shellcheck -x -P SCRIPTDIR shell/speshell shell/greeter/speshell-greeter shell/greeter/speshell-greeter-theme shell/tools/* preview/*.sh
    # Quickshell loads the shell through a module tree it generates, in which each
    # directory is the module `qs.<dir>`; qmllint lints the same tree, built here.
    cd shell
    tree=$(mktemp -d)
    trap 'rm -rf "$tree"' EXIT
    cp shell.qml greeter.qml "$tree/"
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
    out=$(cd "$tree" && {{ qmllint }} -I "$tree/imports" shell.qml greeter.qml $(for dir in {{ modules }}; do echo "$dir"/*.qml; done) 2>&1 \
        | grep -v 'not declared as singleton in qmldir but using pragma Singleton' || true)
    [ -z "$out" ] || { printf '%s\n' "$out"; exit 1; }

# Run the QML unit tests.
test:
    QT_QPA_PLATFORM=offscreen QML_XHR_ALLOW_FILE_READ=1 {{ qmltestrunner }} -input tests

# Compile the effects' shaders that changed.
shaders:
    #!/bin/sh
    set -e
    for frag in shell/effects/*/*.frag; do
        out="$(dirname "$frag")/qsb/$(basename "$frag" .frag).qsb"
        mkdir -p "$(dirname "$out")"
        if [ ! -f "$out" ] || [ "$frag" -nt "$out" ] || [ shell/effects/common/common.glsl -nt "$out" ] \
                || [ -n "$(find "$(dirname "$frag")" -maxdepth 1 -name "*.glsl" -newer "$out")" ]; then
            echo "qsb $frag"
            {{ qsb }} --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$out" "$frag"
        fi
    done

# Render a theme's paintings, each <name>.frag in its folder, into the <name>.jpg beside it, at WIDTH x HEIGHT (3840x2160); no theme: every theme's (needs Wayland).
paint theme="":
    #!/bin/sh
    set -e
    theme="{{ theme }}"
    [ -z "$theme" ] || [ -d "shell/themes/$theme" ] || { echo "no theme $theme" >&2; exit 1; }
    frames=$(mktemp -d)
    trap 'rm -rf "$frames"' EXIT
    mkdir -p "$PREVIEW_OUT/paintings"
    for frag in shell/themes/${theme:-*}/*.frag; do
        [ -f "$frag" ] || continue
        painting=$(basename "$frag" .frag)
        out="${frag%.frag}.jpg"
        echo "paint $frag -> $out"
        {{ qsb }} --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$PREVIEW_OUT/paintings/$painting.qsb" "$frag"
        SCENE="$PWD/preview/scenes/PaintingScene.qml" PAINTING="$PREVIEW_OUT/paintings/$painting.qsb" DURATION=0.05 OUT="$frames" \
            QT_FORCE_STDERR_LOGGING=1 timeout 60 quickshell --no-color -p preview/scenes/shell.qml 2>&1 \
            | grep -E "rror|WARN" | grep -v "window masks" >&2 || true
        [ -f "$frames/0001.bmp" ] || { echo "paint: $frag did not render" >&2; exit 1; }
        magick "$frames/0001.bmp" -quality 92 "$out"
        rm -f "$frames"/*
    done

# Render an effect's scene offscreen into ~/.cache/speshell-preview/<effect>-<scene>.mp4 (needs a Wayland session).
preview effect="cosmos" scene="launcher": shaders
    preview/preview.sh "{{ effect }}" "{{ scene }}"

# Render every effect and scene but picks; fail on QML errors, warnings, or a transition that never finishes.
check: shaders
    #!/bin/sh
    status=0
    for effect in $(cd shell/effects && for d in */; do [ -f "$d/Effects.qml" ] && echo "${d%/}"; done); do
        for scene in launcher wallpaper controls clock; do
            preview/preview.sh "$effect" "$scene" >/dev/null 2>&1
            log="$PREVIEW_OUT/$effect-$scene.log"
            problems=$(grep -E "rror|WARN" "$log" | grep -v "window masks")
            if [ -n "$problems" ]; then
                printf 'FAIL %s %s:\n%s\n' "$effect" "$scene" "$problems"
                status=1
            elif [ "$scene" = launcher ] || [ "$scene" = wallpaper ]; then
                if grep -qE "closingFinished|transition finished" "$log"; then
                    printf 'ok   %s %s, finished at %ss\n' "$effect" "$scene" \
                        "$(grep -oE '(closingFinished|finished) at [0-9.]+' "$log" | tail -1 | grep -oE '[0-9.]+$')"
                else
                    printf 'FAIL %s %s: the transition never finished\n' "$effect" "$scene"
                    status=1
                fi
            else
                printf 'ok   %s %s\n' "$effect" "$scene"
            fi
        done
    done
    exit $status

# Benchmark the effects' GPU time per frame at 1080p, phase by phase; see preview/bench.sh (needs Wayland).
bench *args: shaders
    preview/bench.sh {{ args }}

# Render the real bar in a theme with each panel open (all, or those named, or `launcher` or `themes`) into ~/.cache/speshell-preview/shots/ (needs Wayland).
shot theme="cosmos" *shots: shaders
    preview/shot.sh "{{ theme }}" {{ shots }}

# Remove compiled shaders and the previews' output.
clean:
    rm -rf shell/effects/*/qsb "$PREVIEW_OUT"

# Build and install a package from this checkout, uncommitted changes included.
local-package-install:
    #!/bin/sh
    set -e
    builddir=$(mktemp -d /tmp/speshell-local.XXXXXX)
    printf 'Building local package in %s\n' "$builddir"
    mkdir -p "$builddir/src/speshell"
    cp packaging/PKGBUILD "$builddir/"
    tar --exclude='./packaging/src' --exclude='./packaging/pkg' --exclude='./packaging/speshell' --exclude='./packaging/*.pkg.tar.*' \
        --exclude='qsb' \
        -cf - . | tar -C "$builddir/src/speshell" -xf -
    (cd "$builddir" && makepkg -efsi)
    echo "Installed. Restart Speshell to load new shaders."
