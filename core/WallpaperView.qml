pragma ComponentBehavior: Bound
import QtQuick
import "../services/ThemeProvider.js" as ThemeProvider

// Shows the wallpaper at `path`. On a change, the old image stays on top while the
// theme effects' wallpaper transition, or a plain fade, removes it. Both run at
// `timeScale` times normal speed; at 0 the new image replaces the old at once.
// Self-contained, so the effects lab can host it as Speshell does.
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

    property Image shown: imageA
    property Image outgoing: null
    property bool transitionRunning: false
    property Component runningTransition: null

    function change() {
        var url = ThemeProvider.fileUrl(root.path);
        if (String(root.shown.source) === url)
            return;
        root.finishTransition();
        var next = root.shown === imageA ? imageB : imageA;
        if (root.shown.status === Image.Ready) {
            root.outgoing = root.shown;
            root.outgoing.z = 1;
        } else {
            root.shown.source = "";
        }
        next.z = 0;
        root.shown = next;
        next.source = url;
        root.startWhenLoaded();
    }

    function startWhenLoaded() {
        if (root.outgoing === null || root.transitionRunning || fade.running
                || root.shown.status === Image.Loading)
            return;
        root.runningTransition = root.timeScale > 0 ? root.transition : null;
        if (root.runningTransition !== null) {
            root.transitionRunning = true;
            safetyTimer.restart();
        } else if (root.timeScale > 0) {
            fade.start();
        } else {
            root.finishTransition();
        }
    }

    function finishTransition() {
        safetyTimer.stop();
        fade.stop();
        // Detached first: clearing the source reports a status change, which
        // re-enters startWhenLoaded().
        var old = root.outgoing;
        root.outgoing = null;
        if (old !== null) {
            old.source = "";
            old.opacity = 1;
            old.z = 0;
        }
        root.transitionRunning = false;
    }

    // Optional for effects; the new image cannot change while a transition runs.
    function offerIncoming(item) {
        if ("incoming" in item)
            item.incoming = root.shown;
    }

    // Deferred so a wallpaper change sees its new effects' transition.
    onPathChanged: Qt.callLater(root.change)
    Component.onCompleted: root.change()

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

    NumberAnimation {
        id: fade
        target: root.outgoing
        property: "opacity"
        to: 0
        duration: Math.round(root.fadeDuration / Math.max(0.25, root.timeScale))
        easing.type: Easing.OutCubic
        onFinished: root.finishTransition()
    }

    // An effects transition must emit finished(); this bounds a broken one.
    Timer {
        id: safetyTimer
        interval: Math.round(5000 / Math.max(0.25, root.timeScale))
        onTriggered: root.finishTransition()
    }

    // Effects wallpaper transition (see extras/effects/README.md): draws above both
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

    Binding {
        target: transitionLoader.item
        property: "outgoing"
        value: root.outgoing
    }

    Binding {
        target: transitionLoader.item
        property: "theme"
        value: root.theme
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
