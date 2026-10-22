pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import qs.components
import qs.panels
import qs.theme

// One panel under the bar button that opened it, or over it on a bottom bar, kept on
// screen. The panel sets its own width (a Card is Theme.panelWidth wide) and scrolls
// when it is taller than the screen allows.
Item {
    id: root

    // The bar's own rectangle, in the parent's coordinates, and whether it runs along
    // the top.
    property rect barRect: Qt.rect(0, 0, 0, 0)
    property bool atTop: true
    // The window shows.
    property bool shown: true
    // The panel shown, by PanelService id; "" while closed.
    property string panel: ""
    // The button it hangs from; null centers it on the bar.
    property Item button: null
    // Untyped, for the properties only some panels have.
    readonly property var panelItem: panelLoader.item

    readonly property int padding: Theme.panelPadding

    signal closeRequested()
    // The button's middle, summed up its parents so it follows the button as the bar
    // lays out around it, as when a new timer joins.
    readonly property real anchorX: {
        if (!root.button)
            return root.barRect.x + root.barRect.width / 2;
        let x = root.button.width / 2;
        for (let item = root.button; item && item !== root.parent; item = item.parent)
            x += item.x;
        return x;
    }
    readonly property real maxHeight: (root.atTop
            ? root.parent.height - root.barRect.y - root.barRect.height
            : root.barRect.y)
        - Theme.spacingSmall * 2

    readonly property var components: ({
        audio: audioPanel,
        battery: batteryPanel,
        bluetooth: bluetoothPanel,
        clipboard: clipboardPanel,
        clock: clockPanel,
        display: displayPanel,
        media: mediaPanel,
        microphone: microphonePanel,
        network: networkPanel,
        notes: notesPanel,
        notifications: notificationsPanel,
        power: powerPanel,
        timer: timerPanel,
        tools: toolsPanel,
        weather: weatherPanel
    })

    visible: root.panel !== ""
    x: Math.round(Math.max(Theme.spacingSmall,
        Math.min(root.parent.width - Theme.spacingSmall - root.width, root.anchorX - root.width / 2)))
    y: root.atTop
        ? root.barRect.y + root.barRect.height + Theme.spacingSmall
        : root.barRect.y - Theme.spacingSmall - root.height
    width: panelLoader.width + root.padding * 2
    height: Math.min(root.maxHeight, panelLoader.height + root.padding * 2)
    opacity: 0

    // Follows its panel's content as it grows and shrinks. A panel arriving takes its
    // size at once, whichever of it and this handler sees the change first.
    property bool followsContent: true

    Behavior on height {
        enabled: root.followsContent
        NumberAnimation {
            id: resize
            duration: Theme.animDuration
            easing.type: Theme.animEasing
        }
    }

    // Each panel enters, whether the dropdown opens with it or switches to it.
    onPanelChanged: {
        root.followsContent = false;
        resize.complete();
        if (root.panel !== "")
            entrance.restart();
        Qt.callLater(() => root.followsContent = true);
    }

    ParallelAnimation {
        id: entrance

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.animDurationFast
        }
        NumberAnimation {
            target: slide
            property: "y"
            from: root.atTop ? -Theme.spacingSmall : Theme.spacingSmall
            to: 0
            duration: Theme.animDuration
            easing.type: Theme.animEasing
        }
    }

    transform: Translate { id: slide }

    // Keeps clicks from reaching the bar's closing area behind.
    MouseArea {
        anchors.fill: parent
    }

    // Rounded on the corners away from the bar.
    Surface {
        anchors.fill: parent
        backdrop: true
        roundTopLeft: !root.atTop
        roundTopRight: !root.atTop
        roundBottomLeft: root.atTop
        roundBottomRight: root.atTop
    }

    FocusScope {
        anchors.fill: parent
        anchors.margins: root.padding
        focus: root.visible

        Keys.onEscapePressed: root.closeRequested()

        Flickable {
            id: flickable

            readonly property bool scrolls: contentHeight > height + 1

            anchors.fill: parent
            contentHeight: panelLoader.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 3000

            // In the padding beside the panel, so it never covers it.
            T.ScrollBar.vertical: StyledScrollBar {
                parent: flickable.parent
                anchors.left: flickable.right
                anchors.leftMargin: (root.padding - width) / 2
                anchors.top: flickable.top
                anchors.bottom: flickable.bottom
                policy: flickable.scrolls ? T.ScrollBar.AsNeeded : T.ScrollBar.AlwaysOff
            }

            Loader {
                id: panelLoader

                width: root.panelItem ? root.panelItem.implicitWidth : 0
                active: root.panel !== ""
                sourceComponent: root.components[root.panel] ?? null

                onLoaded: {
                    flickable.contentY = 0;
                    if ("presented" in root.panelItem)
                        root.panelItem.presented = Qt.binding(() => root.visible && root.shown);
                }
            }
        }
    }

    Component {
        id: audioPanel
        AudioPanel {
            output: true
        }
    }

    Component {
        id: microphonePanel
        AudioPanel {
            output: false
        }
    }

    Component {
        id: batteryPanel
        BatteryPanel {}
    }

    Component {
        id: bluetoothPanel
        BluetoothPanel {}
    }

    Component {
        id: clipboardPanel
        ClipboardPanel {}
    }

    Component {
        id: clockPanel
        ClockPanel {}
    }

    Component {
        id: displayPanel
        DisplayPanel {}
    }

    Component {
        id: mediaPanel
        MediaPanel {}
    }

    Component {
        id: networkPanel
        NetworkPanel {}
    }

    Component {
        id: notesPanel
        NotesPanel {}
    }

    Component {
        id: notificationsPanel
        NotificationsPanel {}
    }

    Component {
        id: powerPanel
        PowerPanel {}
    }

    // The timer of the chip it hangs from.
    Component {
        id: timerPanel
        TimerPanel {
            timer: (root.button as TimerChip)?.timer ?? null
            onDone: root.closeRequested()
        }
    }

    Component {
        id: toolsPanel
        ToolsPanel {}
    }

    Component {
        id: weatherPanel
        WeatherPanel {}
    }
}
