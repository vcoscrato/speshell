pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import qs.components
import qs.services

// One panel under the bar button that opened it, or over it on a bottom bar, kept on
// screen. The panel sets its own width (a Card is Theme.panelWidth wide) and scrolls
// when it is taller than the screen allows. Tab walks the panel's controls, then the
// bar's buttons; Escape closes it.
Item {
    id: root

    // The bar's own rectangle, in the parent's coordinates, and whether it runs along
    // the top.
    property rect barRect: Qt.rect(0, 0, 0, 0)
    property bool atTop: true
    // The panel shown, by PanelService id, "" while closed, and the button it hangs
    // from, null to center it on the bar; both set through show().
    property string panel: ""
    property Item button: null
    // Untyped, for the properties only some panels have.
    readonly property var panelItem: panelLoader.item

    readonly property int padding: Theme.panelPadding

    signal closeRequested()
    // The button's middle, summed up its parents so it follows the button as the bar
    // lays out around it, as when a new timer joins.
    readonly property real anchorX: {
        if (!root.button)
            return root.barRect.x + root.barRect.width / 2;
        let x = root.button.width / 2;
        for (let item = root.button; item && item !== root.parent; item = item.parent)
            x += item.x;
        return x;
    }
    readonly property real maxHeight: (root.atTop
            ? root.parent.height - root.barRect.y - root.barRect.height
            : root.barRect.y)
        - Theme.spacingSmall * 2

    // Shows `panel` from `button`, or closes with "". Opening fades and slides the
    // dropdown in; switching panels swaps the content at once, in the surface's new
    // place and size, and fades it in.
    function show(panel, button) {
        if (panel === root.panel && button === root.button)
            return;
        const opening = root.panel === "";
        root.followsContent = false;
        resize.complete();
        root.button = button;
        root.panel = panel;
        // Cleared first, so another timer's panel loads anew.
        panelLoader.source = "";
        if (panel !== "") {
            panelLoader.setSource(Qt.resolvedUrl("../panels/" + root.fileFor(panel) + ".qml"), root.propertiesFor(panel));
            flickable.contentY = 0;
            // Tab starts at the panel again.
            focusScope.forceActiveFocus();
            if (opening)
                entrance.restart();
            else
                swap.restart();
        }
        Qt.callLater(() => root.followsContent = true);
    }

    // The speaker and the microphone share a panel.
    function fileFor(panel) {
        const name = panel === "microphone" ? "audio" : panel;
        return name.charAt(0).toUpperCase() + name.slice(1) + "Panel";
    }

    // What a panel takes beyond its file: the microphone's side of the audio panel, and
    // the timer of the chip it hangs from.
    function propertiesFor(panel) {
        if (panel === "audio" || panel === "microphone")
            return { output: panel === "audio" };
        if (panel === "timer")
            return { timer: (root.button as TimerChip)?.timer ?? null };
        return {};
    }

    // Moves the keyboard to the next control, or the one before.
    function tab(forward) {
        const from = root.Window.activeFocusItem ?? focusScope;
        const next = from.nextItemInFocusChain(forward);
        if (next)
            next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
    }

    // Whether `item` is part of the panel.
    function holds(item) {
        for (let parentItem = item; parentItem; parentItem = parentItem.parent) {
            if (parentItem === panelLoader)
                return true;
        }
        return false;
    }

    visible: root.panel !== ""
    x: Math.round(Math.max(Theme.spacingSmall,
        Math.min(root.parent.width - Theme.spacingSmall - root.width, root.anchorX - root.width / 2)))
    y: root.atTop
        ? root.barRect.y + root.barRect.height + Theme.spacingSmall
        : root.barRect.y - Theme.spacingSmall - root.height
    width: panelLoader.width + root.padding * 2
    height: Math.min(root.maxHeight, panelLoader.height + root.padding * 2)

    // Follows its panel's content as it grows and shrinks. A panel arriving takes its
    // size at once, whichever of it and this handler sees the change first.
    property bool followsContent: true

    Behavior on height {
        enabled: root.followsContent
        NumberAnimation {
            id: resize
            duration: Theme.animDuration
            easing.type: Theme.animEasing
        }
    }

    ParallelAnimation {
        id: entrance

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.animDurationFast
        }
        NumberAnimation {
            target: slide
            property: "y"
            from: root.atTop ? -Theme.spacingSmall : Theme.spacingSmall
            to: 0
            duration: Theme.animDuration
            easing.type: Theme.animEasing
        }
    }

    NumberAnimation {
        id: swap
        target: flickable
        property: "opacity"
        from: 0
        to: 1
        duration: Theme.animDurationFast
    }

    transform: Translate { id: slide }

    // Keeps clicks from reaching the bar's closing area behind.
    MouseArea {
        anchors.fill: parent
    }

    // A spacing off the bar, so rounded all round, as a surface away from the
    // screen's edges is.
    Surface {
        anchors.fill: parent
        backdrop: true
        rounded: true
    }

    FocusScope {
        id: focusScope

        anchors.fill: parent
        anchors.margins: root.padding
        focus: root.visible

        Keys.onEscapePressed: root.closeRequested()
        // From the start of the panel, or from a control Tab doesn't stop at, into the
        // panel's controls rather than back to the bar's.
        Keys.onTabPressed: root.tab(true)
        Keys.onBacktabPressed: root.tab(false)

        Flickable {
            id: flickable

            readonly property bool scrolls: contentHeight > height + 1

            anchors.fill: parent
            contentHeight: panelLoader.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 3000

            // In the padding beside the panel, so it never covers it.
            T.ScrollBar.vertical: StyledScrollBar {
                parent: flickable.parent
                anchors.left: flickable.right
                anchors.leftMargin: (root.padding - width) / 2
                anchors.top: flickable.top
                anchors.bottom: flickable.bottom
                policy: flickable.scrolls ? T.ScrollBar.AsNeeded : T.ScrollBar.AlwaysOff
            }

            Loader {
                id: panelLoader
                width: root.panelItem ? root.panelItem.implicitWidth : 0
            }
        }
    }

    // A timer's panel closes the dropdown once it's set.
    Connections {
        target: root.panelItem
        ignoreUnknownSignals: true

        function onDone() {
            root.closeRequested();
        }
    }

    // Scrolls the panel to the control the keyboard moves to.
    Connections {
        target: root.Window.window
        enabled: root.visible && flickable.scrolls

        function onActiveFocusItemChanged() {
            const item = root.Window.activeFocusItem;
            if (!item || item === focusScope || !root.holds(item))
                return;
            const area = item.mapToItem(flickable.contentItem, 0, 0, item.width, item.height);
            if (area.y < flickable.contentY)
                flickable.contentY = Math.max(0, area.y);
            else if (area.y + area.height > flickable.contentY + flickable.height)
                flickable.contentY = Math.min(flickable.contentHeight - flickable.height, area.y + area.height - flickable.height);
        }
    }
}
