pragma ComponentBehavior: Bound
import QtQuick
import qs.theme

// The Speshell mark: an asterisk between a pair of brackets, drawn on a 29-unit
// grid so it stays crisp at any multiple of 29 px.
Item {
    id: root

    property real size: 29
    property color leftColor: Theme.text
    property color rightColor: Theme.accent
    readonly property real unit: root.size / 29

    width: root.size
    height: root.size

    Rectangle {
        x: 0
        y: 2 * root.unit
        width: 2 * root.unit
        height: 25 * root.unit
        color: root.leftColor
    }
    Rectangle {
        x: 0
        y: 2 * root.unit
        width: 9 * root.unit
        height: 2 * root.unit
        color: root.leftColor
    }
    Rectangle {
        x: 0
        y: 25 * root.unit
        width: 9 * root.unit
        height: 2 * root.unit
        color: root.leftColor
    }

    Rectangle {
        x: 27 * root.unit
        y: 2 * root.unit
        width: 2 * root.unit
        height: 25 * root.unit
        color: root.rightColor
    }
    Rectangle {
        x: 20 * root.unit
        y: 2 * root.unit
        width: 9 * root.unit
        height: 2 * root.unit
        color: root.rightColor
    }
    Rectangle {
        x: 20 * root.unit
        y: 25 * root.unit
        width: 9 * root.unit
        height: 2 * root.unit
        color: root.rightColor
    }

    Repeater {
        model: [0, 60, -60]

        delegate: Rectangle {
            required property real modelData

            anchors.centerIn: parent
            width: 2 * root.unit
            height: 15 * root.unit
            radius: root.unit
            rotation: modelData
            antialiasing: true
            color: root.rightColor
        }
    }
}
