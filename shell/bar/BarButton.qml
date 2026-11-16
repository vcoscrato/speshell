import QtQuick
import qs.components
import qs.services
import "../components/Keyboard.js" as Keyboard

// A bar button, its content given by the user: square unless `text` makes it wider,
// filled on hover and while its dropdown is open, and named in a label on hover. Shows
// `iconName` and `text` itself when given them. Space or Enter clicks it while it has
// the keyboard, as it can while a dropdown is open.
Item {
    id: root

    // The bar's button size; wider with text.
    property int size: Theme.controlHeight
    // On a bottom bar: the label shows above.
    property bool labelAbove: false
    // The panel it opens, if any.
    property string panel: ""
    property bool open: false
    // Shown on hover or keyboard focus, unless the dropdown is open.
    property string label: ""
    property string iconName: ""
    // The icon's tone when its state calls for one, as a low battery's; else it follows
    // the button.
    property string tone: ""
    property color iconColor: root.tone !== "" ? Theme.toneColor(root.tone)
        : root.open ? Theme.accent
        : root.pointerInside ? Theme.text
        : Theme.subtextBright
    property string text: ""
    // Shown before `text` unless `compact`, as the date before the time; a crowded bar
    // goes compact and leaves it to the hover label.
    property string detail: ""
    property bool compact: false
    property int fontSize: Theme.fontSizeSmall
    property int fontWeight: Font.Normal
    property bool tabularDigits: false
    property int horizontalPadding: Theme.spacingSmall
    property bool pointerInside: false
    readonly property string shownText: (root.compact ? "" : root.detail) + root.text
    // How much narrower going compact made it, so the bar knows its full width.
    readonly property real compactSavings: root.visible && root.compact && root.detail !== ""
        ? root.widthFor(fullMetrics.advanceWidth) - root.implicitWidth
        : 0
    readonly property alias icon: icon
    default property alias content: contentItem.data

    // `pointer`: the MouseArea clicked, or null from the keyboard.
    signal clicked(Item pointer)
    // Scrolled a step over it: 1 up, -1 down.
    signal scrolled(int direction)
    signal rightClicked()

    // Its width with text `textWidth` wide.
    function widthFor(textWidth) {
        if (textWidth <= 0)
            return root.size;
        // The icon beside text, as sized below.
        const iconWidth = root.iconName === "" ? 0
            : (root.panel !== "" ? Theme.iconSizeMedium : Theme.iconSizeSmall) + contentRow.spacing;
        return Math.max(root.size, Math.ceil(iconWidth + textWidth) + root.horizontalPadding * 2);
    }

    implicitWidth: root.widthFor(root.shownText === "" ? 0 : textLabel.implicitWidth)
    implicitHeight: root.size
    scale: mouse.pressed ? Theme.pressScale : 1
    activeFocusOnTab: true

    Behavior on scale {
        NumberAnimation { duration: Theme.animDurationFast; easing.type: Theme.animEasing }
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.label || root.shownText
    Accessible.onPressAction: root.clicked(null)
    Keys.onPressed: event => {
        if (Keyboard.presses(event)) {
            event.accepted = true;
            root.clicked(null);
        }
    }

    TextMetrics {
        id: fullMetrics
        font: textLabel.font
        text: root.detail + root.text
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.borderRadius
        color: root.open ? Theme.selectedFill : (root.pointerInside ? Theme.cardHover : "transparent")
        border.width: root.open ? Theme.borderWidth : 0
        border.color: Theme.selectedBorder
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.spacingSmall
        visible: root.iconName !== "" || root.shownText !== ""

        AppIcon {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconName !== ""
            name: root.iconName
            // Smaller beside text, except on a panel button, which matches its neighbors.
            size: root.shownText === "" || root.panel !== "" ? Theme.iconSizeMedium : Theme.iconSizeSmall
            iconColor: root.iconColor
        }

        Label {
            id: textLabel
            anchors.verticalCenter: parent.verticalCenter
            visible: root.shownText !== ""
            text: root.shownText
            font.pixelSize: root.fontSize
            font.weight: root.fontWeight
            font.features: root.tabularDigits ? { "tnum": 1 } : {}
            color: root.open ? Theme.accent : Theme.text
        }
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }

    Tooltip {
        visible: (root.pointerInside || root.activeFocus) && !root.open && root.label !== ""
        text: root.label
        below: !root.labelAbove
        // At once, as the bar is glanced over.
        delay: 0
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: root.pointerInside = true
        onExited: root.pointerInside = false
        onCanceled: root.pointerInside = false
        onClicked: event => {
            if (event.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked(mouse);
        }
    }

    WheelSteps {
        onStepped: direction => root.scrolled(direction)
    }

    FocusRing {}
}
