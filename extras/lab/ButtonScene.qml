import QtQuick
import QtQuick.Shapes
import Quickshell

// Mimics primary buttons in THEME_INI's colors, over the effects' backdrop: the
// effects' button face clipped to Speshell's cut-corner outline, with its label. Each
// row holds one at rest, one hovered, and one hovered and pressed now and then; the top
// row at a dropdown's sizes, the bottom at three times them. From 3 s they keep still,
// as in power saver.
Item {
    id: root
    width: 1920
    height: 1080
    property real labTime: 0
    // As ActionButton passes them to EffectClock.
    readonly property real timeScale: 1
    readonly property int frameRate: 60

    readonly property bool running: root.labTime < 3
    // The pointer sweeps across the hovered buttons and back.
    readonly property real sweep: 0.5 + 0.4 * Math.sin(root.labTime * 2.2)
    readonly property bool pressing: (root.labTime % 1.2) > 0.85

    property var effects: {
        const component = Qt.createComponent("file://" + Quickshell.env("EFFECTS_DIR") + "/Effects.qml");
        if (component.status !== Component.Ready) {
            console.error(component.errorString());
            return null;
        }
        return component.createObject(root);
    }
    readonly property Component face: root.effects && ("button" in root.effects) ? root.effects.button : null

    ThemePalette {
        id: swatch
    }

    Item {
        x: 16
        y: 16
        width: 708
        height: 248
        clip: true

        Rectangle {
            anchors.fill: parent
            color: swatch.bg
        }

        Loader {
            id: backdrop
            width: parent.width
            height: 1050
            sourceComponent: root.effects && ("backdrop" in root.effects) ? root.effects.backdrop : null
        }

        Binding { target: backdrop.item; property: "theme"; value: swatch }

        Row {
            x: 24
            y: 20
            spacing: 24

            Button { zoom: 1; label: "Keep changes" }
            Button { zoom: 1; label: "Keep changes"; hovered: true }
            Button { zoom: 1; label: "Finish"; hovered: true; pressed: root.pressing }
        }

        Row {
            x: 24
            y: 76
            spacing: 24

            Button { zoom: 3; label: "Finish" }
            Button { zoom: 3; label: "Finish"; hovered: true }
        }
    }

    component Button: Item {
        id: button

        property real zoom: 1
        property string label: ""
        property bool hovered: false
        property bool pressed: false

        width: Math.round((labelText.implicitWidth / button.zoom + 24) * button.zoom)
        height: 32 * button.zoom
        scale: button.pressed ? 0.96 : 1

        Loader {
            id: face
            width: button.width
            height: button.height
            sourceComponent: root.face
        }

        Binding { target: face.item; property: "theme"; value: swatch }
        Binding { target: face.item; property: "hovered"; value: button.hovered }
        Binding { target: face.item; property: "pressed"; value: button.pressed }
        Binding { target: face.item; property: "pointer"; value: Qt.point(button.width * root.sweep, button.height / 2) }
        Binding { target: face.item; property: "running"; value: root.running }

        ShaderEffectSource {
            id: texture
            visible: false
            sourceItem: face.item ? face : null
            hideSource: true
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                id: outline

                readonly property real cut: Math.round(button.height / 5)
                readonly property real w: button.width - 0.5
                readonly property real h: button.height - 0.5

                fillColor: swatch.accent
                fillItem: face.item ? texture : null
                strokeWidth: button.zoom
                strokeColor: Qt.rgba(swatch.accent.r / 1.6, swatch.accent.g / 1.6, swatch.accent.b / 1.6, 0.6)
                joinStyle: ShapePath.MiterJoin

                PathPolyline {
                    path: [Qt.point(0.5 + outline.cut, 0.5), Qt.point(outline.w, 0.5), Qt.point(outline.w, outline.h - outline.cut),
                        Qt.point(outline.w - outline.cut, outline.h), Qt.point(0.5, outline.h), Qt.point(0.5, 0.5 + outline.cut),
                        Qt.point(0.5 + outline.cut, 0.5)]
                }
            }
        }

        Text {
            id: labelText
            anchors.centerIn: parent
            text: button.label
            font.pixelSize: 11 * button.zoom
            font.family: "Inter"
            font.weight: Font.DemiBold
            color: swatch.onAccent
        }
    }

    Component.onCompleted: {
        if (root.face === null)
            console.log("no button face");
    }
}
