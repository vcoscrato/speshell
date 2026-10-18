.pragma library

// Single-quotes a value for safe use inside an sh -c script.
function quote(value) {
    return "'" + String(value).replace(/'/g, "'\"'\"'") + "'";
}

// Shell function that runs "$@" in the user's terminal emulator. Returns 127
// when no terminal is found so callers can fall back.
var shellFunction = "speshell_terminal() { "
    + "if [ -n \"${TERMINAL:-}\" ] && command -v \"${TERMINAL%% *}\" >/dev/null 2>&1; then "
    + "exec $TERMINAL -e \"$@\"; fi; "
    + "if command -v xdg-terminal-exec >/dev/null 2>&1; then exec xdg-terminal-exec \"$@\"; fi; "
    + "for term in kitty foot ghostty alacritty wezterm konsole gnome-terminal xterm; do "
    + "command -v \"$term\" >/dev/null 2>&1 || continue; "
    + "case \"$term\" in "
    + "kitty|foot) exec \"$term\" \"$@\" ;; "
    + "wezterm) exec wezterm start -- \"$@\" ;; "
    + "gnome-terminal) exec gnome-terminal -- \"$@\" ;; "
    + "*) exec \"$term\" -e \"$@\" ;; "
    + "esac; done; "
    + "echo 'No terminal emulator found. Set $TERMINAL.' >&2; return 127; }; ";

function terminalCommand(argv) {
    return ["sh", "-c", shellFunction + "speshell_terminal \"$@\"", "speshell-terminal"]
        .concat(argv || []);
}

// Opens a file in $VISUAL or $EDITOR inside a terminal, falling back to the
// desktop's default application when no editor or terminal is available.
function editFileCommand(path) {
    return [
        "sh", "-c",
        shellFunction
            + "SPESHELL_EDITOR=\"${VISUAL:-${EDITOR:-}}\"; export SPESHELL_EDITOR; "
            + "if [ -n \"$SPESHELL_EDITOR\" ]; then "
            + "speshell_terminal sh -c 'exec $SPESHELL_EDITOR \"$1\"' speshell-editor \"$1\"; fi; "
            + "exec xdg-open \"$1\"",
        "speshell-open-config",
        String(path || "")
    ];
}
