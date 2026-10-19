import QtQuick
import qs.components
import qs.theme

// One app's system tray icon: left click activates it, or opens its menu when it
// only has one; right click opens the menu below the icon, or above it on a bottom bar.
Item {
    id: root

    required property var modelData
    // On a bottom bar: the menu and the label open above.
    property bool above: false
    readonly property bool menuOpen: menu.visible
    property bool pointerInside: false
    readonly property bool containingWindowVisible: !!(root.Window
        && root.Window.window
        && root.Window.window.visible)
    readonly property string labelText: root.modelData.tooltipTitle
        || root.modelData.title
        || root.modelData.id
        || "System tray icon"
    readonly property string iconPath: {
        var icon = root.modelData.icon;
        if (!icon)
            return "";
        var s = icon.toString();
        var pi = s.indexOf("?path=");
        return pi !== -1 ? s.substring(0, pi) : s;
    }

    function activate() {
        if (root.modelData.onlyMenu && root.modelData.hasMenu)
            menu.open();
        else
            root.modelData.activate();
    }

    width: Theme.controlHeight
    height: Theme.controlHeight

    Connections {
        target: root.Window ? root.Window.window : null

        function onVisibleChanged() {
            if (!root.containingWindowVisible)
                root.pointerInside = false;
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.labelText
    Accessible.onPressAction: root.activate()

    Rectangle {
        anchors.fill: parent
        color: root.pointerInside ? Theme.cardHover : "transparent"
        radius: Theme.borderRadius

        Image {
            id: trayImage
            anchors.centerIn: parent
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            visible: root.iconPath !== ""
            source: root.iconPath
            sourceSize: Qt.size(Theme.iconSizeMedium, Theme.iconSizeMedium)
            fillMode: Image.PreserveAspectFit
        }

        AppIcon {
            anchors.centerIn: parent
            name: "tray-fallback"
            size: Theme.iconSizeMedium
            iconColor: Theme.subtext
            visible: !trayImage.visible
        }
    }

    HoverLabel {
        visible: root.containingWindowVisible
            && root.pointerInside
            && !root.menuOpen
            && root.labelText !== ""
        text: root.labelText
        above: root.above
    }

    TrayMenu {
        id: menu
        handle: root.modelData.menu
        y: root.above ? -menu.height - Theme.spacingMedium : root.height + Theme.spacingMedium
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: root.pointerInside = true
        onExited: root.pointerInside = false
        onCanceled: root.pointerInside = false
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton)
                root.activate();
            else if (root.modelData.hasMenu)
                menu.open();
        }
    }
}
