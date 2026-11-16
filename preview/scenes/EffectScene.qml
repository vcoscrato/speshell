import QtQuick
import Quickshell

// What the effect scenes share: a screen-sized stage on the harness's `previewTime`, the
// effects in EFFECTS_DIR, and `swatch`, Theme.qml's color names from THEME_INI's [Colors].
Item {
    id: root
    width: 1920
    height: 1080
    property real previewTime: 0

    readonly property ThemePalette swatch: ThemePalette {}
    readonly property var effects: {
        const component = Qt.createComponent("file://" + Quickshell.env("EFFECTS_DIR") + "/Effects.qml");
        if (component.status !== Component.Ready) {
            console.error(component.errorString());
            return null;
        }
        return component.createObject(root);
    }
}
