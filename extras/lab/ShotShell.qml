import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.bar
import qs.core
import qs.services
import qs.theme

// Renders Speshell's real bar offscreen over the theme's wallpaper, once with nothing
// open (`bar`) and once with each panel in SHOTS open, or the launcher (`launcher`).
// shot.sh copies this file to the root of a copy of the tree, so `qs.*` and the shipped
// themes resolve. For each shot it saves OUT/<name>.png and logs the area to keep as
// "crop <name> x y w h".
//
// A timer and a screen recording run throughout, so the bar's chips and the panels
// that show them have something to show. Env: SHOTS (space-separated), OUT, SHOT_QUERY
// (typed into the launcher), SHOT_MEDIA=1 to show the playing track; shot.sh
// picks the theme in the data directory it gives.
ShellRoot {
    id: shell

    readonly property string out: Quickshell.env("OUT") || "/tmp"
    property var shots: []
    property int index: -1
    property var bar: null
    property var launcher: null
    property int waits: 0

    function create(path, properties) {
        const component = Qt.createComponent(path);
        if (component.status !== Component.Ready) {
            console.error(component.errorString());
            Qt.quit();
            return null;
        }
        // Never mapped: its content draws into the grabbed scene instead.
        const window = component.createObject(scene, Object.assign({
            visible: false,
            implicitWidth: scene.width,
            implicitHeight: scene.height
        }, properties));
        for (const child of window.contentItem.children.slice())
            child.parent = scene;
        return window;
    }

    function start() {
        TimerService.start(25 * 60, "Tea");
        ActivityService.publish("shot", {
            id: "screen-recording", state: "active", label: "Recording", iconName: "screen-recording",
            tone: "error", startedAt: Date.now() - 78000, actions: [{ id: "stop", label: "Stop and save" }]
        });
        shell.bar = shell.create("bar/Bar.qml", { modelData: Quickshell.screens[0] });
        // The playing track's cover is someone else's art; SHOT_MEDIA=1 keeps it.
        if (Quickshell.env("SHOT_MEDIA") !== "1")
            shell.find(scene, item => "coverButton" in item).visible = false;
        const asked = (Quickshell.env("SHOTS") || "").split(" ").filter(name => name !== "");
        shell.shots = ["bar"].concat(asked.length > 0 ? asked
            : Object.keys(PanelService.labels).filter(panel => PanelService.isSupported(panel)).concat(["launcher"]));
        shell.advance();
    }

    function advance() {
        shell.index++;
        if (shell.index >= shell.shots.length) {
            Qt.quit();
            return;
        }
        const name = shell.shots[shell.index];
        shell.bar.closeDropdown();
        if (name === "launcher") {
            shell.launcher = shell.create("core/LauncherOverlay.qml", { opened: true, presenting: true });
            LauncherService.setQuery(Quickshell.env("SHOT_QUERY") || "");
        } else if (name !== "bar") {
            const button = shell.bar.buttonFor(name);
            // The weather's button shows once the forecast arrives.
            if (PanelService.isSupported(name) && !button && shell.waits < 10) {
                shell.waits++;
                shell.index--;
                retry.restart();
                return;
            }
            shell.waits = 0;
            if (!button) {
                console.warn("shot: no panel", name, "here");
                Qt.callLater(shell.advance);
                return;
            }
            shell.bar.toggleDropdown(name, button, null);
        }
        settle.restart();
    }

    function save(name) {
        // The bar's dropdown: the one item that hosts a panel.
        const dropdown = shell.find(scene, item => "panelItem" in item && "anchorX" in item);
        let area = Qt.rect(0, 0, scene.width, scene.height);
        if (name === "launcher") {
            const width = shell.launcher.paletteWidth + Theme.spacingXL * 2;
            area = Qt.rect((scene.width - width) / 2, 0, width, scene.height * 0.8);
        } else if (dropdown && dropdown.visible) {
            const margin = Theme.spacingLarge;
            const at = dropdown.mapToItem(scene, 0, 0);
            area = Qt.rect(at.x - margin, 0, dropdown.width + margin * 2, at.y + dropdown.height + margin);
        }
        scene.grabToImage(result => {
            result.saveToFile(shell.out + "/" + name + ".png");
            console.log("crop", name, Math.max(0, Math.round(area.x)), Math.round(area.y),
                Math.round(Math.min(area.width, scene.width - area.x)), Math.round(Math.min(area.height, scene.height)));
            if (shell.launcher) {
                shell.launcher.destroy();
                shell.launcher = null;
            }
            shell.advance();
        });
    }

    // The first item under `item` that passes `test`.
    function find(item, test) {
        for (const child of item.children) {
            if (test(child))
                return child;
            const found = shell.find(child, test);
            if (found)
                return found;
        }
        return null;
    }

    // Long enough for the dropdown's entrance and the panel's first data.
    Timer {
        id: settle
        interval: 900
        onTriggered: shell.save(shell.shots[shell.index])
    }

    Timer {
        id: retry
        interval: 500
        onTriggered: shell.advance()
    }

    Timer {
        id: begin
        interval: 1500
        onTriggered: shell.start()
    }

    PanelWindow {
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "speshell-lab-shot"
        anchors { left: true; top: true }
        mask: Region {}

        Item {
            width: 1
            height: 1
            clip: true

            Item {
                id: scene
                width: 1920
                height: 1080

                Rectangle {
                    anchors.fill: parent
                    color: Theme.crust
                }

                // The theme's wallpaper, whether or not Speshell draws it.
                Image {
                    readonly property string path: ThemeService.wallpaperFor(ThemeService.themeId)

                    anchors.fill: parent
                    source: path !== "" ? "file://" + path : ""
                    fillMode: Image.PreserveAspectCrop
                }
            }
        }
    }

    Binding {
        target: Theme
        property: "textScale"
        value: ConfigService.settings.appearance.textScale
    }

    Binding {
        target: Theme
        property: "paletteOverride"
        value: ThemeService.colors
    }

    Component.onCompleted: {
        ConfigService.load();
        begin.start();
    }
}
