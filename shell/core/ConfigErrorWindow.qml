pragma ComponentBehavior: Bound
// Quickshell's type info marks PanelWindow uncreatable, though QML creates it.
// qmllint disable uncreatable-type

import QtQuick
import QtQuick.Templates as T
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.services

// The window shown instead of the shell while config.ini is invalid: what is wrong,
// with buttons to open the file, copy a report, retry, or quit.
PanelWindow {
    id: root

    property bool active: false
    property bool focusGrabActive: false
    readonly property var targetScreen: HyprlandService.focusedScreen()

    visible: root.active && root.targetScreen !== null
    screen: root.targetScreen
    color: Theme.crust
    focusable: true
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "speshell-config-error"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    HyprlandFocusGrab {
        active: root.focusGrabActive && HyprlandService.running
        windows: [root]
    }

    onVisibleChanged: {
        root.focusGrabActive = root.visible;
        if (root.visible)
            reportArea.forceActiveFocus();
    }

    // The palette of the last theme applied, or Cosmos's before any.
    Surface {
        anchors.centerIn: parent
        width: Math.min(720, parent.width - Theme.spacingXL * 2)
        height: Math.min(620, parent.height - Theme.spacingXL * 2)
        backdrop: true
        roundTopLeft: true
        roundTopRight: true
        roundBottomRight: true
        roundBottomLeft: true
        edge: "left"
        edgeColor: Theme.error

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingLarge

            Row {
                width: parent.width
                spacing: Theme.spacingMedium

                AppIcon {
                    id: alertIcon
                    name: "alert"
                    size: Theme.iconSizeLarge
                    iconColor: Theme.error
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    width: parent.width - alertIcon.width - parent.spacing
                    spacing: Theme.spacingMicro

                    Label {
                        role: "heading"
                        text: "Configuration invalid"
                    }

                    Label {
                        width: parent.width
                        text: "Speshell is stopped until the configuration is corrected."
                        color: Theme.subtext
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: Theme.controlHeight
                radius: Theme.borderRadius
                color: Theme.mantle
                border.width: Theme.borderWidth
                border.color: Theme.controlBorder

                Label {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingMedium
                    anchors.rightMargin: Theme.spacingMedium
                    text: ConfigService.configPath || "~/.config/speshell/config.ini"
                    color: Theme.subtextBright
                    elide: Text.ElideMiddle
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Rectangle {
                width: parent.width
                height: Math.max(160, parent.height - 196)
                radius: Theme.borderRadius
                color: Theme.mantle
                border.width: Theme.borderWidth
                border.color: Theme.controlBorder

                Flickable {
                    id: reportScroll
                    anchors.fill: parent
                    anchors.margins: Theme.borderWidth
                    contentHeight: reportArea.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    T.ScrollBar.vertical: StyledScrollBar {
                        policy: reportScroll.contentHeight > reportScroll.height ? T.ScrollBar.AsNeeded : T.ScrollBar.AlwaysOff
                    }

                    TextEdit {
                        id: reportArea
                        width: reportScroll.width
                        padding: Theme.spacingMedium
                        text: ConfigService.errorReport
                        readOnly: true
                        selectByMouse: true
                        textFormat: TextEdit.PlainText
                        wrapMode: TextEdit.Wrap
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.onAccent
                        font.family: "monospace"
                        font.pixelSize: Theme.fontSizeSupporting
                    }
                }
            }

            Item {
                width: parent.width
                height: Theme.controlHeight

                Label {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - actionRow.width - Theme.spacingMedium)
                    text: ConfigService.operationMessage
                    color: ConfigService.operationFailed ? Theme.error : Theme.success
                    elide: Text.ElideRight
                }

                Row {
                    id: actionRow
                    anchors.right: parent.right
                    spacing: Theme.spacingSmall

                    ActionButton {
                        text: "Quit"
                        iconName: "close"
                        onClicked: Qt.quit()
                    }

                    ActionButton {
                        text: "Open config"
                        iconName: "folder-open"
                        onClicked: ConfigService.openConfig()
                    }

                    ActionButton {
                        text: "Copy report"
                        iconName: "copy"
                        onClicked: ConfigService.copyErrorReport()
                    }

                    ActionButton {
                        text: "Retry"
                        iconName: "refresh"
                        kind: "primary"
                        onClicked: ConfigService.load()
                    }
                }
            }
        }
    }
}
