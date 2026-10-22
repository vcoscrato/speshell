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
// 60 frames a second. With PERF set to windows of lab time ("1.3-2.15", or several
// joined by commas), nothing is captured and the real time of the frames inside them
// is logged instead, as the mean of their middle half, so a stray stall or two does
// not count.
ShellRoot {
    id: lab
    readonly property real duration: Number(Quickshell.env("DURATION") || 3)
    readonly property string out: Quickshell.env("OUT") || "/tmp"
    property int frame: 0
    property bool capturing: false
    readonly property bool perf: Quickshell.env("PERF") !== null && Quickshell.env("PERF") !== ""
    // Capture all 60 frames a second instead of every second one.
    readonly property bool everyFrame: Quickshell.env("EVERY_FRAME") !== null && Quickshell.env("EVERY_FRAME") !== ""
    readonly property var perfWindows: lab.perf
        ? Quickshell.env("PERF").split(",").map(w => w.split("-").map(Number)) : []
    property real lastFrameAt: 0
    property var frameTimes: []

    function inPerfWindow(t) {
        return lab.perfWindows.some(w => t > w[0] && t <= w[1]);
    }

    function logPerf() {
        const times = lab.frameTimes.slice().sort((a, b) => a - b);
        const middle = times.slice(Math.floor(times.length / 4), Math.ceil(times.length * 3 / 4));
        const mean = middle.reduce((sum, t) => sum + t, 0) / Math.max(1, middle.length);
        console.log("perf:", mean.toFixed(3), "ms per frame over", times.length, "frames");
    }

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
                        lab.logPerf();
                    Qt.quit();
                    return;
                }
                // The time since the last frame is how long the scene took to draw at
                // the lab time it was given.
                const now = Date.now();
                if (lab.perf && lab.inPerfWindow(lab.frame / 60))
                    lab.frameTimes.push(now - lab.lastFrameAt);
                lab.lastFrameAt = now;
                lab.frame++;
                loader.item.labTime = lab.frame / 60;
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
