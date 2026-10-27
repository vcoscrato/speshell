import QtQuick
import Quickshell

// Mimics a panel's controls in THEME_INI's colors, played by a script: a slider dragged
// and let go twice, another stepped by the wheel, an audio device and a segment picked,
// a switch turned on and off, and a square button picked. The effects' knob draws the
// thumbs, and their interactions get the calls bar/InteractionsLayer.qml makes.
Item {
    id: root
    width: 1920
    height: 1080
    property real previewTime: 0
    // Effect speed, as Speshell passes [Appearance] controlEffectsSpeed to EffectClock.
    readonly property real timeScale: Number(Quickshell.env("SPEED") || 1)

    property var effects: {
        const component = Qt.createComponent("file://" + Quickshell.env("EFFECTS_DIR") + "/Effects.qml");
        if (component.status !== Component.Ready) {
            console.error(component.errorString());
            return null;
        }
        return component.createObject(root);
    }
    readonly property Component knobComponent: root.effects && ("knob" in root.effects) ? root.effects.knob : null

    ThemePalette {
        id: swatch
    }

    // ── Script ───────────────────────────────────────────────
    function ease(a, b, t0, t1, t) {
        const k = Math.max(0, Math.min(1, (t - t0) / (t1 - t0)));
        return a + (b - a) * k * k * (3 - 2 * k);
    }

    readonly property real volume: previewTime < 1.2 ? ease(0.2, 0.85, 0.3, 1.1, previewTime) : ease(0.85, 0.45, 1.3, 1.6, previewTime)
    readonly property bool dragging: (previewTime > 0.25 && previewTime < 1.15) || (previewTime > 1.25 && previewTime < 1.65)
    readonly property real brightness: 0.4 + 0.05 * [1.8, 1.9, 2.0, 2.1].filter(t => previewTime >= t).length
    // The pointer nears the volume knob, drags it, and moves off; it rests on the
    // brightness slider while its wheel turns, and on the switch while it flips.
    readonly property real volumePointer: previewTime < 0.3 ? ease(volumeSlider.knobX + 180, volumeSlider.knobX + 9, 0, 0.28, previewTime)
        : previewTime < 1.75 ? volumeSlider.knobX + 9 : ease(volumeSlider.knobX + 9, volumeSlider.knobX + 190, 1.75, 2.05, previewTime)
    readonly property bool switchHovered: previewTime > 3.1 && previewTime < 4.25
    property int device: previewTime >= 2.3 ? 1 : 0
    property int segment: previewTime >= 2.8 ? 2 : 0
    property bool switchOn: previewTime >= 3.3 && previewTime < 3.9
    property real switchAt: -10
    onSwitchOnChanged: switchAt = previewTime

    property var done: ({})
    function once(name, t, action) {
        if (previewTime >= t && !done[name]) {
            done[name] = true;
            action();
        }
    }

    property real lastVolumeX: volumeSlider.knobX
    property real lastBrightnessX: brightnessSlider.knobX
    onPreviewTimeChanged: {
        const fx = fxLayer.item;
        if (!fx)
            return;
        const vx = volumeSlider.knobX;
        if (dragging && vx !== lastVolumeX)
            fx.slide(volumeSlider.knobCenter(), vx - lastVolumeX);
        lastVolumeX = vx;
        once("release1", 1.15, () => fx.release(volumeSlider.knobCenter()));
        once("release2", 1.65, () => fx.release(volumeSlider.knobCenter()));
        const bx = brightnessSlider.knobX;
        if (bx !== lastBrightnessX)
            fx.slide(brightnessSlider.knobCenter(), bx - lastBrightnessX);
        lastBrightnessX = bx;
        once("device", 2.3, () => pickAt(deviceDots.itemAt(1)));
        once("segment", 2.8, () => pickAt(segments.itemAt(2)));
        once("on", 3.3, () => fx.toggle(areaOf(toggle), true));
        once("off", 3.9, () => fx.toggle(areaOf(toggle), false));
        once("button", 4.3, () => pickAt(buttonBox));
    }

    function areaOf(item) {
        return item.mapToItem(fxLayer, 0, 0, item.width, item.height);
    }

    // Picked by a click in the middle of `item`.
    function pickAt(item) {
        const area = areaOf(item);
        fxLayer.item.pick(area, Qt.point(area.x + area.width / 2, area.y + area.height / 2));
    }

    component LabSlider: Item {
        id: slider
        // Inline components cannot see the file's ids, so these come in.
        property var theme: null
        property Component knobComponent: null
        property Item space: null
        property real value: 0
        property color fill: slider.theme.accent
        property bool pressed: false
        // The pointer over the slider, in its coordinates, while `hovered`.
        property bool hovered: false
        property real pointerX: 0
        readonly property real knobX: slider.value * (slider.width - knob.width)
        readonly property point knobPointer: Qt.point(slider.pointerX - knob.x, slider.height / 2 - knob.y)
        onKnobPointerChanged: if (knobLoader.item && "pointer" in knobLoader.item) knobLoader.item.pointer = slider.knobPointer
        function knobCenter() {
            return knob.mapToItem(slider.space, knob.width / 2, knob.height / 2);
        }
        height: 20

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 8
            radius: 4
            color: Qt.rgba(slider.theme.surface2.r, slider.theme.surface2.g, slider.theme.surface2.b, 0.5)

            Rectangle {
                width: slider.value * parent.width
                height: parent.height
                radius: 4
                color: slider.fill
            }
        }

        Rectangle {
            id: knob
            x: slider.knobX
            anchors.verticalCenter: parent.verticalCenter
            width: slider.pressed ? 20 : 18
            height: width
            radius: width / 2
            color: knobLoader.status === Loader.Ready ? "transparent" : slider.theme.bg
            border.width: knobLoader.status === Loader.Ready ? 0 : 2
            border.color: slider.theme.accent

            Loader {
                id: knobLoader
                anchors.fill: parent
                sourceComponent: slider.knobComponent
            }

            Binding { target: knobLoader.item; property: "theme"; value: slider.theme }
            Binding { target: knobLoader.item; property: "pressed"; value: slider.pressed }
            Binding { target: knobLoader.item; property: "hovered"; value: slider.hovered }
            Binding { target: knobLoader.item; property: "travel"; value: knob.x }
        }
    }

    // ── The panel ────────────────────────────────────────────
    Item {
        id: panel
        x: 16
        y: 16
        width: 420
        height: 420
        clip: true

        Rectangle {
            anchors.fill: parent
            color: swatch.bg
        }

        Loader {
            id: backdrop
            anchors.fill: parent
            sourceComponent: root.effects && ("backdrop" in root.effects) ? root.effects.backdrop : null
        }

        Binding { target: backdrop.item; property: "theme"; value: swatch }

        Rectangle {
            id: buttonBox
            x: 11
            y: 330
            width: 38
            height: 38
            radius: 3
            color: Qt.rgba(swatch.accent.r, swatch.accent.g, swatch.accent.b, root.previewTime >= 4.3 ? 0.12 : 0)
            border.width: 1
            border.color: Qt.rgba(swatch.accent.r, swatch.accent.g, swatch.accent.b, root.previewTime >= 4.3 ? 0.45 : 0)

            Rectangle {
                anchors.centerIn: parent
                width: 18
                height: 18
                radius: 4
                color: "transparent"
                border.width: 2
                border.color: root.previewTime >= 4.3 ? swatch.accent : swatch.subtext
            }
        }

        Text {
            x: 80
            y: 22
            text: "Volume"
            color: swatch.subtext
            font.pixelSize: 12
        }

        LabSlider {
            id: volumeSlider
            theme: swatch
            knobComponent: root.knobComponent
            space: fxLayer
            x: 80
            y: 40
            width: 300
            value: root.volume
            pressed: root.dragging
            hovered: root.previewTime < 2.1
            pointerX: root.volumePointer
        }

        Repeater {
            id: deviceDots
            model: ["Speakers", "Headphones"]

            Rectangle {
                required property int index
                required property string modelData
                x: 88
                y: 84 + index * 30
                width: 14
                height: 14
                radius: 7
                border.width: 2
                border.color: swatch.accent
                color: root.device === index ? swatch.accent : "transparent"

                Text {
                    x: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData
                    color: swatch.text
                    font.pixelSize: 12
                }
            }
        }

        Rectangle {
            x: 80
            y: 160
            width: 300
            height: 30
            radius: 5
            color: Qt.rgba(swatch.overlay.r, swatch.overlay.g, swatch.overlay.b, 0.08)
            border.width: 1
            border.color: Qt.rgba(swatch.overlay.r, swatch.overlay.g, swatch.overlay.b, 0.24)

            Repeater {
                id: segments
                model: ["Off", "0.5×", "1×", "2×"]

                Rectangle {
                    required property int index
                    required property string modelData
                    x: 2 + index * 74
                    y: 2
                    width: 74
                    height: 26
                    radius: 3
                    color: root.segment === index ? Qt.rgba(swatch.accent.r, swatch.accent.g, swatch.accent.b, 0.2) : "transparent"
                    border.width: root.segment === index ? 1 : 0
                    border.color: swatch.accent

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: root.segment === parent.index ? swatch.text : swatch.subtext
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }
        }

        Rectangle {
            id: toggle
            x: 80
            y: 220
            width: 36
            height: 20
            radius: 10
            color: root.switchOn ? swatch.accent : Qt.rgba(swatch.surface2.r, swatch.surface2.g, swatch.surface2.b, 0.4)

            Rectangle {
                id: thumb
                readonly property real k: Math.min(1, (root.previewTime - root.switchAt) / 0.18)
                x: root.switchOn ? 3 + 16 * thumb.k : 19 - 16 * Math.max(0, thumb.k)
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: thumbLoader.status === Loader.Ready ? "transparent" : root.switchOn ? swatch.bg : swatch.subtext

                Loader {
                    id: thumbLoader
                    anchors.fill: parent
                    sourceComponent: root.knobComponent
                }

                Binding { target: thumbLoader.item; property: "theme"; value: swatch }
                Binding { target: thumbLoader.item; property: "checked"; value: root.switchOn }
                Binding { target: thumbLoader.item; property: "travel"; value: thumb.x }
                Binding { target: thumbLoader.item; property: "hovered"; value: root.switchHovered }
                onXChanged: if (thumbLoader.item && "pointer" in thumbLoader.item) thumbLoader.item.pointer = Qt.point(18 - thumb.x, 7)
            }
        }

        Text {
            x: 80
            y: 262
            text: "Brightness"
            color: swatch.subtext
            font.pixelSize: 12
        }

        LabSlider {
            id: brightnessSlider
            theme: swatch
            knobComponent: root.knobComponent
            space: fxLayer
            x: 80
            y: 280
            width: 300
            value: root.brightness
            hovered: root.previewTime > 1.7 && root.previewTime < 2.3
            pointerX: 230
            fill: swatch.yellow
        }

        // The effects' interactions, over the panel and taking no input.
        Loader {
            id: fxLayer
            anchors.fill: parent
            sourceComponent: root.effects && ("interactions" in root.effects) ? root.effects.interactions : null
        }

        Binding { target: fxLayer.item; property: "theme"; value: swatch }
    }

    Component.onCompleted: {
        if (fxLayer.sourceComponent === null)
            console.log("no interactions");
    }
}
