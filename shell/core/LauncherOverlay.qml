pragma ComponentBehavior: Bound
// Quickshell's type info marks PanelWindow uncreatable, though QML creates it.
// qmllint disable uncreatable-type
import QtQuick
import QtQuick.Templates as T
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services

// The launcher window: the search field and results over a dimmed screen, entering and
// leaving with the theme's launcher transition.
PanelWindow {
    id: root
    property bool opened: false
    // Mapped on screen; outlives `opened` while an effects transition plays the exit.
    property bool presenting: false
    property bool focusGrabActive: false
    property var targetScreen: null
    property int selectedIndex: 0
    readonly property bool mapped: root.visible && root.backingWindowVisible
    // Latched per presentation so an effects change, e.g. from a theme picked while it
    // closes, lets the old effects finish their exit.
    property Component transition: null
    readonly property bool transitionReady: transitionLoader.status === Loader.Ready
    readonly property var results: LauncherService.results || []
    readonly property int resultCount: root.results.length
    // Badges name each result's kind, which says nothing while every result shares one.
    readonly property bool mixedKinds: root.results.some(result => (result.badge || "") !== (root.results[0].badge || ""))
    readonly property int configuredWidth: ConfigService.settings.launcher.width
    readonly property int configuredVisibleRows: ConfigService.settings.launcher.visibleRows
    readonly property int paletteWidth: Math.min(root.configuredWidth, Math.max(320, root.width - Theme.spacingXL * 2))
    readonly property int resultRowHeight: Math.max(56,
        Math.ceil((Theme.fontSizeNormal + Theme.fontSizeSmall) * 1.25)
            + Theme.spacingMedium * 2)

    readonly property int resultSpacing: Theme.spacingTiny
    readonly property int resultViewportHeight: root.configuredVisibleRows * root.resultRowHeight
        + Math.max(0, root.configuredVisibleRows - 1) * root.resultSpacing

    visible: root.presenting && root.targetScreen !== null
    screen: root.targetScreen
    color: "transparent"
    focusable: true
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    updatesEnabled: root.visible

    WlrLayershell.namespace: "speshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible && root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Click-through while the exit transition plays.
    mask: root.opened ? null : passThrough

    anchors { left: true; right: true; top: true; bottom: true }

    function clampSelected() {
        root.selectedIndex = root.resultCount <= 0
            ? 0
            : Math.max(0, Math.min(root.selectedIndex, root.resultCount - 1));
    }

    function moveSelection(delta) {
        if (root.resultCount <= 0)
            return;
        root.selectedIndex = (root.selectedIndex + delta + root.resultCount) % root.resultCount;
        resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
    }

    // Follows LauncherService.shown. Open dropdowns and the theme gallery close, so the
    // launcher has the keyboard.
    function openLauncher() {
        PanelService.dismiss();
        ThemeService.closeGallery();
        root.targetScreen = HyprlandService.focusedScreen();
        LauncherService.setQuery("");
        root.selectedIndex = 0;
        closeSafetyTimer.stop();
        if (!root.presenting)
            root.transition = EffectsService.launcherTransition;
        root.opened = true;
        root.presenting = true;
        resultsList.contentY = 0;
    }

    function closeLauncher() {
        root.opened = false;
        root.focusGrabActive = false;
        if (root.transitionReady)
            closeSafetyTimer.restart();
        else
            root.finishPresentation();
    }

    // Unmap once the exit is over; the query clears only now so the exit shows the last frame.
    function finishPresentation() {
        if (root.opened)
            return;
        closeSafetyTimer.stop();
        root.presenting = false;
        LauncherService.setQuery("");
        root.selectedIndex = 0;
    }

    function activateSelected() {
        if (root.resultCount <= 0)
            return;
        if (LauncherService.activate(root.results[root.selectedIndex]))
            LauncherService.close();
    }

    function iconPath(result) {
        if (!result || !result.iconSource)
            return "";
        return Quickshell.iconPath(result.iconSource, true);
    }

    onResultCountChanged: root.clampSelected()
    onVisibleChanged: {
        if (root.visible) {
            resultsList.contentY = 0;
            focusTimer.restart();
        } else {
            focusTimer.stop();
            root.focusGrabActive = false;
        }
    }
    onBackingWindowVisibleChanged: if (root.mapped) focusTimer.restart()

    Connections {
        target: LauncherService

        function onShownChanged() {
            if (LauncherService.shown)
                root.openLauncher();
            else
                root.closeLauncher();
        }
    }

    Region { id: passThrough }

    HyprlandFocusGrab {
        active: root.focusGrabActive && HyprlandService.running
        windows: [root]
    }

    // An effects transition must emit closingFinished(); this bounds a broken one.
    Timer {
        id: closeSafetyTimer
        interval: Math.round(2500 / Math.max(0.25, transitionLoader.timeScale))
        onTriggered: root.finishPresentation()
    }

    Timer {
        id: focusTimer
        interval: 60
        repeat: false
        onTriggered: {
            if (!root.mapped || !root.opened)
                return;
            searchField.forceActiveFocus();
            searchField.cursorPosition = searchField.text.length;
            root.focusGrabActive = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.crust, 0.30)
        opacity: root.opened ? 1 : 0

        Behavior on opacity {
            enabled: root.transitionReady
            NumberAnimation { duration: Theme.animDurationSlow; easing.type: Theme.animEasing }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: LauncherService.close()
        }
    }

    Item {
        id: launcherPanel

        // As tall as every result row makes it. Placed by that, the search field stays
        // put while the results come and go below it.
        readonly property real fullHeight: searchBox.height + paletteColumn.spacing
            + root.resultViewportHeight + Theme.spacingLarge * 2

        z: 1
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(Theme.spacingXL, Math.round((parent.height - fullHeight) / 2 - parent.height * 0.10))
        width: root.paletteWidth
        height: paletteColumn.implicitHeight + Theme.spacingLarge * 2
        clip: true

        // Centered, so every corner faces the center.
        Surface {
            anchors.fill: parent
            backdrop: true
            roundTopLeft: true
            roundTopRight: true
            roundBottomRight: true
            roundBottomLeft: true
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: function(mouse) { mouse.accepted = true; }
        }

        Column {
            id: paletteColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingLarge
            spacing: Theme.spacingMedium

            Rectangle {
                id: searchBox
                width: parent.width
                height: Math.max(48,
                    Math.ceil(Theme.fontSizeLarge * 1.35)
                        + Theme.spacingMedium * 2)
                // Field's look, at the launcher's size.
                radius: Theme.borderRadius
                color: Theme.controlFill
                border.width: Theme.borderWidth
                border.color: searchField.activeFocus ? Theme.accent : Theme.controlBorder

                AppIcon {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingMedium
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: Theme.iconSizeMedium
                    iconColor: searchField.activeFocus ? Theme.accent : Theme.subtext
                }

                TextInput {
                    id: searchField
                    anchors.left: parent.left
                    anchors.leftMargin: 44
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingMedium
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    text: LauncherService.query
                    selectByMouse: true
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true

                    onTextChanged: {
                        LauncherService.setQuery(text);
                        root.selectedIndex = 0;
                        resultsList.contentY = 0;
                    }

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            LauncherService.close();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            root.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            root.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.activateSelected();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            if (root.resultCount > 0)
                                LauncherService.complete(root.results[root.selectedIndex]);
                            event.accepted = true;
                        }
                    }
                }

                Label {
                    anchors.left: searchField.left
                    anchors.right: searchField.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search apps, calculate, ! for commands, ? for the web"
                    elide: Text.ElideRight
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSizeNormal
                    visible: searchField.text === "" && !searchField.preeditText
                }
            }

            ListView {
                id: resultsList
                readonly property bool scrollable: contentHeight > height + 1
                readonly property int scrollGutter: scrollable ? Theme.spacingMedium : 0
                width: parent.width
                height: Math.min(contentHeight, root.resultViewportHeight)
                clip: true
                visible: root.resultCount > 0
                model: root.results
                spacing: root.resultSpacing
                currentIndex: root.selectedIndex
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 3000

                T.ScrollBar.vertical: StyledScrollBar {
                    policy: resultsList.scrollable ? T.ScrollBar.AsNeeded : T.ScrollBar.AlwaysOff
                }

                delegate: Rectangle {
                    id: resultRow
                    required property int index
                    required property var modelData
                    readonly property string nativeIconPath: root.iconPath(resultRow.modelData)

                    width: resultsList.width - resultsList.scrollGutter
                    height: root.resultRowHeight
                    radius: Theme.borderRadius
                    opacity: modelData.activatable === false ? 0.72 : 1.0
                    color: resultRow.index === root.selectedIndex
                        ? Theme.selectedFill
                        : (resultMouse.containsMouse ? Theme.card : "transparent")
                    border.width: resultRow.index === root.selectedIndex ? Theme.borderWidth : 0
                    border.color: Theme.selectedBorder

                    Item {
                        id: resultIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30

                        IconImage {
                            anchors.centerIn: parent
                            width: 27
                            height: 27
                            source: resultRow.nativeIconPath
                            asynchronous: true
                            visible: resultRow.nativeIconPath !== ""
                        }

                        AppIcon {
                            anchors.centerIn: parent
                            name: resultRow.modelData.iconName || "apps"
                            size: Theme.iconSizeLarge
                            iconColor: resultRow.modelData.kind === "error"
                                ? Theme.error
                                : Theme.subtext
                            visible: resultRow.nativeIconPath === ""
                        }
                    }

                    Column {
                        anchors.left: resultIcon.right
                        anchors.leftMargin: Theme.spacingMedium
                        anchors.right: resultKind.left
                        anchors.rightMargin: Theme.spacingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Label {
                            width: parent.width
                            text: resultRow.modelData.title || ""
                            color: Theme.text
                            font.pixelSize: Theme.fontSizeNormal
                            font.bold: resultRow.modelData.kind === "calculator"
                            elide: Text.ElideRight
                        }

                        Label {
                            width: parent.width
                            text: resultRow.modelData.subtitle || ""
                            color: resultRow.modelData.kind === "error"
                                ? Theme.error
                                : Theme.subtext
                            elide: Text.ElideRight
                            visible: text !== ""
                        }
                    }

                    Label {
                        id: resultKind
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.mixedKinds ? resultRow.modelData.badge || "" : ""
                        color: resultRow.index === root.selectedIndex ? Theme.accent : Theme.overlay
                        font.pixelSize: Theme.fontSizeMicro
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }

                    MouseArea {
                        id: resultMouse
                        anchors.fill: parent
                        enabled: resultRow.modelData.activatable !== false
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: root.selectedIndex = resultRow.index
                        onClicked: {
                            root.selectedIndex = resultRow.index;
                            root.activateSelected();
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: Math.max(54,
                    Math.ceil(Theme.fontSizeNormal * 1.35)
                        + Theme.spacingLarge * 2)
                visible: root.resultCount === 0

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingSmall

                    AppIcon {
                        name: "search"
                        size: Theme.iconSizeMedium
                        iconColor: Theme.overlay
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Label {
                        text: LauncherService.emptyMessage()
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSizeNormal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Label {
                width: parent.width
                text: LauncherService.activationError
                color: Theme.error
                wrapMode: Text.WordWrap
                visible: text !== ""
            }
        }
    }

    // Effects transition (see effects/README.md): draws above the panel, and may capture it with
    // a ShaderEffectSource to animate the panel itself. Alive only while the launcher is mapped.
    Loader {
        id: transitionLoader
        // EffectClock runs at this speed and frame rate; a transition left running
        // after transitions are turned off finishes at normal speed.
        property real timeScale: EffectsService.launcherSpeed > 0 ? EffectsService.launcherSpeed : 1
        property int frameRate: EffectsService.frameRate
        z: 2
        anchors.fill: parent
        active: root.transition !== null && root.presenting
        sourceComponent: root.transition
    }

    Binding {
        target: transitionLoader.item
        property: "panel"
        value: launcherPanel
    }

    Binding {
        target: transitionLoader.item
        property: "panelRect"
        value: Qt.rect(launcherPanel.x, launcherPanel.y, launcherPanel.width, launcherPanel.height)
    }

    Binding {
        target: transitionLoader.item
        property: "active"
        value: root.opened
    }

    Binding {
        target: transitionLoader.item
        property: "theme"
        value: Theme
    }

    Connections {
        target: transitionLoader.item
        ignoreUnknownSignals: true

        function onClosingFinished() { root.finishPresentation(); }
    }
}
