pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services
import "../services/ThemeProvider.js" as ThemeProvider
import "../components/Format.js" as Format

// What stands between the user and a session, on one screen: the theme's wallpaper,
// dimmed, its clock face over the date, and a card holding the children, as a password
// field. The lock screen and the login screen show it. The card shakes each time
// `failures` grows, and goes away without children. It comes and goes with the theme's
// launcher transition, which also plays round it while it shows.
Item {
    id: root

    property string wallpaper: ""
    property int failures: 0
    // A line under the card, as the keyboard layout.
    property string footnote: ""
    // Set once the way is open: the card leaves, and the dimming, clock, and date fade,
    // leaving the wallpaper as the desktop shows it; then departed() follows. Cleared again
    // before that, the card comes back.
    property bool leaving: false
    default property alias content: cardColumn.data

    readonly property bool transitionReady: transitionLoader.status === Loader.Ready
    // Whether departed() was emitted for this leaving.
    property bool gone: false

    signal departed()

    function finishLeaving() {
        if (!root.leaving || root.gone)
            return;
        root.gone = true;
        leaveTimer.stop();
        root.departed();
    }

    onFailuresChanged: if (root.failures > 0) shake.play()

    onLeavingChanged: {
        root.gone = false;
        if (root.leaving)
            leaveTimer.restart();
        else
            leaveTimer.stop();
    }

    // Without a transition the card fades with the rest; with one, this bounds an exit
    // that never reports its end.
    Timer {
        id: leaveTimer
        interval: root.transitionReady ? Math.round(2500 / Math.max(0.25, transitionLoader.timeScale)) : Theme.animDurationSlow
        onTriggered: root.finishLeaving()
    }

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
        opacity: root.leaving ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationSlow; easing.type: Theme.animEasing }
        }
    }

    Column {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.spacingXL

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingMedium
            opacity: root.leaving ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDurationSlow; easing.type: Theme.animEasing }
            }

            ClockFace {
                id: face
                anchors.horizontalCenter: parent.horizontalCenter
                // As wide as the card under it, on a screen tall enough.
                width: Math.round(Math.min(Theme.panelWidth, root.height * 0.32))
                height: width
                ticking: root.visible
            }

            Label {
                role: "heading"
                anchors.horizontalCenter: parent.horizontalCenter
                text: Format.date(face.now)
            }
        }

        Surface {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            visible: cardColumn.visibleChildren.length > 0
            width: Theme.panelWidth
            height: cardColumn.implicitHeight + Theme.spacingLarge * 2
            backdrop: true
            rounded: true
            opacity: root.leaving && !root.transitionReady ? 0 : 1
            transform: Translate { id: shakeOffset }

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDurationSlow; easing.type: Theme.animEasing }
            }

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
            opacity: root.leaving ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDurationSlow; easing.type: Theme.animEasing }
            }

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

    Shake {
        id: shake
        offset: shakeOffset
    }

    // The theme's launcher transition, with the card as its panel (see effects/README.md).
    Loader {
        id: transitionLoader
        property real timeScale: EffectsService.launcherSpeed > 0 ? EffectsService.launcherSpeed : 1
        property int frameRate: EffectsService.frameRate
        z: 1
        anchors.fill: parent
        active: card.visible && EffectsService.launcherTransition !== null
        sourceComponent: EffectsService.launcherTransition
    }

    Binding {
        target: transitionLoader.item
        property: "panel"
        value: card
    }

    Binding {
        target: transitionLoader.item
        property: "panelRect"
        value: Qt.rect(layout.x + card.x, layout.y + card.y, card.width, card.height)
    }

    Binding {
        target: transitionLoader.item
        property: "panelRadius"
        value: Theme.surfaceRadius
        when: transitionLoader.item !== null && "panelRadius" in transitionLoader.item
    }

    Binding {
        target: transitionLoader.item
        property: "active"
        value: !root.leaving
    }

    Binding {
        target: transitionLoader.item
        property: "theme"
        value: Theme
    }

    Connections {
        target: transitionLoader.item
        ignoreUnknownSignals: true

        function onClosingFinished() { root.finishLeaving(); }
    }
}
