pragma ComponentBehavior: Bound
import QtQuick
import "../services/ThemeProvider.js" as ThemeProvider

// Shows the wallpaper at `path`, over its children while there is none. On a change,
// the old image, or the children, stay on top while the theme effects' wallpaper
// transition, or a plain fade, removes them; so the first wallpaper after startup
// arrives the same way. Both run at `timeScale` times normal speed; at 0 the new
// image replaces the old at once. A change while a transition plays freezes the frame
// on screen and carries that away instead, so nothing jumps; place() shows the path at
// once instead. Self-contained, so the dev scenes can host it as Speshell does.
Item {
    id: root

    property string path: ""
    // The current effects' wallpaper transition; read when a change starts.
    property Component transition: null
    // The palette the transition draws in, as Theme.qml names it.
    property var theme: null
    // The plain fade's length at normal speed, ms.
    property int fadeDuration: 350
    property real timeScale: 1
    // Frames per second of the effects transition.
    property int frameRate: 60
    property real pixelRatio: 1
    // What shows without a wallpaper, such as a default one. Opaque, since the
    // new image draws beneath it while it goes away.
    default property alias fallback: fallbackLayer.data
    // The new image is still loading.
    readonly property bool loading: root.shown.status === Image.Loading
    // Something is changing on screen: a capture, a load, or a transition.
    readonly property bool busy: root.outgoing !== null || root.capturing

    property Image shown: imageA
    // The old image, fallbackLayer, or a frozen frame.
    property Item outgoing: null
    property bool transitionRunning: false
    property Component runningTransition: null
    // The next change shows its image at once.
    property bool placing: false
    // Freezing the frame on screen, which takes a frame or two.
    property bool capturing: false
    property ShaderEffectSource freezing: null
    property int framesToCapture: 0

    // Shows `path` without a transition, keeping what is on screen until it loads.
    function place() {
        root.placing = true;
        root.change();
    }

    function change() {
        var url = ThemeProvider.fileUrl(root.path);
        if (root.capturing)
            return;
        // Placing cuts a transition short, leaving its new image.
        if (root.placing && root.transitionRunning)
            root.finishTransition();
        if (String(root.shown.source) === url) {
            // Shown, or loading to show; placing ends once nothing is left to replace.
            if (root.outgoing === null)
                root.placing = false;
            return;
        }
        if (root.transitionRunning) {
            root.capture();
            return;
        }
        if (root.outgoing !== null) {
            // Still loading the last one: load this one in its place.
            root.shown.source = url;
            root.startWhenLoaded();
            return;
        }
        var next = root.shown === imageA ? imageB : imageA;
        if (root.shown.status === Image.Ready) {
            root.outgoing = root.shown;
        } else {
            root.shown.source = "";
            if (url !== "")
                root.outgoing = fallbackLayer;
        }
        root.swapIn(next, url);
    }

    function swapIn(next, url) {
        if (root.outgoing !== null)
            root.outgoing.z = 1;
        next.z = 0;
        root.shown = next;
        next.source = url;
        root.startWhenLoaded();
    }

    // Freezes the frame on screen, in the freeze the running transition is not
    // carrying away, to carry it away in turn once the next frame shows it.
    function capture() {
        root.freezing = root.outgoing === freezeA ? freezeB : freezeA;
        root.freezing.visible = true;
        root.freezing.scheduleUpdate();
        root.framesToCapture = 2;
        root.capturing = true;
        captureTimer.restart();
    }

    function finishCapture() {
        if (!root.capturing)
            return;
        captureTimer.stop();
        root.capturing = false;
        var frozen = root.freezing;
        root.freezing = null;
        root.finishTransition();
        // The frame covers the image under it, which the next one replaces.
        root.outgoing = frozen;
        var next = root.shown === imageA ? imageB : imageA;
        root.shown.source = "";
        root.swapIn(next, ThemeProvider.fileUrl(root.path));
    }

    function startWhenLoaded() {
        if (root.outgoing === null || root.transitionRunning || root.capturing
                || root.shown.status === Image.Loading)
            return;
        if (root.placing || root.timeScale <= 0) {
            root.placing = false;
            root.finishTransition();
            return;
        }
        root.runningTransition = root.transition ?? (root.fadeDuration > 0 ? fadeTransition : null);
        if (root.runningTransition === null) {
            root.finishTransition();
            return;
        }
        root.transitionRunning = true;
        safetyTimer.restart();
    }

    function finishTransition() {
        safetyTimer.stop();
        // Detached first: clearing the source reports a status change, which
        // re-enters startWhenLoaded().
        var old = root.outgoing;
        root.outgoing = null;
        root.transitionRunning = false;
        if (old === freezeA || old === freezeB)
            old.visible = false;
        else if (old === fallbackLayer)
            old.z = -1;
        else if (old !== null)
            (old as Image).source = "";
        if (old !== null && old !== fallbackLayer)
            old.z = 0;
    }

    // Optional for effects; the new image cannot change while a transition runs.
    function offerIncoming(item) {
        if ("incoming" in item)
            item.incoming = root.shown;
    }

    // Deferred so a wallpaper change sees its new effects' transition.
    onPathChanged: Qt.callLater(root.change)
    Component.onCompleted: root.change()

    // Everything a frame shows, but the frozen frames themselves.
    Item {
        id: stage
        anchors.fill: parent

        Item {
            id: fallbackLayer
            anchors.fill: parent
            z: -1
        }

        Image {
            id: imageA
            anchors.fill: parent
            sourceSize: Qt.size(root.width * root.pixelRatio, root.height * root.pixelRatio)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            onStatusChanged: root.startWhenLoaded()
        }

        Image {
            id: imageB
            anchors.fill: parent
            sourceSize: imageA.sourceSize
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            onStatusChanged: root.startWhenLoaded()
        }

        // Effects wallpaper transition (see effects/README.md): draws above both
        // images and must hide the outgoing one, for example through a ShaderEffectSource
        // with hideSource.
        Loader {
            id: transitionLoader
            // EffectClock runs at this speed and frame rate; a transition left running
            // after transitions are turned off finishes at normal speed.
            property real timeScale: root.timeScale > 0 ? root.timeScale : 1
            property int frameRate: root.frameRate
            z: 2
            anchors.fill: parent
            active: root.transitionRunning && root.runningTransition !== null
            sourceComponent: root.runningTransition
        }
    }

    // Two, so the one a transition is carrying away can be frozen into the other.
    // Each holds its texture only while it shows.
    ShaderEffectSource {
        id: freezeA
        anchors.fill: parent
        z: 3
        visible: false
        sourceItem: freezeA.visible ? stage : null
        live: false
    }

    ShaderEffectSource {
        id: freezeB
        anchors.fill: parent
        z: 3
        visible: false
        sourceItem: freezeB.visible ? stage : null
        live: false
    }

    // Without effects, or with them off: the old image fades out.
    Component {
        id: fadeTransition

        Item {
            id: fade

            property Item outgoing: null
            signal finished()

            ShaderEffectSource {
                anchors.fill: parent
                sourceItem: fade.outgoing
                hideSource: true
                live: false

                NumberAnimation on opacity {
                    from: 1
                    to: 0
                    duration: Math.round(root.fadeDuration / Math.max(0.25, root.timeScale))
                    easing.type: Easing.OutCubic
                    onFinished: fade.finished()
                }
            }
        }
    }

    // The frozen frame shows once the window has drawn it, two frames on to be sure.
    Connections {
        target: root.Window.window
        enabled: root.capturing

        function onFrameSwapped() {
            root.framesToCapture--;
            if (root.framesToCapture <= 0)
                Qt.callLater(root.finishCapture);
        }
    }

    // A window that draws nothing, such as an unmapped one, still moves on.
    Timer {
        id: captureTimer
        interval: 250
        onTriggered: root.finishCapture()
    }

    // An effects transition must emit finished(); this bounds a broken one.
    Timer {
        id: safetyTimer
        interval: Math.round(5000 / Math.max(0.25, root.timeScale))
        onTriggered: root.finishTransition()
    }

    Binding {
        target: transitionLoader.item
        property: "outgoing"
        value: root.outgoing
    }

    Binding {
        target: transitionLoader.item
        property: "theme"
        value: root.theme
        when: transitionLoader.item !== null && "theme" in transitionLoader.item
    }

    Connections {
        target: transitionLoader

        function onLoaded() { root.offerIncoming(transitionLoader.item); }
    }

    Connections {
        target: transitionLoader.item
        ignoreUnknownSignals: true

        function onFinished() { root.finishTransition(); }
    }
}
