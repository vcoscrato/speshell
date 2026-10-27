import QtQuick
import Quickshell

// Renders COPIES independent instances of INNER (a scene file) into full-resolution
// offscreen layers every frame, so GPU cost dominates the frame time.
Item {
    id: root
    width: 1
    height: 1
    property real previewTime: 0

    Repeater {
        model: Number(Quickshell.env("COPIES") || 1)

        ShaderEffectSource {
            width: 1
            height: 1
            live: true
            hideSource: true
            textureSize: Qt.size(1920, 1080)
            sourceItem: inner

            Loader {
                id: inner
                source: Quickshell.env("INNER")
                onLoaded: item.previewTime = Qt.binding(function() { return root.previewTime; })
            }
        }
    }
}
