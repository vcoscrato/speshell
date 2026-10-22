#!/bin/sh
# usage: lab/bench.sh [-a REF] [-r RUNS] [-p PHASES] [-m] [EFFECT...]
#
# Measures the GPU time per frame of one 1080p instance of each effect (all of them by
# default), phase by phase, and prints a table:
#   open       the launcher standing open
#   motion     the launcher's exit and entrance (a second entrance, past shader compiles)
#   wallpaper  the wallpaper transition
#   controls   the controls scene, its backdrop included, while effects play
#   clock      the clock scene, a face at the panel's size and one at twice it
#
# Each phase renders many copies of its scene into offscreen 1080p layers every frame,
# so the GPU, not vsync, sets the frame time. The cost of one copy is the slope between
# N and 2N copies, with N doubled until both are clearly GPU-bound; each frame time is
# the mean of the middle half of its frames. Every phase is measured RUNS times (3), and
# the table gives the median with the spread of the runs. A run still under vsync at
# 128 copies gives only an upper bound, and one where 2N copies ran barely slower than N
# (the GPU's clocks changed between them) is dropped; a phase with too few good runs
# shows its tightest bound, or "noisy".
#
# On NVIDIA it also notes how often the GPU slowed down for heat, which makes runs on a
# hot laptop slow and uneven: compare against a ref then, rather than trusting the ms.
#
#   -a REF     also measure git REF (e.g. HEAD), run for run with the checkout, and show
#              the change; it counts only where the two spreads do not overlap
#   -r RUNS    runs per phase
#   -p PHASES  comma-separated phases to measure (default: all)
#   -m         also print the README's Cost table, in Markdown
#
# On a laptop with NVIDIA graphics it renders on the NVIDIA GPU; BENCH_GPU=default leaves
# the choice to the system. Progress goes to stderr.
set -e
SMI=""
LAB=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$LAB/../.." && pwd)
LAB_OUT=${LAB_OUT:-${XDG_CACHE_HOME:-$HOME/.cache}/speshell-lab}
SAMPLES="$LAB_OUT/samples"
BUDGET=0.5
MAX_COPIES=64

REF=""
RUNS=3
PHASES="open,motion,wallpaper,controls,clock"
MARKDOWN=""
while getopts a:r:p:m opt; do
    case $opt in
        a) REF=$OPTARG ;;
        r) RUNS=$OPTARG ;;
        p) PHASES=$OPTARG ;;
        m) MARKDOWN=1 ;;
        *) sed -n '2,/^set -e/p' "$0" | sed '$d; s/^# \{0,1\}//' >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
EFFECTS=${*:-$(cd "$LAB/../effects" && for d in */; do [ -f "$d/Effects.qml" ] && printf '%s ' "${d%/}"; done)}
PHASES=$(echo "$PHASES" | tr , ' ')

[ -f "$SAMPLES/a.jpg" ] || { echo "bench: run just preview once first, to make the sample wallpapers" >&2; exit 1; }

if [ "${BENCH_GPU:-}" != default ] && [ -f /usr/share/glvnd/egl_vendor.d/10_nvidia.json ] \
        && nvidia-smi -L >/dev/null 2>&1; then
    SMI=1
    export __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia \
        __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# The trees measured: this checkout, and REF built beside it.
TREES="$ROOT"
if [ -n "$REF" ]; then
    git -C "$ROOT" rev-parse --verify --quiet "$REF^{commit}" >/dev/null || { echo "bench: no commit $REF" >&2; exit 1; }
    mkdir "$WORK/ref"
    git -C "$ROOT" archive "$REF" | tar -x -C "$WORK/ref"
    echo "bench: compiling the shaders of $REF" >&2
    (cd "$WORK/ref" && just shaders >/dev/null)
    TREES="$ROOT $WORK/ref"
fi

# Each phase: its scene, the scene's settings, the windows of lab time measured, and
# when the run ends.
phase() {
    case $1 in
        open) echo "launcher|CLOSE_AT=2.2|1.3-2.15|2.15" ;;
        motion) echo "launcher|CLOSE_AT=2.2 REOPEN_AT=3.3|2.2-2.8,3.3-4.4|4.4" ;;
        wallpaper) echo "wallpaper|SWITCH_AT=1.0|1.05-2.2|2.2" ;;
        controls) echo "controls||0.3-4.4|4.4" ;;
        clock) echo "clock||0.5-3.0|3.0" ;;
        *) echo "bench: unknown phase $1" >&2; exit 2 ;;
    esac
}

# measure TREE EFFECT PHASE COPIES [ENV...]: the frame time in ms, or nothing on failure.
measure() {
    tree=$1 effect=$2 copies=$4
    spec=$(phase "$3")
    scene=${spec%%|*}; rest=${spec#*|}
    settings=${rest%%|*}; rest=${rest#*|}
    windows=${rest%%|*}; duration=${rest#*|}
    shift 4
    env $settings "$@" EFFECTS_DIR="$tree/extras/effects/$effect" THEME_INI="$tree/extras/themes/$effect/theme.ini" \
        SCENE="$LAB/PerfScene.qml" INNER="$LAB/$(echo "$scene" | sed 's/./\U&/')Scene.qml" COPIES="$copies" \
        PERF="$windows" DURATION="$duration" OUT=/dev/null WALL_A="$SAMPLES/a.jpg" WALL_B="$SAMPLES/b.jpg" \
        SPESHELL_DIR="$tree" QT_FORCE_STDERR_LOGGING=1 \
        timeout 300 quickshell --no-color -p "$LAB/shell.qml" 2>&1 \
        | tee "$WORK/last.log" | sed -n 's/.*perf: \([0-9.]*\) ms.*/\1/p' | tail -1
    # How hot the GPU ran: its temperature, and whether it was slowing down for heat.
    [ -z "$SMI" ] || nvidia-smi --format=csv,noheader,nounits --query-gpu=temperature.gpu,$(
        )clocks_event_reasons.sw_thermal_slowdown,clocks_event_reasons.hw_thermal_slowdown,$(
        )clocks_event_reasons.hw_power_brake_slowdown >>"$WORK/heat" 2>/dev/null || true
}

# One copy of a light scene runs at the display's pace; the renderer is Qt's own report.
first=${EFFECTS%% *}
PERIOD=$(measure "$ROOT" "$first" clock 1 QSG_INFO=1)
[ -n "$PERIOD" ] || { echo "bench: the lab did not run:" >&2; tail -5 "$WORK/last.log" >&2; exit 1; }
GPU=$(sed -n 's/.*OpenGL VENDOR:.* RENDERER: \(.*\) VERSION:.*/\1/p' "$WORK/last.log" | head -1)
GPU=${GPU:-unknown renderer}
BOUND=$(awk -v p="$PERIOD" 'BEGIN { print p * 1.5 }')
echo "bench: $GPU, a frame every $PERIOD ms at rest" >&2
: >"$WORK/heat"

# Results, one line each: effect phase tree median min max bounded(0/1)
: >"$WORK/results"
total=$(( $(echo $EFFECTS | wc -w) * $(echo $PHASES | wc -w) ))
done_count=0
for effect in $EFFECTS; do
    for ph in $PHASES; do
        done_count=$((done_count + 1))
        # Copies enough that this checkout's frame clearly waits on the GPU.
        n=8
        while :; do
            t=$(measure "$ROOT" "$effect" "$ph" $n)
            [ -n "$t" ] || { echo "bench: $effect $ph failed:" >&2; tail -5 "$WORK/last.log" >&2; exit 1; }
            awk -v t="$t" -v b="$BOUND" 'BEGIN { exit !(t < b) }' || break
            [ $n -lt $MAX_COPIES ] || break
            n=$((n * 2))
        done
        for run in $(seq "$RUNS"); do
            # Alternated, so drift in the GPU's clocks falls on both trees alike.
            order=$TREES
            [ $((run % 2)) -eq 0 ] && [ -n "$REF" ] && order="$WORK/ref $ROOT"
            for tree in $order; do
                a=$(measure "$tree" "$effect" "$ph" $n)
                b=$(measure "$tree" "$effect" "$ph" $((n * 2)))
                [ -n "$a" ] && [ -n "$b" ] || { echo "bench: $effect $ph failed:" >&2; tail -5 "$WORK/last.log" >&2; exit 1; }
                echo "$tree $a $b" >>"$WORK/runs-$effect-$ph"
            done
        done
        for tree in $TREES; do
            label=$([ "$tree" = "$ROOT" ] && echo now || echo ref)
            grep "^$tree " "$WORK/runs-$effect-$ph" | awk -v n=$n -v bound="$BOUND" -v e="$effect" -v ph="$ph" -v l="$label" '
                { a[NR] = $2; b[NR] = $3 }
                END {
                    # Each run: a slope, a bound (2N copies still fit in a frame), or
                    # dropped (2N barely slower than N, so the clocks moved between them).
                    ns = nb = 0
                    for (i = 1; i <= NR; i++) {
                        if (b[i] < bound) bd[++nb] = b[i] / (2 * n)
                        else if (b[i] > 1.3 * a[i]) sl[++ns] = (b[i] - a[i]) / n
                    }
                    if (2 * ns > NR) {
                        for (i = 1; i <= ns; i++) for (j = i + 1; j <= ns; j++) if (sl[j] < sl[i]) { t = sl[i]; sl[i] = sl[j]; sl[j] = t }
                        med = ns % 2 ? sl[(ns + 1) / 2] : (sl[ns / 2] + sl[ns / 2 + 1]) / 2
                        printf "%s %s %s %.3f %.3f %.3f 0\n", e, ph, l, med, sl[1], sl[ns]
                    } else if (nb > 0) {
                        m = bd[1]; for (i = 2; i <= nb; i++) if (bd[i] < m) m = bd[i]
                        printf "%s %s %s %.3f %.3f %.3f 1\n", e, ph, l, m, 0, m
                    } else
                        printf "%s %s %s 0 0 0 2\n", e, ph, l
                }' >>"$WORK/results"
        done
        printf 'bench: [%d/%d] %s %s: %s\n' "$done_count" "$total" "$effect" "$ph" \
            "$(awk -v e="$effect" -v p="$ph" '$1 == e && $2 == p && $3 == "now" { print ($7 == 2 ? "noisy" : ($7 ? "< " : "") $4 " ms") }' "$WORK/results")" >&2
    done
done

# The table: one row per effect and phase.
color=$([ -t 1 ] && echo 1 || echo 0)
heat=$(awk -F', ' '
    { n++; if ($1 > hot) hot = $1; if ($2 == "Active" || $3 == "Active" || $4 == "Active") slow++ }
    END { if (slow) printf "the GPU slowed down for heat in %d of %d runs, at up to %d °C", slow, n, hot }' "$WORK/heat")
awk -v gpu="$GPU" -v heat="$heat" -v runs="$RUNS" -v ref="$REF" -v budget="$BUDGET" -v color="$color" -v period="$PERIOD" '
    function paint(s, c) { return color ? "\033[" c "m" s "\033[0m" : s }
    # kind: 0 measured, 1 only bounded (under vsync), 2 too noisy to tell
    function cell(m, lo, hi, kind) {
        return kind == 2 ? "noisy" : kind ? sprintf("< %.2f", m) : sprintf("%.2f  %.2f-%.2f", m, lo, hi)
    }
    {
        key = $1 SUBSEP $2
        if (!(key in seen)) { seen[key] = 1; rows[++n] = key; eff[n] = $1; ph[n] = $2 }
        med[key, $3] = $4; lo[key, $3] = $5; hi[key, $3] = $6; kind[key, $3] = $7
    }
    END {
        printf "\n%s\n", paint("Speshell effects: GPU time per frame of one 1080p instance, in ms", "1")
        printf "%s, a frame every %.1f ms at rest; median of %d runs, then their spread\n", gpu, period, runs
        if (heat != "") printf "%s\n", paint("Warning: " heat "; the ms run high and uneven, so compare against a ref.", "33")
        printf "Budget: %s ms on an RTX 3070 (the README table). Other GPUs differ; compare against a ref.\n\n", budget
        if (ref == "") {
            printf "%-10s  %-10s  %-18s\n", "effect", "phase", "ms   spread"
            printf "%-10s  %-10s  %-18s\n", "──────────", "──────────", "──────────────────"
        } else {
            printf "%-10s  %-10s  %-18s  %-18s  %s\n", "effect", "phase", "now  spread", ref "  spread", "change"
            printf "%-10s  %-10s  %-18s  %-18s  %s\n", "──────────", "──────────", "──────────────────", "──────────────────", "──────────"
        }
        for (i = 1; i <= n; i++) {
            k = rows[i]
            now = cell(med[k, "now"], lo[k, "now"], hi[k, "now"], kind[k, "now"])
            line = sprintf("%-10s  %-10s  %-18s", (i > 1 && eff[i] == eff[i - 1]) ? "" : eff[i], ph[i], now)
            if (ref != "") {
                was = cell(med[k, "ref"], lo[k, "ref"], hi[k, "ref"], kind[k, "ref"])
                if (kind[k, "now"] == 1 && kind[k, "ref"] == 1)
                    change = "both under vsync"
                else if (kind[k, "now"] || kind[k, "ref"])
                    change = "unclear"
                else if (lo[k, "now"] > hi[k, "ref"])
                    change = paint(sprintf("+%.0f%%", 100 * (med[k, "now"] / (med[k, "ref"] > 0 ? med[k, "ref"] : 1e-9) - 1)), "31")
                else if (hi[k, "now"] < lo[k, "ref"])
                    change = paint(sprintf("%.0f%%", 100 * (med[k, "now"] / med[k, "ref"] - 1)), "32")
                else
                    change = "within noise"
                line = sprintf("%s  %-18s  %s", line, was, change)
            }
            print line
        }
        print ""
    }' "$WORK/results"

if [ -n "$MARKDOWN" ]; then
    awk -v phases="$PHASES" '
        function name(e) { return e == "relampago" ? "Relâmpago" : toupper(substr(e, 1, 1)) substr(e, 2) }
        function head(p) {
            return p == "open" ? "Launcher open" : p == "motion" ? "Launcher entrance and exit" \
                : p == "wallpaper" ? "Wallpaper" : p == "controls" ? "Controls" : "Clock face"
        }
        $3 == "now" { v[$1, $2] = $7 == 2 ? "noisy" : ($7 ? "under " : "") sprintf("%.2f", $4) " ms"; if (!($1 in seen)) { seen[$1] = 1; order[++ne] = $1 } }
        END {
            np = split(phases, ps, " ")
            line = "| Effects |"; rule = "|---|"
            for (j = 1; j <= np; j++) { line = line " " head(ps[j]) " |"; rule = rule "---|" }
            print line; print rule
            for (i = 1; i <= ne; i++) {
                line = "| " name(order[i]) " |"
                for (j = 1; j <= np; j++) line = line " " v[order[i], ps[j]] " |"
                print line
            }
        }' "$WORK/results"
    echo
fi
