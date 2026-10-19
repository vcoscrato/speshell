pragma Singleton
import QtQuick
import Quickshell

// Loads the active theme's effects: a directory, shipped under extras/effects or
// added under <dataDir>/effects, whose Effects.qml may provide the launcher and
// wallpaper transitions, the backdrop of Speshell's surfaces, effects on its controls,
// a knob for its sliders and switches, and a clock face.
// See extras/effects/README.md.
Singleton {
    id: root

    readonly property int apiVersion: 1

    // Effects directory, from the active theme. "" disables effects.
    readonly property string dir: ThemeService.activeEffectsDir
    readonly property string name: root.dir.substring(root.dir.lastIndexOf("/") + 1)

    property var current: null

    // Power saver turns every moving part off; the still backdrop and clock face stay.
    readonly property bool enabled: PowerService.mode !== "saver"

    // Speeds from config, one per kind of effect: a multiple of normal speed; 0 turns
    // that kind off. Hosts pass them on as `timeScale`, which EffectClock follows.
    readonly property real launcherSpeed: ConfigService.settings.appearance.launcherTransitionSpeed
    readonly property real wallpaperSpeed: ConfigService.settings.appearance.wallpaperTransitionSpeed
    readonly property real controlsSpeed: ConfigService.settings.appearance.controlEffectsSpeed
    // Frames per second of effects, passed on as `frameRate`: 0 ticks with every frame
    // the display shows.
    readonly property int frameRate: PowerService.mode === "maximum" ? 0 : 60

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

    // Every part is optional.
    function optional(name) {
        return root.current && root.current[name] || null;
    }

    // A transition from the old effects may still be playing, for example the launcher
    // exit after picking a theme, so the old effects outlive their replacement briefly.
    function unload() {
        if (root.current)
            root.current.destroy(5000);
        root.current = null;
    }

    function fail(message) {
        NotificationService.addInternalNotification("effects", "Effects unavailable", message);
    }

    // Untyped, since qmllint only knows createObject() returns a QObject.
    function declaredApi(effectsObject) {
        return effectsObject.apiVersion;
    }

    function load() {
        root.unload();
        if (root.dir === "")
            return;

        var component = Qt.createComponent("file://" + root.dir + "/Effects.qml");
        if (component.status !== Component.Ready) {
            root.fail("Could not load effects '" + root.name + "': " + component.errorString().trim());
            return;
        }
        var effectsObject = component.createObject(root);
        if (!effectsObject) {
            root.fail("Could not create effects '" + root.name + "'.");
            return;
        }
        var effectsApi = root.declaredApi(effectsObject);
        if (effectsApi !== root.apiVersion) {
            effectsObject.destroy();
            root.fail("Effects '" + root.name + "' target effects API " + effectsApi
                + "; this Speshell supports " + root.apiVersion + ".");
            return;
        }
        root.current = effectsObject;
    }

    // Load synchronously so a wallpaper change sees its new effects' transition.
    onDirChanged: root.load()
}
