pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services
import "../services/ThemeProvider.js" as ThemeProvider

// What stands between the user and a session, on one screen: the theme's wallpaper,
// dimmed, its clock face over the date, and a card holding the children, as a password
// field. The lock screen and the login screen show it. The card shakes each time
// `failures` grows, and goes away without children.
Item {
    id: root

    property string wallpaper: ""
    property int failures: 0
    // A line under the card, as the keyboard layout.
    property string footnote: ""
    default property alias content: cardColumn.data

    onFailuresChanged: if (root.failures > 0 && Theme.motion) shake.restart()

    DefaultWallpaper {
        anchors.fill: parent
    }

    // Loaded before the first frame, so the screen never shows the desktop's place empty.
    Image {
        anchors.fill: parent
        visible: status === Image.Ready
        source: ThemeProvider.fileUrl(root.wallpaper)
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.crust, 0.5)
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingXL

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingMedium

            ClockFace {
                id: face
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(Math.min(360, root.height * 0.32))
                height: width
                ticking: root.visible
            }

            Label {
                role: "heading"
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(face.now, "dddd, d MMMM")
            }
        }

        Surface {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            visible: cardColumn.children.length > 0
            width: Theme.panelWidth
            height: cardColumn.implicitHeight + Theme.spacingLarge * 2
            backdrop: true
            roundTopLeft: true
            roundTopRight: true
            roundBottomRight: true
            roundBottomLeft: true
            transform: Translate { id: offset }

            Column {
                id: cardColumn
                x: Theme.spacingLarge
                y: Theme.spacingLarge
                width: parent.width - Theme.spacingLarge * 2
                spacing: Theme.spacingSmall
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.footnote !== ""
            spacing: Theme.spacingTiny

            AppIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "keyboard"
                size: Theme.iconSizeSmall
                iconColor: Theme.subtextBright
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.footnote
                color: Theme.subtextBright
            }
        }
    }

    SequentialAnimation {
        id: shake

        NumberAnimation { target: offset; property: "x"; to: -12; duration: 50 }
        NumberAnimation { target: offset; property: "x"; to: 10; duration: 80 }
        NumberAnimation { target: offset; property: "x"; to: -6; duration: 70 }
        NumberAnimation { target: offset; property: "x"; to: 0; duration: 60 }
    }
}
