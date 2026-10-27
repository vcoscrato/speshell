pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.components

// A tray item's menu, from its `menu` handle, as a PopupMenu. The app's entries load
// only while the menu shows; submenus cascade and load when they open.
PopupMenu {
    id: root

    property var handle: null

    // One entry of the app's menu and the row or submenu built for it.
    component Slot: QtObject {
        required property var modelData
        property var built: null
        property bool submenu: false
    }

    QsMenuOpener {
        id: opener
        menu: root.visible ? root.handle : null
    }

    Component {
        id: entryComponent

        PopupMenuItem {
            property var entry: null

            text: entry ? entry.text : ""
            enabled: entry ? entry.enabled : false
            icon.source: entry ? entry.icon : ""
            selectable: entry !== null && entry.buttonType !== QsMenuButtonType.None
            selected: entry !== null && entry.checkState === Qt.Checked
            onTriggered: entry.triggered()
        }
    }

    Component {
        id: separatorComponent
        PopupMenuSeparator {}
    }

    Instantiator {
        model: opener.children

        delegate: Slot {}

        onObjectAdded: function(index, object) {
            var slot = object as Slot;
            var entry = slot.modelData;
            slot.submenu = entry.hasChildren;
            if (slot.submenu) {
                slot.built = Qt.createComponent("TrayMenu.qml").createObject(null, { handle: entry, title: entry.text });
                root.insertMenu(index, slot.built);
            } else {
                slot.built = entry.isSeparator
                    ? separatorComponent.createObject(null)
                    : entryComponent.createObject(null, { entry: entry });
                root.insertItem(index, slot.built);
            }
        }

        // Removing also destroys them.
        onObjectRemoved: function(index, object) {
            var slot = object as Slot;
            if (slot.submenu)
                root.removeMenu(slot.built);
            else
                root.removeItem(slot.built);
        }
    }
}
