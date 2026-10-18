import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.services

// Speshell's floating surface: the theme's base color, cut on the corners that face
// the screen's center, a thin frame, and an accent edge. With `backdrop`, the theme
// effects' still backdrop is painted in; it renders once into a texture.
Item {
    id: root

    property bool backdrop: false
    // Paint the backdrop at least this tall and show its top. Backdrops keep their busy
    // parts low, below where text sits on a tall surface, so a short surface full of
    // text, like the bar or the launcher, shows their calm top.
    property real backdropHeight: Theme.backdropHeight
    property int cut: Theme.surfaceCornerCut
    property bool cutTopLeft: false
    property bool cutTopRight: false
    property bool cutBottomRight: false
    property bool cutBottomLeft: false
    // "left", "right", or "" for none.
    property string edge: ""
    property color edgeColor: Theme.accent
    property color fillColor: Theme.bg

    readonly property int topLeft: root.cutTopLeft ? root.cut : 0
    readonly property int topRight: root.cutTopRight ? root.cut : 0
    readonly property int bottomRight: root.cutBottomRight ? root.cut : 0
    readonly property int bottomLeft: root.cutBottomLeft ? root.cut : 0
    // The outline, clockwise from the top left; an uncut corner is one point.
    readonly property var outline: {
        var w = root.width;
        var h = root.height;
        var points = [Qt.point(root.topLeft, 0)];
        if (root.topRight > 0)
            points.push(Qt.point(w - root.topRight, 0), Qt.point(w, root.topRight));
        else
            points.push(Qt.point(w, 0));
        if (root.bottomRight > 0)
            points.push(Qt.point(w, h - root.bottomRight), Qt.point(w - root.bottomRight, h));
        else
            points.push(Qt.point(w, h));
        if (root.bottomLeft > 0)
            points.push(Qt.point(root.bottomLeft, h), Qt.point(0, h - root.bottomLeft));
        else
            points.push(Qt.point(0, h));
        if (root.topLeft > 0)
            points.push(Qt.point(0, root.topLeft));
        points.push(points[0]);
        return points;
    }

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
        antialiasing: true

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
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin

            PathPolyline { path: root.outline }
        }
    }

    Rectangle {
        readonly property real inset: Math.max(root.cut, Math.min(40, root.height * 0.2))

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
