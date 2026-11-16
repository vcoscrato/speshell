pragma Singleton
import QtQuick
import Quickshell

// Loads the active theme's effects: a directory, shipped under effects/ or
// added under <dataDir>/effects, whose Effects.qml may provide the launcher and
// wallpaper transitions, the backdrop of Speshell's surfaces, effects on its controls,
// a knob for its sliders and switches, and a clock face.
// See effects/README.md.
Singleton {
    id: root

    readonly property int apiVersion: 1

    // Effects directory, from the active theme. "" disables effects.
    readonly property string dir: ThemeService.activeEffectsDir

    // Effects objects by directory, each loaded once and kept: the active theme's, and
    // those the theme gallery previews. A transition from the last active ones may still
    // be playing, such as the launcher's exit after picking a theme.
    readonly property var loaded: ({})
    readonly property var current: root.effectsIn(root.dir)

    // Power saver turns every moving part off; the still backdrop and clock face stay.
    readonly property bool enabled: PowerService.mode !== "saver"

    // Speeds from config, one per kind of effect: a multiple of normal speed; 0 turns
    // that kind off. Hosts pass them on as `timeScale`, which EffectClock follows.
    readonly property real launcherSpeed: ConfigService.settings.appearance.launcherTransitionSpeed
    readonly property real wallpaperSpeed: ConfigService.settings.appearance.wallpaperTransitionSpeed
    readonly property real controlsSpeed: ConfigService.settings.appearance.controlEffectsSpeed
    // Frames per second of effects, passed on as `frameRate`: 0 ticks with every frame
    // the display shows. Balanced halves them on battery.
    readonly property int frameRate: PowerService.mode === "maximum" ? 0 : (PowerService.onBattery ? 30 : 60)

    readonly property Component launcherTransition: root.enabled && root.launcherSpeed > 0
        ? root.optional("launcherTransition") : null
    readonly property Component wallpaperTransition: root.enabled && root.wallpaperSpeed > 0
        ? root.optional("wallpaperTransition") : null
    // Still, so it stays with every effect off.
    readonly property Component backdrop: root.optional("backdrop")
    readonly property Component interactions: root.enabled && root.controlsSpeed > 0
        ? root.optional("interactions") : null
    // The thumb of sliders and switches; moved only by the hand, so it stays with
    // control effects off. Power saver uses the plain thumb, which never animates.
    readonly property Component knob: root.enabled ? root.optional("knob") : null
    // The clock panel's face. It stays in power saver, told to keep still.
    readonly property Component clock: root.optional("clock")

    // Controls report the user's hand on them here; InteractionsLayer passes these on
    // to the effects' interactions. `knob` is the thumb that moved `dx` px or was let go,
    // `target` what was picked, `pointer` the MouseArea clicked to pick it (null from the
    // keyboard), and `control` the switch turned on or off.
    signal knobMoved(Item knob, real dx)
    signal knobReleased(Item knob)
    signal picked(Item target, Item pointer)
    signal switched(Item control, bool on)

    // Tells a knob that follows the pointer (it declares `pointer`) where the pointer is
    // over its control, given by `area`'s `mouse`, in the knob's own coordinates.
    // Untyped, since qmllint only knows a Loader's item as a QObject.
    function pointKnob(knobItem, area, mouse) {
        if (knobItem && "pointer" in knobItem)
            knobItem.pointer = area.mapToItem(knobItem, mouse.x, mouse.y);
    }

    // Tells a knob on a switch that asks (it declares `switchArea`) the whole switch, as
    // `area` returns it in the knob's own coordinates, kept up to date as it moves.
    function placeKnobOnSwitch(knobItem, area) {
        if (knobItem && "switchArea" in knobItem)
            knobItem.switchArea = Qt.binding(area);
    }

    // The wallpaper transition of the effects in `dir`, as wallpaperTransition is the
    // active ones'.
    function wallpaperTransitionIn(dir) {
        const effects = root.enabled && root.wallpaperSpeed > 0 ? root.effectsIn(dir) : null;
        return effects ? effects.wallpaperTransition || null : null;
    }

    // Every part is optional.
    function optional(name) {
        return root.current && root.current[name] || null;
    }

    function fail(message) {
        NotificationService.addInternalNotification("effects", "Effects unavailable", message);
    }

    // Untyped, since qmllint only knows createObject() returns a QObject.
    function declaredApi(effectsObject) {
        return effectsObject.apiVersion;
    }

    // The effects object in `dir`, or null when it fails to load, which it reports.
    function create(dir) {
        const name = dir.substring(dir.lastIndexOf("/") + 1);
        const component = Qt.createComponent("file://" + dir + "/Effects.qml");
        if (component.status !== Component.Ready) {
            root.fail("Could not load effects '" + name + "': " + component.errorString().trim());
            return null;
        }
        const effectsObject = component.createObject(root);
        if (!effectsObject) {
            root.fail("Could not create effects '" + name + "'.");
            return null;
        }
        const effectsApi = root.declaredApi(effectsObject);
        if (effectsApi !== root.apiVersion) {
            effectsObject.destroy();
            root.fail("Effects '" + name + "' target effects API " + effectsApi
                + "; this Speshell supports " + root.apiVersion + ".");
            return null;
        }
        return effectsObject;
    }

    // The effects in `dir`, loaded the first time they are asked for, so a wallpaper change
    // sees its new effects' transition at once. null for none, or ones that failed.
    function effectsIn(dir) {
        if (dir === "")
            return null;
        // Filled in place, so reading it from a binding does not loop.
        if (!(dir in root.loaded))
            root.loaded[dir] = root.create(dir);
        return root.loaded[dir];
    }
}
