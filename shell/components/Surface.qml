import QtQuick
import QtQuick.Shapes
import qs.services

// Speshell's floating surface: the theme's base color, rounded on the corners that
// face the screen's center, a thin frame, and an accent edge. With `backdrop`, the theme
// effects' still backdrop is painted in; it renders once into a texture.
Item {
    id: root

    property bool backdrop: false
    // Paint the backdrop at least this tall and show its top. Backdrops keep their busy
    // parts low, below where text sits on a tall surface, so a short surface full of
    // text, like the bar or the launcher, shows their calm top.
    property real backdropHeight: Theme.backdropHeight
    property int radius: Theme.surfaceRadius
    property bool roundTopLeft: false
    property bool roundTopRight: false
    property bool roundBottomRight: false
    property bool roundBottomLeft: false
    // "left", "right", or "" for none.
    property string edge: ""
    property color edgeColor: Theme.accent
    property color fillColor: Theme.bg
    // Laid over the fill and the backdrop, as for a hovered surface.
    property color tint: "transparent"

    Item {
        id: material

        width: root.width
        height: Math.max(root.height, root.backdropHeight)
        visible: root.backdrop && backdropLoader.status === Loader.Ready

        Rectangle {
            anchors.fill: parent
            color: root.fillColor
        }

        Loader {
            id: backdropLoader

            anchors.fill: parent
            active: root.backdrop
            sourceComponent: EffectsService.backdrop
        }

        Binding {
            target: backdropLoader.item
            property: "theme"
            value: Theme
        }
    }

    ShaderEffectSource {
        id: materialTexture

        visible: false
        sourceItem: material.visible ? material : null
        sourceRect: Qt.rect(0, 0, root.width, root.height)
        hideSource: true
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 2
            strokeColor: Qt.rgba(
                Theme.surface2.r * 0.88 + Theme.overlay.r * 0.12,
                Theme.surface2.g * 0.88 + Theme.overlay.g * 0.12,
                Theme.surface2.b * 0.88 + Theme.overlay.b * 0.12,
                1
            )
            fillColor: root.fillColor
            fillItem: material.visible ? materialTexture : null
            joinStyle: ShapePath.MiterJoin

            PathRectangle {
                width: root.width
                height: root.height
                topLeftRadius: root.roundTopLeft ? root.radius : 0
                topRightRadius: root.roundTopRight ? root.radius : 0
                bottomRightRadius: root.roundBottomRight ? root.radius : 0
                bottomLeftRadius: root.roundBottomLeft ? root.radius : 0
            }
        }

        ShapePath {
            strokeWidth: -1
            fillColor: root.tint

            PathRectangle {
                width: root.width
                height: root.height
                topLeftRadius: root.roundTopLeft ? root.radius : 0
                topRightRadius: root.roundTopRight ? root.radius : 0
                bottomRightRadius: root.roundBottomRight ? root.radius : 0
                bottomLeftRadius: root.roundBottomLeft ? root.radius : 0
            }
        }
    }

    Rectangle {
        readonly property real inset: Math.max(root.radius, Math.min(40, root.height * 0.2))

        visible: root.edge !== ""
        x: root.edge === "left" ? 0 : root.width - width
        y: inset
        width: 2
        height: Math.max(0, root.height - inset * 2)

        gradient: Gradient {
            GradientStop { position: 0; color: Theme.alpha(root.edgeColor, 0) }
            GradientStop { position: 0.10; color: root.edgeColor }
            GradientStop { position: 0.88; color: root.edgeColor }
            GradientStop { position: 1; color: Theme.alpha(root.edgeColor, 0) }
        }
    }
}
