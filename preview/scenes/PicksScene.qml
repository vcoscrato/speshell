import QtQuick
import Quickshell

// Picks up close, in THEME_INI's colors: a bar's clock clicked near its end, a bar icon,
// a panel's row clicked on its label, and a square button, each with the pointer drawn
// where it pressed. The effects' interactions get pick(area, at) as bar/InteractionsLayer.qml
// calls it.
Item {
    id: root
    width: 1920
    height: 1080
    property real previewTime: 0
    readonly property real timeScale: Number(Quickshell.env("SPEED") || 1)

    property var effects: {
        const component = Qt.createComponent("file://" + Quickshell.env("EFFECTS_DIR") + "/Effects.qml");
        if (component.status !== Component.Ready) {
            console.error(component.errorString());
            return null;
        }
        return component.createObject(root);
    }

    ThemePalette {
        id: swatch
    }

    // ── Script: [time, target, where in it (0..1 across, 0..1 down)] ─
    readonly property var script: [
        [0.3, clock, 0.82, 0.5],
        [1.2, bell, 0.4, 0.6],
        [2.1, deviceRow, 0.22, 0.5],
        [3.0, buttonBox, 0.5, 0.5]
    ]
    property var done: ({})
    property point pointer: Qt.point(-100, -100)
    property real pressedAt: -10

    onPreviewTimeChanged: {
        const fx = fxLayer.item;
        if (!fx)
            return;
        for (let i = 0; i < script.length; i++) {
            const [t, target, u, v] = script[i];
            if (previewTime < t || done[i])
                continue;
            done[i] = true;
            const area = target.mapToItem(fxLayer, 0, 0, target.width, target.height);
            const at = Qt.point(area.x + area.width * u, area.y + area.height * v);
            pointer = at;
            pressedAt = previewTime;
            fx.pick(area, at);
        }
    }

    Item {
        x: 16
        y: 16
        width: 420
        height: 300
        clip: true

        Rectangle {
            anchors.fill: parent
            color: swatch.bg
        }

        // ── The bar ──────────────────────────────────────────
        Rectangle {
            id: bar
            width: parent.width
            height: 40
            color: swatch.mantle

            Row {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: index === 1 ? 22 : 8
                        height: 8
                        radius: 4
                        color: index === 1 ? swatch.accent : swatch.surface2
                    }
                }
            }

            Rectangle {
                id: clock
                x: 112
                y: 5
                width: 168
                height: 30
                radius: 4
                color: root.previewTime >= 0.3 ? Qt.rgba(swatch.accent.r, swatch.accent.g, swatch.accent.b, 0.14) : "transparent"
                border.width: root.previewTime >= 0.3 ? 1 : 0
                border.color: Qt.rgba(swatch.accent.r, swatch.accent.g, swatch.accent.b, 0.5)
                Text {
                    anchors.centerIn: parent
                    text: "Wed 14 Oct   21:37"
                    color: swatch.text
                    font.pixelSize: 13
                    font.bold: true
                }
            }

            Rectangle {
                id: bell
                x: parent.width - 82
                y: 5
                width: 30
                height: 30
                radius: 4
                color: root.previewTime >= 1.2 ? Qt.rgba(swatch.accent.r, swatch.accent.g, swatch.accent.b, 0.14) : "transparent"
                Rectangle {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    radius: 7
                    color: "transparent"
                    border.width: 2
                    border.color: swatch.text
                }
            }

            Rectangle {
                x: parent.width - 44
                y: 5
                width: 30
                height: 30
                radius: 4
                color: "transparent"
                Rectangle {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    radius: 3
                    color: "transparent"
                    border.width: 2
                    border.color: swatch.subtext
                }
            }
        }

        // ── A panel ──────────────────────────────────────────
        Item {
            y: 40
            width: parent.width
            height: parent.height - 40
            clip: true

            Loader {
                id: backdrop
                anchors.fill: parent
                sourceComponent: root.effects && ("backdrop" in root.effects) ? root.effects.backdrop : null
            }

            Binding { target: backdrop.item; property: "theme"; value: swatch }

            Rectangle {
                id: buttonBox
                x: 9
                y: 160
                width: 38
                height: 38
                radius: 3
                color: Qt.rgba(swatch.accent.r, swatch.accent.g, swatch.accent.b, root.previewTime >= 3.0 ? 0.12 : 0)
                border.width: 1
                border.color: Qt.rgba(swatch.accent.r, swatch.accent.g, swatch.accent.b, root.previewTime >= 3.0 ? 0.45 : 0)
                Rectangle {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    radius: 4
                    color: "transparent"
                    border.width: 2
                    border.color: root.previewTime >= 3.0 ? swatch.accent : swatch.subtext
                }
            }

            Text {
                x: 76
                y: 22
                text: "Output"
                color: swatch.subtext
                font.pixelSize: 12
            }

            Repeater {
                model: ["Speakers", "Headphones", "HDMI"]
                Rectangle {
                    id: row
                    required property int index
                    required property string modelData
                    readonly property bool on: root.previewTime >= 2.1 ? index === 1 : index === 0
                    x: 70
                    y: 44 + index * 36
                    width: 320
                    height: 30
                    radius: 4
                    color: row.on ? Qt.rgba(swatch.accent.r, swatch.accent.g, swatch.accent.b, 0.1) : "transparent"
                    Component.onCompleted: if (index === 1) root.deviceRow = row
                    Rectangle {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        radius: 7
                        border.width: 2
                        border.color: swatch.accent
                        color: row.on ? swatch.accent : "transparent"
                    }
                    Text {
                        x: 34
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData
                        color: swatch.text
                        font.pixelSize: 12
                    }
                }
            }
        }

        // The effects' interactions, over everything and taking no input.
        Loader {
            id: fxLayer
            anchors.fill: parent
            sourceComponent: root.effects && ("interactions" in root.effects) ? root.effects.interactions : null
        }

        Binding { target: fxLayer.item; property: "theme"; value: swatch }

        // The pointer, pressing.
        Canvas {
            x: root.pointer.x - 1
            y: root.pointer.y - 1
            width: 14
            height: 20
            scale: root.previewTime - root.pressedAt < 0.12 ? 0.85 : 1
            transformOrigin: Item.TopLeft
            onPaint: {
                const ctx = getContext("2d");
                ctx.beginPath();
                ctx.moveTo(1, 1);
                ctx.lineTo(1, 16);
                ctx.lineTo(5, 12.5);
                ctx.lineTo(8, 19);
                ctx.lineTo(10.5, 18);
                ctx.lineTo(7.5, 11.5);
                ctx.lineTo(12.5, 11.5);
                ctx.closePath();
                ctx.fillStyle = "white";
                ctx.strokeStyle = "black";
                ctx.lineWidth = 1.2;
                ctx.fill();
                ctx.stroke();
            }
        }
    }

    property Item deviceRow: null

    Component.onCompleted: {
        if (fxLayer.sourceComponent === null)
            console.log("no interactions");
    }
}
