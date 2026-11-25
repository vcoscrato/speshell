import QtQuick
import qs.components
import qs.services
import "../components/Keyboard.js" as Keyboard

// One app's system tray icon: left click activates it, or opens its menu when it
// only has one; right click opens the menu below the icon, or above it on a bottom bar.
// From the keyboard, Space or Enter is the left click and the Menu key the right.
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
    // The icon by name from the icon theme, and, when the app names a folder of its own
    // (`?path=`), the file there, tried once the theme has no such icon.
    readonly property string iconSource: root.modelData.icon ? root.modelData.icon.toString() : ""
    readonly property string iconPath: {
        const pi = root.iconSource.indexOf("?path=");
        return pi !== -1 ? root.iconSource.substring(0, pi) : root.iconSource;
    }
    readonly property string iconFile: {
        const pi = root.iconSource.indexOf("?path=");
        if (pi === -1)
            return "";
        const name = root.iconPath.substring(root.iconPath.lastIndexOf("/") + 1);
        return "file://" + decodeURIComponent(root.iconSource.substring(pi + 6)) + "/" + name;
    }
    property bool themeMissing: false
    onIconSourceChanged: root.themeMissing = false

    function activate() {
        if (root.modelData.onlyMenu && root.modelData.hasMenu)
            menu.open();
        else
            root.modelData.activate();
    }

    width: Theme.controlHeight
    height: Theme.controlHeight
    activeFocusOnTab: true

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
    Keys.onPressed: event => {
        if (Keyboard.presses(event)) {
            event.accepted = true;
            root.activate();
        } else if (event.key === Qt.Key_Menu && root.modelData.hasMenu) {
            event.accepted = true;
            menu.open();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.pointerInside ? Theme.cardHover : "transparent"
        radius: Theme.borderRadius

        Image {
            id: trayImage
            anchors.centerIn: parent
            width: Theme.iconSizeMedium
            height: Theme.iconSizeMedium
            visible: root.iconPath !== "" && status !== Image.Error
            source: root.themeMissing ? root.iconFile : root.iconPath
            sourceSize: Qt.size(Theme.iconSizeMedium, Theme.iconSizeMedium)
            fillMode: Image.PreserveAspectFit
            onStatusChanged: {
                if (status === Image.Error && !root.themeMissing && root.iconFile !== "")
                    root.themeMissing = true;
            }
        }

        AppIcon {
            anchors.centerIn: parent
            name: "tray-fallback"
            size: Theme.iconSizeMedium
            iconColor: Theme.subtext
            visible: !trayImage.visible
        }
    }

    Tooltip {
        visible: root.containingWindowVisible
            && (root.pointerInside || root.activeFocus)
            && !root.menuOpen
            && root.labelText !== ""
        text: root.labelText
        below: !root.above
        // At once, as the bar is glanced over.
        delay: 0
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
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.activate();
            else if (root.modelData.hasMenu)
                menu.open();
        }
    }

    FocusRing {}
}
