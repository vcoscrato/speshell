.pragma library

// The local path of a file:// URL.
function localPath(url) {
    return decodeURIComponent(String(url).replace(/^file:\/\//, ""));
}

// The command that runs the script `name` beside this file (one of the services'
// *.sh) with `args`.
function script(name, args) {
    return [localPath(Qt.resolvedUrl(name))].concat(args || []);
}

// The command that runs `argv` in the user's terminal emulator; it exits 127 when
// there is none.
function terminalCommand(argv) {
    return script("terminal.sh", argv);
}

// The command that opens `path` in $VISUAL or $EDITOR inside a terminal, or in the
// desktop's default application without an editor or terminal.
function editFileCommand(path) {
    return script("terminal.sh", ["--edit", String(path || "")]);
}
