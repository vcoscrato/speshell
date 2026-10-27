import QtQuick
import qs.services

// The theme effects' interactions over `host`: small effects where the user drags a
// slider, flips a switch, or picks something inside it. Fill the host and stack it
// above the host's content; it takes no input.
Item {
    id: root

    required property Item host
    property bool presented: false

    // Untyped, so the effects' functions can be called on it.
    readonly property var interactions: effectsLoader.item

    // Whether `item` is part of the host; popups and other windows are not.
    function holds(item) {
        for (var parentItem = item; parentItem; parentItem = parentItem.parent) {
            if (parentItem === root.host)
                return true;
        }
        return false;
    }

    function areaOf(item) {
        return item.mapToItem(root, 0, 0, item.width, item.height);
    }

    // Where `pointer` was clicked, so a pick starts under the pointer rather than in the
    // middle of a wide control; the middle of `area` for a pick from the keyboard.
    function pointOf(pointer, area) {
        if (pointer)
            return pointer.mapToItem(root, pointer.mouseX, pointer.mouseY);
        return Qt.point(area.x + area.width / 2, area.y + area.height / 2);
    }

    Loader {
        id: effectsLoader

        // EffectClock runs at this speed and frame rate.
        property real timeScale: EffectsService.controlsSpeed
        property int frameRate: EffectsService.frameRate

        anchors.fill: parent
        enabled: false
        active: root.presented && EffectsService.interactions !== null
        sourceComponent: EffectsService.interactions
    }

    Binding {
        target: effectsLoader.item
        property: "theme"
        value: Theme
    }

    Connections {
        target: EffectsService
        enabled: effectsLoader.status === Loader.Ready

        function onKnobMoved(knob, dx) {
            if (root.holds(knob))
                root.interactions.slide(knob.mapToItem(root, knob.width / 2, knob.height / 2), dx);
        }

        function onKnobReleased(knob) {
            if (root.holds(knob))
                root.interactions.release(knob.mapToItem(root, knob.width / 2, knob.height / 2));
        }

        function onPicked(target, pointer) {
            if (root.holds(target)) {
                var area = root.areaOf(target);
                root.interactions.pick(area, root.pointOf(pointer, area));
            }
        }

        function onSwitched(control, on) {
            if (root.holds(control))
                root.interactions.toggle(root.areaOf(control), on);
        }
    }
}
