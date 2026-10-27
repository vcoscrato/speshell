pragma ComponentBehavior: Bound
// Quickshell's type info marks PanelWindow uncreatable, though QML creates it.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services
import "../services/ThemeProvider.js" as ThemeProvider

// The theme gallery. The theme it previews fills the screen: its wallpaper behind, its
// colors on the whole shell, its name, palette, and clock face, and its wallpapers to
// pick from; the themes line up along the bottom. A move plays the theme's own
// wallpaper transition behind; quick moves wait for the keys to rest. Applying lets
// the gallery's interface go, sets the theme under its wallpaper, already the one on
// screen, and then lets that go too, so nothing goes back to the old theme.
PanelWindow {
    id: root

    // The interface shows and takes the keyboard.
    property bool opened: false
    // The wallpaper behind shows; it outlives `opened` while an applied theme settles.
    property bool backdropShown: false
    // Mapped on screen, until both have faded out.
    property bool presenting: false
    // How far closing has come: "chrome" while the interface fades, "waiting" for the
    // wallpaper behind and the desktop to settle, "backdrop" while it fades; "" open.
    property string leaving: ""
    property bool focusGrabActive: false
    property var targetScreen: null
    property string selectedId: ""
    // The wallpaper previewed, one of the selected theme's, or "" for none.
    property string wallpaperPath: ""
    // Where the arrow keys move: "themes" or "wallpapers".
    property string row: "themes"
    // What shows behind: the selection once it settles, and its theme's effects, whose
    // wallpaper transition brings it in and whose clock face shows.
    property string shownPath: ""
    property string shownDir: ""
    // The effects whose clock face shows, which follows shownDir through a fade.
    property string faceDir: ""
    // When the selection last moved, ms.
    property real lastMove: 0
    // { theme, wallpaper } to apply once the interface has faded out.
    property var pending: null
    property real wheelDelta: 0

    readonly property string query: filterInput.text.trim().toLowerCase()
    readonly property var themes: ThemeService.themes.filter(theme => root.query === ""
        || theme.name.toLowerCase().indexOf(root.query) >= 0 || theme.id.indexOf(root.query) >= 0
        || theme.effects.indexOf(root.query) >= 0)
    readonly property int selectedIndex: root.themes.findIndex(theme => theme.id === root.selectedId)
    readonly property var selected: root.selectedIndex >= 0 ? root.themes[root.selectedIndex] : null
    readonly property var wallpapers: ThemeService.wallpapers.filter(wallpaper => wallpaper.theme === root.selectedId)
    readonly property int wallpaperIndex: root.wallpapers.findIndex(wallpaper => wallpaper.path === root.wallpaperPath)
    // Wallpapers are picked only when Speshell draws them and the theme has a choice.
    readonly property bool pickingWallpapers: ThemeService.wallpaperEnabled && root.wallpapers.length > 1
    readonly property bool selectedActive: root.selectedId === ThemeService.themeId
    readonly property bool applied: root.selectedActive
        && (!ThemeService.wallpaperEnabled || root.wallpaperPath === ThemeService.wallpaper)

    readonly property int margin: Math.round(Math.max(Theme.spacingXL, Math.min(root.width, root.height) * 0.05))
    readonly property int cardWidth: Math.round(Math.max(168, Math.min(272, (root.width - root.margin * 2) / 7.5)))
    readonly property int cardHeight: Math.round(root.cardWidth * 9 / 16)
    readonly property int thumbWidth: Math.round(root.cardWidth * 0.5)

    visible: root.presenting && root.targetScreen !== null
    screen: root.targetScreen
    color: "transparent"
    focusable: true
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    updatesEnabled: root.visible

    WlrLayershell.namespace: "speshell-themes"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible && root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Click-through while it fades out.
    mask: root.opened ? null : passThrough

    anchors { left: true; right: true; top: true; bottom: true }

    // Follows ThemeService.galleryShown, starting at the theme in use.
    function open() {
        PanelService.dismiss();
        LauncherService.close();
        root.targetScreen = HyprlandService.focusedScreen();
        fadeTimer.stop();
        settleTimer.stop();
        root.leaving = "";
        root.pending = null;
        filterInput.text = "";
        root.row = "themes";
        root.select(ThemeService.themeId);
        if (ThemeService.wallpaper !== "")
            root.wallpaperPath = ThemeService.wallpaper;
        root.shownDir = ThemeService.activeEffectsDir;
        root.shownPath = root.wallpaperPath;
        // What the desktop shows already, so it arrives as is.
        backdrop.place();
        faceOut.stop();
        faceSwap.stop();
        root.faceDir = root.shownDir;
        clock.opacity = 1;
        root.opened = true;
        // Once loaded, so it arrives as the desktop under it already looks.
        root.backdropShown = !backdrop.busy;
        root.presenting = true;
    }

    // Closing without applying lets the wallpaper behind go with the interface.
    function close() {
        root.opened = false;
        root.focusGrabActive = false;
        if (root.pending === null)
            root.backdropShown = false;
        root.leaving = "chrome";
        fadeTimer.restart();
    }

    // Moves closing on as far as it can: once the interface is gone and the wallpaper
    // behind has finished its transition, applies what was picked in place; once the
    // desktop has loaded it, lets the wallpaper behind go; then unmaps.
    function leave() {
        if (root.leaving === "waiting") {
            if (root.pending !== null) {
                if (backdrop.busy)
                    return;
                const picked = root.pending;
                root.pending = null;
                if (!ThemeService.wallpaperEnabled || picked.wallpaper === ""
                        || !ThemeService.setWallpaper(picked.wallpaper, root.targetScreen))
                    ThemeService.setTheme(picked.theme, root.targetScreen);
            }
            if (ThemeService.wallpapersLoading > 0)
                return;
            if (root.backdropShown) {
                root.backdropShown = false;
                root.leaving = "backdrop";
                fadeTimer.restart();
                return;
            }
            root.leaving = "done";
        }
        if (root.leaving === "done") {
            root.leaving = "";
            root.presenting = false;
        }
    }

    function select(id) {
        root.selectedId = id;
        root.wallpaperPath = ThemeService.wallpaperFor(id);
        if (!root.pickingWallpapers)
            root.row = "themes";
    }

    // The selection moved: it shows behind at once, or, for one of a quick run of
    // moves, as a held key repeats them, once they rest, so a run does not start a
    // transition per step.
    function moved(repeated) {
        const now = Date.now();
        const quick = repeated || now - root.lastMove < settleTimer.interval;
        root.lastMove = now;
        if (quick) {
            settleTimer.restart();
            if (root.faceDir !== root.selectedDir())
                faceOut.restart();
        } else {
            root.showSelection();
        }
    }

    function selectedDir() {
        const theme = ThemeProvider.findTheme(ThemeService.themes, root.selectedId);
        return theme ? theme.effectsDir : "";
    }

    function showSelection() {
        settleTimer.stop();
        root.shownDir = root.selectedDir();
        root.shownPath = root.wallpaperPath;
        if (root.faceDir !== root.shownDir) {
            faceOut.stop();
            faceSwap.restart();
        }
    }

    // Steps through the row the keys are on, wrapping around.
    function move(delta, row, repeated) {
        if ((row || root.row) === "wallpapers" && root.pickingWallpapers) {
            const count = root.wallpapers.length;
            root.wallpaperPath = root.wallpapers[(Math.max(0, root.wallpaperIndex) + delta + count) % count].path;
        } else if (root.themes.length > 0) {
            const count = root.themes.length;
            root.select(root.themes[(Math.max(0, root.selectedIndex) + delta + count) % count].id);
        } else {
            return;
        }
        root.moved(repeated);
    }

    // A wheel or touchpad steps once per notch's worth of scrolling.
    function scroll(event, row) {
        root.wheelDelta += event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
        while (Math.abs(root.wheelDelta) >= 120) {
            root.move(root.wheelDelta > 0 ? -1 : 1, row);
            root.wheelDelta -= root.wheelDelta > 0 ? 120 : -120;
        }
    }

    // Another theme at random, and one of its wallpapers.
    function surprise() {
        const id = ThemeProvider.pickRandomTheme(root.themes, root.selectedId);
        if (id === "")
            return;
        root.select(id);
        if (ThemeService.wallpaperEnabled)
            root.wallpaperPath = ThemeProvider.pickRandom(ThemeService.wallpapers, id, "") || root.wallpaperPath;
        root.moved();
    }

    // Starts what still waits to show behind, which closing lets finish.
    function apply() {
        if (root.selected === null)
            return;
        if (!root.applied) {
            root.showSelection();
            root.pending = { theme: root.selectedId, wallpaper: root.wallpaperPath };
        }
        ThemeService.closeGallery();
    }

    function sentenceCase(text) {
        return text.charAt(0).toUpperCase() + text.substring(1);
    }

    // The selection, once filtering leaves it out, moves to the first that matches.
    onThemesChanged: {
        // From the list itself: selectedIndex may not have caught up yet.
        if (root.opened && root.themes.length > 0 && !root.themes.some(theme => theme.id === root.selectedId)) {
            root.select(root.themes[0].id);
            root.moved();
        }
    }
    onSelectedIndexChanged: if (root.selectedIndex >= 0) dock.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    onWallpaperIndexChanged: if (root.wallpaperIndex >= 0) strip.positionViewAtIndex(root.wallpaperIndex, ListView.Contain)
    onVisibleChanged: {
        if (root.visible) {
            focusTimer.restart();
        } else {
            focusTimer.stop();
            root.focusGrabActive = false;
        }
    }

    Connections {
        target: ThemeService

        function onGalleryShownChanged() {
            if (ThemeService.galleryShown)
                root.open();
            else
                root.close();
        }
    }

    // The shell wears the previewed theme's colors while the gallery shows, and until
    // the picked theme applies; closing without applying takes them back at once.
    Binding {
        target: ThemeService
        property: "previewId"
        value: root.selected ? root.selected.id : ""
        when: root.presenting && (root.opened || root.pending !== null)
    }

    Connections {
        target: ThemeService

        function onWallpapersLoadingChanged() { root.leave(); }
    }

    Connections {
        target: backdrop

        function onBusyChanged() {
            if (root.opened && !backdrop.busy)
                root.backdropShown = true;
            root.leave();
        }
    }

    Region { id: passThrough }

    HyprlandFocusGrab {
        active: root.focusGrabActive && HyprlandService.running
        windows: [root]
    }

    // Each layer's fade out.
    Timer {
        id: fadeTimer
        interval: Theme.animDuration
        onTriggered: {
            root.leaving = root.leaving === "chrome" ? "waiting" : "done";
            root.leave();
        }
    }

    // A pause between moves this long ends a quick run of them.
    Timer {
        id: settleTimer
        interval: 280
        onTriggered: root.showSelection()
    }

    Timer {
        id: focusTimer
        interval: 60
        onTriggered: {
            if (!root.visible || !root.opened)
                return;
            filterInput.forceActiveFocus();
            root.focusGrabActive = true;
        }
    }

    // The clock face hides during a quick run of moves, and swaps faces out of sight.
    NumberAnimation {
        id: faceOut
        target: clock
        property: "opacity"
        to: 0
        duration: Theme.animDurationFast
    }

    SequentialAnimation {
        id: faceSwap

        NumberAnimation {
            target: clock
            property: "opacity"
            to: 0
            duration: Theme.animDurationFast
        }
        ScriptAction {
            script: root.faceDir = root.shownDir
        }
        NumberAnimation {
            target: clock
            property: "opacity"
            to: 1
            duration: Theme.animDuration
            easing.type: Theme.animEasing
        }
    }

    WallpaperView {
        id: backdrop
        anchors.fill: parent
        opacity: root.backdropShown ? 1 : 0
        path: root.shownPath
        theme: Theme
        // Only while it shows, so a theme applied meanwhile loads nothing here.
        transition: root.presenting ? EffectsService.wallpaperTransitionIn(root.shownDir) : null
        fadeDuration: Theme.animDurationSlow
        timeScale: EffectsService.wallpaperSpeed
        frameRate: EffectsService.frameRate
        pixelRatio: root.devicePixelRatio

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
        }

        DefaultWallpaper {
            anchors.fill: parent
        }
    }

    // Everything over the wallpaper.
    Item {
        id: content
        anchors.fill: parent
        opacity: root.opened ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
        }

        WheelHandler {
            target: null
            onWheel: event => root.scroll(event, "themes")
        }

        // Scrims, so the text reads over any wallpaper.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.alpha(Theme.crust, 0.88) }
                GradientStop { position: 0.3; color: Theme.alpha(Theme.crust, 0.7) }
                GradientStop { position: 0.5; color: Theme.alpha(Theme.crust, 0.35) }
                GradientStop { position: 0.75; color: Theme.alpha(Theme.crust, 0) }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: dock.height + hints.height + root.margin * 4
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.alpha(Theme.crust, 0) }
                GradientStop { position: 0.55; color: Theme.alpha(Theme.crust, 0.72) }
                GradientStop { position: 1; color: Theme.alpha(Theme.crust, 0.92) }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.margin * 2.5
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.alpha(Theme.crust, 0.6) }
                GradientStop { position: 1; color: Theme.alpha(Theme.crust, 0) }
            }
        }

        // Header: the gallery's name, the filter typed so far, and closing.
        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: root.margin
            anchors.rightMargin: root.margin
            anchors.topMargin: Math.round(root.margin * 0.6)
            height: Theme.controlHeight

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingSmall

                AppIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "palette"
                    size: Theme.iconSizeMedium
                    iconColor: Theme.accent
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "heading"
                    text: "Themes"
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "caption"
                    text: root.query === ""
                        ? ThemeService.themes.length + " installed"
                        : root.themes.length + " of " + ThemeService.themes.length
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingSmall

                // Takes what is typed; shows once there is something.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(160, filterInput.contentWidth + Theme.spacingSmall * 3 + Theme.iconSizeSmall)
                    height: Theme.controlHeight
                    radius: Theme.borderRadius
                    color: Theme.controlFill
                    border.width: Theme.borderWidth
                    border.color: Theme.selectedBorder
                    opacity: filterInput.text !== "" ? 1 : 0

                    AppIcon {
                        id: filterIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        size: Theme.iconSizeSmall
                        iconColor: Theme.accent
                    }

                    TextInput {
                        id: filterInput
                        anchors.left: filterIcon.right
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.spacingSmall
                        anchors.rightMargin: Theme.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.onAccent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        clip: true
                        Accessible.name: "Filter themes"

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                if (filterInput.text !== "")
                                    filterInput.text = "";
                                else
                                    ThemeService.closeGallery();
                            } else if (event.key === Qt.Key_Left) {
                                root.move(-1, "", event.isAutoRepeat);
                            } else if (event.key === Qt.Key_Right) {
                                root.move(1, "", event.isAutoRepeat);
                            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Tab && root.row === "themes") {
                                if (root.pickingWallpapers)
                                    root.row = "wallpapers";
                            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                root.row = "themes";
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.apply();
                            } else {
                                return;
                            }
                            event.accepted = true;
                        }
                    }
                }

                HeaderButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.controlHeight
                    iconSize: Theme.iconSizeMedium
                    iconName: "close"
                    tooltipText: "Close"
                    onClicked: ThemeService.closeGallery()
                }
            }
        }

        // The previewed theme: what it is, its palette, and its wallpapers.
        Item {
            id: hero
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.bottom: dock.top
            anchors.leftMargin: root.margin
            anchors.rightMargin: root.margin
            anchors.bottomMargin: root.margin
            visible: root.selected !== null

            Column {
                id: info
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(Math.round(root.width * 0.42), 680)
                spacing: Theme.spacingLarge

                Column {
                    width: parent.width
                    spacing: Theme.spacingSmall

                    Label {
                        role: "section"
                        color: root.selectedActive ? Theme.accent : Theme.subtext
                        text: "Theme " + (root.selectedIndex + 1) + " of " + root.themes.length
                            + (root.selectedActive ? "  ·  In use" : "")
                    }

                    Label {
                        width: parent.width
                        role: "display"
                        font.pixelSize: Math.round(Theme.fontSizeHuge * 1.5)
                        font.weight: Font.DemiBold
                        text: root.selected ? root.selected.name : ""
                        elide: Text.ElideRight
                    }

                    Label {
                        width: parent.width
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.subtextBright
                        lineHeight: 1.15
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        text: root.selected ? root.selected.description : ""
                        visible: text !== ""
                    }
                }

                // The palette: the accent and the hues, then the surfaces from darkest
                // to the text.
                Row {
                    spacing: Theme.spacingXL

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingSmall

                        Repeater {
                            model: [Theme.accent, Theme.error, Theme.peach, Theme.warning, Theme.success,
                                Theme.teal, Theme.sky, Theme.blue, Theme.pink, Theme.rosewater]

                            delegate: Rectangle {
                                required property int index
                                required property color modelData

                                anchors.verticalCenter: parent.verticalCenter
                                width: index === 0 ? 30 : 20
                                height: width
                                radius: width / 2
                                color: modelData
                                border.width: Theme.borderWidth
                                border.color: Theme.alpha(Theme.text, 0.22)

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animDurationSlow; easing.type: Theme.animEasing }
                                }
                            }
                        }
                    }

                    ClippingRectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: ramp.width
                        height: 14
                        radius: height / 2
                        color: "transparent"
                        border.width: Theme.borderWidth
                        border.color: Theme.alpha(Theme.text, 0.22)

                        Row {
                            id: ramp

                            Repeater {
                                model: [Theme.crust, Theme.mantle, Theme.bg, Theme.card, Theme.cardHover,
                                    Theme.surface2, Theme.overlay, Theme.subtext, Theme.text]

                                delegate: Rectangle {
                                    required property color modelData

                                    width: 22
                                    height: 14
                                    color: modelData

                                    Behavior on color {
                                        ColorAnimation { duration: Theme.animDurationSlow; easing.type: Theme.animEasing }
                                    }
                                }
                            }
                        }
                    }
                }

                Label {
                    role: "caption"
                    font.pixelSize: Theme.fontSizeSmall
                    text: {
                        const theme = root.selected;
                        if (!theme)
                            return "";
                        const parts = [];
                        if (theme.effects === "")
                            parts.push("No effects");
                        else if (theme.effects !== theme.id)
                            parts.push(root.sentenceCase(theme.effects) + " effects");
                        const wallpaper = root.wallpapers[root.wallpaperIndex];
                        if (wallpaper)
                            parts.push(root.sentenceCase(wallpaper.title));
                        if (root.wallpapers.length > 1)
                            parts.push((root.wallpaperIndex + 1) + " of " + root.wallpapers.length + " wallpapers");
                        return parts.join("  ·  ");
                    }
                    visible: text !== ""
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingSmall
                    visible: root.pickingWallpapers

                    Label {
                        role: "section"
                        color: root.row === "wallpapers" ? Theme.accent : Theme.subtext
                        text: "Wallpapers"
                    }

                    ListView {
                        id: strip
                        // Room for the selection ring.
                        readonly property int ring: 3

                        width: Math.min(contentWidth, parent.width)
                        height: Math.round((root.thumbWidth - strip.ring * 2) * 9 / 16) + strip.ring * 2
                        orientation: ListView.Horizontal
                        interactive: false
                        spacing: Theme.spacingTiny
                        clip: true
                        model: root.wallpapers

                        WheelHandler {
                            target: null
                            onWheel: event => root.scroll(event, "wallpapers")
                        }

                        // As tall as the strip, the thumbnail inset by the ring, which
                        // ListView would not leave room for above and below.
                        delegate: Item {
                            id: thumb
                            required property var modelData
                            readonly property bool chosen: thumb.modelData.path === root.wallpaperPath

                            width: root.thumbWidth
                            height: strip.height

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.borderRadius + strip.ring
                                color: "transparent"
                                border.width: root.row === "wallpapers" ? 2 : 1
                                border.color: Theme.accent
                                visible: thumb.chosen
                            }

                            ClippingRectangle {
                                anchors.fill: parent
                                anchors.margins: strip.ring
                                radius: Theme.borderRadius
                                color: Theme.crust
                                opacity: thumb.chosen || thumbMouse.containsMouse ? 1 : 0.7

                                Image {
                                    anchors.fill: parent
                                    source: ThemeProvider.fileUrl(thumb.modelData.path)
                                    sourceSize: Qt.size(parent.width * root.devicePixelRatio, parent.height * root.devicePixelRatio)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }

                            MouseArea {
                                id: thumbMouse
                                anchors.fill: parent
                                anchors.margins: strip.ring
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.row = "wallpapers";
                                    root.wallpaperPath = thumb.modelData.path;
                                    root.moved();
                                }
                                onDoubleClicked: root.apply()
                            }

                            Tooltip {
                                visible: thumbMouse.containsMouse
                                text: root.sentenceCase(thumb.modelData.title)
                            }
                        }
                    }
                }

                Row {
                    spacing: Theme.spacingSmall

                    // In use, it only closes.
                    ActionButton {
                        kind: root.applied ? "secondary" : "primary"
                        checked: root.applied
                        iconName: root.applied ? "check" : ""
                        text: root.applied ? "In use"
                            : root.selectedActive ? "Apply wallpaper"
                            : "Apply theme"
                        onClicked: root.apply()
                    }

                    ActionButton {
                        iconName: "shuffle"
                        text: "Surprise me"
                        enabled: root.themes.length > 1
                        onClicked: root.surprise()
                    }
                }
            }

            ClockFace {
                id: clock
                readonly property real side: Math.round(Math.min(root.height * 0.34, root.width * 0.24, 400))

                anchors.right: parent.right
                anchors.rightMargin: Math.round(root.width * 0.06)
                anchors.verticalCenter: parent.verticalCenter
                width: side
                height: side
                ticking: root.presenting
                // Only while it shows, so a theme applied meanwhile loads nothing here.
                face: {
                    const effects = root.presenting ? EffectsService.effectsIn(root.faceDir) : null;
                    return effects ? effects.clock || null : null;
                }
            }
        }

        // The themes, each over its wallpaper in its own colors.
        ListView {
            id: dock
            // Room for the selection ring.
            readonly property int ring: 5

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: hints.top
            anchors.bottomMargin: Theme.spacingXL
            width: Math.min(contentWidth, parent.width - root.margin * 2)
            height: root.cardHeight + dock.ring * 2
            orientation: ListView.Horizontal
            interactive: false
            spacing: Theme.spacingSmall
            clip: true
            model: root.themes

            // The card inset by the ring, as for the wallpapers.
            delegate: Item {
                id: card
                required property var modelData
                readonly property var palette: Theme.mergePalette(card.modelData.colors)
                readonly property bool chosen: card.modelData.id === root.selectedId
                readonly property string wallpaper: ThemeService.wallpaperFor(card.modelData.id)

                width: root.cardWidth + dock.ring * 2
                height: dock.height
                scale: card.chosen ? 1 : cardMouse.containsMouse ? 0.97 : 0.93

                Behavior on scale {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.borderRadius + dock.ring
                    color: "transparent"
                    border.width: 2
                    border.color: card.palette.accent
                    opacity: card.chosen ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
                    }
                }

                ClippingRectangle {
                    id: tile
                    anchors.fill: parent
                    anchors.margins: dock.ring
                    radius: Theme.borderRadius
                    color: card.palette.crust
                    opacity: card.chosen || cardMouse.containsMouse ? 1 : 0.8

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
                    }

                    DefaultWallpaper {
                        anchors.fill: parent
                        crust: card.palette.crust
                        surface: card.palette.surface2
                        accent: card.palette.accent
                        visible: cardImage.status !== Image.Ready
                    }

                    Image {
                        id: cardImage
                        anchors.fill: parent
                        source: ThemeProvider.fileUrl(card.wallpaper)
                        sourceSize: Qt.size(tile.width * root.devicePixelRatio, tile.height * root.devicePixelRatio)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * 0.6
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.alpha(card.palette.crust, 0) }
                            GradientStop { position: 1; color: Theme.alpha(card.palette.crust, 0.9) }
                        }
                    }

                    Label {
                        anchors.left: parent.left
                        anchors.right: swatches.left
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.spacingSmall
                        role: "title"
                        color: card.palette.text
                        text: card.modelData.name
                        elide: Text.ElideRight
                    }

                    Row {
                        id: swatches
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.spacingSmall
                        anchors.bottomMargin: Theme.spacingSmall + 4
                        spacing: 3

                        Repeater {
                            model: [card.palette.accent, card.palette.red, card.palette.yellow,
                                card.palette.green, card.palette.blue, card.palette.pink]

                            delegate: Rectangle {
                                required property string modelData

                                width: 8
                                height: 8
                                radius: 4
                                color: modelData
                            }
                        }
                    }

                    // The theme in use.
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Theme.spacingSmall
                        width: 20
                        height: 20
                        radius: 10
                        color: card.palette.accent
                        visible: card.modelData.id === ThemeService.themeId

                        AppIcon {
                            anchors.centerIn: parent
                            name: "check"
                            size: Theme.iconSizeTiny
                            iconColor: ThemeProvider.readableOn(card.palette.accent, card.palette.text, card.palette.crust)
                        }
                    }
                }

                MouseArea {
                    id: cardMouse
                    anchors.fill: tile
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.row = "themes";
                        if (card.modelData.id !== root.selectedId) {
                            root.select(card.modelData.id);
                            root.moved();
                        }
                    }
                    onDoubleClicked: root.apply()
                }
            }
        }

        Label {
            anchors.centerIn: dock
            role: "title"
            color: Theme.subtext
            text: "No theme matches “" + filterInput.text.trim() + "”"
            visible: root.themes.length === 0
        }

        Row {
            id: hints
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(root.margin * 0.6)
            spacing: Theme.spacingXL

            Hint { keys: "← →"; label: "Themes" }
            Hint { keys: "↑ ↓"; label: "Wallpapers"; visible: root.pickingWallpapers }
            Hint { keys: "Enter"; label: "Apply" }
            Hint { keys: "Type"; label: "Filter" }
            Hint { keys: "Esc"; label: "Close" }
        }
    }

    // A key and what it does.
    component Hint: Row {
        id: hint

        property string keys: ""
        property string label: ""

        spacing: Theme.spacingSmall

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: keyLabel.implicitWidth + Theme.spacingSmall * 2
            height: Theme.controlHeightSmall
            radius: Theme.borderRadius
            color: Theme.controlFill
            border.width: Theme.borderWidth
            border.color: Theme.controlBorder

            Label {
                id: keyLabel
                anchors.centerIn: parent
                role: "caption"
                color: Theme.text
                font.weight: Font.Medium
                text: hint.keys
            }
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            role: "caption"
            text: hint.label
        }
    }
}
