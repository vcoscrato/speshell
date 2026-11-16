pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Templates as T
import Quickshell.Wayland
import qs.components
import qs.services

// The window shown instead of the shell while config.ini is invalid: what is wrong,
// with buttons to open the file, copy a report, retry, or quit. Once the file is open in
// an editor, it steps behind the windows, so the editor shows over it; saving a fixed file
// reloads the shell, which takes this window away.
ModalWindow {
    id: root

    property bool active: false

    targetScreen: HyprlandService.focusedScreen()
    visible: root.active && root.targetScreen !== null
    color: Theme.crust
    focusTarget: reportArea

    WlrLayershell.namespace: "speshell-config-error"

    // In front again the next time the configuration breaks.
    onVisibleChanged: if (!root.visible) root.behind = false

    // The palette of the last theme applied, or Cosmos's before any.
    Dialog {
        width: Math.min(Theme.panelWidth * 2, parent.width - Theme.spacingXL * 2)
        edge: "left"
        edgeColor: Theme.error
        iconName: "alert"
        toneColor: Theme.error
        title: "Configuration invalid"
        detail: root.behind
            ? "Speshell is stopped until the configuration is corrected, and starts again once it is saved."
            : "Speshell is stopped until the configuration is corrected."

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
            // The report, up to half the screen.
            height: Math.max(Theme.controlHeight * 5, Math.min(reportArea.implicitHeight + Theme.borderWidth * 2, root.height / 2))
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
                    font.pixelSize: Theme.fontSizeSmall
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
                text: ConfigService.feedback.text
                color: Theme.toneColor(ConfigService.feedback.tone)
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
                    onClicked: {
                        root.behind = true;
                        ConfigService.openConfig();
                    }
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
