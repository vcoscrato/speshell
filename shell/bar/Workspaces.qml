pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services
import qs.components

// The bar's screen's Hyprland workspaces: those with windows and the active one. A
// click shows one; hovering names its last focused window.
Row {
    id: root

    property string screenName: ""
    property int itemSize: Theme.controlHeight
    // On a bottom bar: labels show above.
    property bool labelAbove: false

    spacing: Theme.spacingTiny

    Repeater {
        // By id, so a refresh updates the buttons in place instead of rebuilding them.
        model: ScriptModel {
            values: WorkspaceService.workspaces
                .filter(workspace => workspace.monitor === root.screenName)
                .map(workspace => workspace.id)
        }

        delegate: Rectangle {
            id: workspace

            required property int modelData
            readonly property var info: WorkspaceService.workspaces.find(entry => entry.id === workspace.modelData)
                ?? { id: workspace.modelData, name: "", active: false, occupied: false, title: "" }
            property bool pointerInside: false

            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(root.itemSize, nameText.implicitWidth + Theme.spacingMedium * 2)
            height: Math.min(Theme.controlHeightSmall + Theme.spacingTiny, root.itemSize)
            radius: Theme.borderRadius
            color: workspace.info.active
                ? Theme.selectedFill
                : (workspace.pointerInside ? Theme.cardHover : "transparent")
            border.width: workspace.info.active ? Theme.borderWidth : 0
            border.color: Theme.selectedBorder

            Accessible.role: Accessible.Button
            Accessible.name: "Workspace " + workspace.info.name
            Accessible.onPressAction: WorkspaceService.focus(workspace.modelData)

            Label {
                id: nameText
                anchors.centerIn: parent
                text: workspace.info.name
                font.weight: workspace.info.active ? Font.DemiBold : Font.Normal
                color: workspace.info.active
                    ? Theme.accent
                    : (workspace.info.occupied ? Theme.text : Theme.subtext)
            }

            HoverLabel {
                visible: workspace.pointerInside && workspace.info.title !== ""
                text: workspace.info.title
                above: root.labelAbove
            }

            MouseArea {
                id: workspaceMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    workspace.pointerInside = true;
                    // Titles aren't followed as they change; read them as one is named.
                    WorkspaceService.refresh();
                }
                onExited: workspace.pointerInside = false
                onCanceled: workspace.pointerInside = false
                onClicked: {
                    if (!workspace.info.active)
                        EffectsService.picked(workspace, workspaceMouse);
                    WorkspaceService.focus(workspace.modelData);
                }
            }
        }
    }
}
