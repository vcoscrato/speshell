import QtQuick
// A stand-in for Speshell's launcher panel in `theme`'s colors.
Rectangle {
    id: root
    property var theme: null
    radius: 10; color: root.theme.bg; border.color: root.theme.surface2; border.width: 1
    Rectangle { x: 16; y: 16; width: parent.width - 32; height: 48; radius: 8; color: root.theme.card
        Text { x: 44; anchors.verticalCenter: parent.verticalCenter; text: "Search apps and panels…"; color: root.theme.subtext; font.pixelSize: 16 } }
    Column { x: 16; y: 80; spacing: 4
        Repeater { model: ["Firefox", "Terminal", "Files", "Settings"]
            Rectangle { required property string modelData; required property int index; width: 508; height: 52; radius: 8
                color: index === 0 ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.12) : "transparent"
                Text { x: 50; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData; color: root.theme.text; font.pixelSize: 14 } } } }
}
