import QtQuick
import Quickshell
import Quickshell.Wayland

// Offscreen preview harness. An invisible 1x1 overlay surface gives Quickshell a real
// GPU context; the scene renders into textures that are saved with grabToImage.
//
// Time is virtual: each rendered frame advances the scene's `labTime` by exactly
// 1/60 s, and every second frame is captured before time moves on, so the 30 fps
// output is frame-exact however slow capturing is.
// Env: SCENE (qml file), DURATION (seconds), OUT (directory); EVERY_FRAME captures all
// 60 frames a second. With PERF set, nothing is captured and the mean real frame time
// is logged instead, from PERF_FROM seconds (at least 0.5 s, past the warm-up of
// shader compiles and image loads).
ShellRoot {
    id: lab
    readonly property real duration: Number(Quickshell.env("DURATION") || 3)
    readonly property string out: Quickshell.env("OUT") || "/tmp"
    property int frame: 0
    property bool capturing: false
    readonly property bool perf: Quickshell.env("PERF") !== null && Quickshell.env("PERF") !== ""
    // Capture all 60 frames a second instead of every second one.
    readonly property bool everyFrame: Quickshell.env("EVERY_FRAME") !== null && Quickshell.env("EVERY_FRAME") !== ""
    property real perfStart: 0
    readonly property int perfFrom: Math.max(30, Math.round(Number(Quickshell.env("PERF_FROM") || 0) * 60))

    PanelWindow {
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        // Overlay keeps frame callbacks flowing even over fullscreen windows.
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "speshell-themes-lab"
        anchors { left: true; top: true }
        mask: Region {}

        FrameAnimation {
            running: loader.status === Loader.Ready
            onTriggered: {
                if (lab.capturing)
                    return;
                if (lab.frame / 60 >= lab.duration) {
                    if (lab.perf)
                        console.log("perf:", ((Date.now() - lab.perfStart) / (lab.frame - lab.perfFrom)).toFixed(3), "ms per frame");
                    Qt.quit();
                    return;
                }
                lab.frame++;
                loader.item.labTime = lab.frame / 60;
                if (lab.frame === lab.perfFrom)
                    lab.perfStart = Date.now();
                if (lab.perf || (!lab.everyFrame && lab.frame % 2 !== 0))
                    return;
                lab.capturing = true;
                const index = lab.everyFrame ? lab.frame : lab.frame / 2;
                loader.item.grabToImage(function(result) {
                    result.saveToFile(lab.out + "/" + String(index).padStart(4, "0") + ".bmp");
                    lab.capturing = false;
                });
            }
        }

        Item {
            width: 1
            height: 1
            clip: true
            Loader {
                id: loader
                source: Quickshell.env("SCENE")
                onStatusChanged: if (status === Loader.Error) Qt.quit()
            }
        }
    }
}
