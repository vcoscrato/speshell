pragma ComponentBehavior: Bound
// Quickshell's type info marks PanelWindow uncreatable, though QML creates it.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.panels
import qs.services

// What OsdService shows at the bottom of the focused screen, over everything and never
// taking focus: a level, as with volume and brightness keys, in the same header and row
// as its panel, live and settable while the pointer is on it; or a state, as with
// airplane mode. present() pops the card in, dismiss() fades it out and then unmaps the
// window.
PanelWindow {
    id: root

    property bool shown: false
    property var targetScreen: null

    // OsdService's level, or "" for a state.
    property string level: ""
    property string stateIcon: "info"
    property string stateTitle: ""
    property string stateDetail: ""

    readonly property var levels: ({
        output: { panel: "audio", row: outputLevel },
        input: { panel: "microphone", row: inputLevel },
        brightness: { panel: "display", row: brightnessLevel },
        keyboard: { title: "Keyboard", icon: "keyboard", row: keyboardLevel }
    })
    readonly property var shownLevel: root.levels[root.level] ?? null

    function present() {
        // Called back while fading out: comes back from as far as it got.
        if (exitAnimation.running) {
            exitAnimation.stop();
            comeBack.restart();
        }
        if (root.shown)
            return;
        root.targetScreen = HyprlandService.focusedScreen();
        root.shown = true;
        entrance.play();
    }

    function dismiss() {
        comeBack.stop();
        if (root.shown)
            exitAnimation.restart();
    }

    screen: root.targetScreen
    visible: root.shown && root.targetScreen !== null
    color: "transparent"
    focusable: false
    aboveWindows: true
    // Clear of the bar, which reserves its edge.
    exclusionMode: ExclusionMode.Normal

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    implicitWidth: osdBody.implicitWidth + Theme.panelPadding * 2
    implicitHeight: osdBody.implicitHeight + Theme.panelPadding * 2

    anchors {
        bottom: true
    }

    // Quickshell's type info hides the fields of PanelWindow.margins.
    // qmllint disable missing-property
    margins {
        bottom: Theme.osdMargin
    }
    // qmllint enable missing-property

    WlrLayershell.namespace: "speshell-osd"

    Connections {
        target: OsdService

        function onRequested(level, iconName, title, detail) {
            root.targetScreen = HyprlandService.focusedScreen();
            root.level = level;
            root.stateIcon = iconName;
            root.stateTitle = title;
            root.stateDetail = detail;
            hideTimer.restart();
            root.present();
        }
    }

    Timer {
        id: hideTimer
        interval: Theme.osdTimeout
        repeat: false
        onTriggered: if (!hover.hovered) root.dismiss()
    }

    Component {
        id: outputLevel
        AudioLevel { endpoint: AudioService.output }
    }

    Component {
        id: inputLevel
        AudioLevel { endpoint: AudioService.input }
    }

    Component {
        id: brightnessLevel
        BrightnessLevel {}
    }

    // The keyboard has no panel; its row follows the brightness one.
    Component {
        id: keyboardLevel

        LevelRow {
            to: BrightnessService.keyboardMax
            stepSize: 1
            value: BrightnessService.keyboardLevel
            valueText: BrightnessService.keyboardLevel === 0 ? "Off" : BrightnessService.keyboardPercent + "%"
            progressColor: Theme.yellow
            onAdjusted: nextValue => BrightnessService.setKeyboardLevel(nextValue)

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "Backlight"
            }
        }
    }

    Component {
        id: stateRow

        DeviceRow {
            iconName: root.stateIcon
            title: root.stateTitle
            subtitle: root.stateDetail
            current: true
            primaryEnabled: false
        }
    }

    Item {
        id: osdCard
        anchors.fill: parent

        // Kept up while the pointer is on it, and for a moment after it leaves.
        HoverHandler {
            id: hover
            onHoveredChanged: if (!hovered) hideTimer.restart()
        }

        // Bottom center of the screen: rounded toward its center.
        Surface {
            anchors.fill: parent
            backdrop: true
            roundTopLeft: true
            roundTopRight: true
        }

        Card {
            id: osdBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.panelPadding
            // Its panel's header, or the keyboard's own.
            panel: root.shownLevel?.panel ?? ""
            title: root.shownLevel?.title ?? PanelService.panels[osdBody.panel]?.label ?? ""
            iconName: root.shownLevel?.icon ?? PanelService.panels[osdBody.panel]?.icon ?? ""

            Loader {
                width: parent.width
                sourceComponent: root.shownLevel ? root.shownLevel.row : stateRow
            }
        }
    }

    PopIn {
        id: entrance
        card: osdCard
    }

    NumberAnimation {
        id: exitAnimation
        target: osdCard
        property: "opacity"
        to: 0
        duration: Theme.animDurationExit
        easing.type: Theme.animEasingExit
        // Also stopped, short of the end, when present() takes the card back.
        onStopped: {
            if (osdCard.opacity <= 0)
                root.shown = false;
        }
    }

    NumberAnimation {
        id: comeBack
        target: osdCard
        property: "opacity"
        to: 1
        duration: Theme.animDurationFast
        easing.type: Theme.animEasing
    }
}
