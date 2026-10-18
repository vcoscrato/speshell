import QtQuick
import qs.components
import qs.theme

// A bar button, its content given by the user: square unless `text` makes it wider,
// filled on hover and while its dropdown is open, and named in a label on hover. Shows
// `iconName` and `text` itself when given them.
Item {
    id: root

    // The bar's button size; wider with text.
    property int size: Theme.controlHeight
    // On a bottom bar: the label shows above.
    property bool labelAbove: false
    // The panel it opens, if any.
    property string panel: ""
    property bool open: false
    // Shown on hover, unless the dropdown is open.
    property string label: ""
    property string iconName: ""
    property color iconColor: root.open ? Theme.accent : (root.pointerInside ? Theme.text : Theme.subtextBright)
    property string text: ""
    property int fontSize: Theme.fontSizeSmall
    property int fontWeight: Font.Normal
    property bool tabularDigits: false
    property int horizontalPadding: Theme.spacingSmall
    property bool pointerInside: false
    default property alias content: contentItem.data

    // `pointer`: the MouseArea clicked, or null from the keyboard.
    signal clicked(Item pointer)
    signal wheeled(real delta)
    signal rightClicked()

    implicitWidth: root.text === ""
        ? root.size
        : Math.max(root.size, contentRow.implicitWidth + root.horizontalPadding * 2)
    implicitHeight: root.size

    Accessible.role: Accessible.Button
    Accessible.name: root.label || root.text
    Accessible.onPressAction: root.clicked(null)

    Rectangle {
        anchors.fill: parent
        radius: Theme.borderRadiusSmall
        color: root.open ? Theme.selectedFill : (root.pointerInside ? Theme.cardHover : "transparent")
        border.width: root.open ? Theme.borderWidth : 0
        border.color: Theme.selectedBorder
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.spacingSmall
        visible: root.iconName !== "" || root.text !== ""

        AppIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconName !== ""
            name: root.iconName
            size: root.text === "" ? Theme.iconSizeMedium : Theme.iconSizeSmall
            iconColor: root.iconColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            text: root.text
            textFormat: Text.PlainText
            font.pixelSize: root.fontSize
            font.family: Theme.fontFamily
            font.weight: root.fontWeight
            font.features: root.tabularDigits ? { "tnum": 1 } : {}
            color: root.open ? Theme.accent : Theme.text
        }
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }

    HoverLabel {
        visible: root.pointerInside && !root.open && root.label !== ""
        text: root.label
        above: root.labelAbove
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
        onClicked: function(event) {
            if (event.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked(mouse);
        }
        onWheel: function(event) { root.wheeled(event.angleDelta.y); }
    }
}
