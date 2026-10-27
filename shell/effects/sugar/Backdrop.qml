import QtQuick
import "Sugar.js" as Sugar

// Sugar backdrop: dark chocolate drizzled with cream, and
// a piped shell border of frosting along the bottom. Drawn once.
ShaderEffect {
    id: root

    // ── Speshell effects API v1: backdrop ────────────────────
    property var theme: null

    property size size: Qt.size(width, height)
    property color cBase: root.theme ? root.theme.bg : "#2a1c1a"
    property color cInk: Sugar.ink(root.theme)
    property color cCream: Sugar.cream(root.theme)
    property color cFrost: Sugar.frosting(root.theme)
    fragmentShader: Qt.resolvedUrl("qsb/Backdrop.qsb")
}
