pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.theme
import "../services/CalendarEvents.js" as CalendarEvents

// A month of days, starting on the locale's first day of the week, with today marked.
// The arrows or the wheel change the month; Today comes back to this one. Days with
// `marks` get a dot, and with `selectable` a click picks one.
Item {
    id: root

    property date today: new Date()
    property date selected: root.today
    property bool selectable: false
    // The dot's color by day, keyed yyyy-MM-dd.
    property var marks: ({})
    // The month shown, as its first day.
    property date month: new Date(root.today.getFullYear(), root.today.getMonth(), 1)
    readonly property bool showingToday: root.month.getFullYear() === root.today.getFullYear()
        && root.month.getMonth() === root.today.getMonth()
    // Qt.DayOfWeek, 1 (Monday) to 7 (Sunday); Date.getDay() counts Sunday as 0.
    readonly property int firstWeekday: Qt.locale().firstDayOfWeek % 7
    readonly property int leadingBlanks: (root.month.getDay() - root.firstWeekday + 7) % 7
    readonly property int dayCount: new Date(root.month.getFullYear(), root.month.getMonth() + 1, 0).getDate()
    readonly property real cellHeight: Math.max(38, Theme.fontSizeSmall * 3.4)

    implicitHeight: content.implicitHeight

    function shift(months) {
        root.month = new Date(root.month.getFullYear(), root.month.getMonth() + months, 1);
    }

    signal picked(date day)

    function goToToday() {
        root.month = new Date(root.today.getFullYear(), root.today.getMonth(), 1);
    }

    // A new day carries the calendar along when it showed the old one's month.
    onTodayChanged: {
        const previous = new Date(root.today.getTime() - 24 * 3600 * 1000);
        if (root.month.getFullYear() === previous.getFullYear() && root.month.getMonth() === previous.getMonth())
            root.goToToday();
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.shift(event.angleDelta.y > 0 ? -1 : 1)
    }

    Column {
        id: content
        width: parent.width
        spacing: Theme.spacingSmall

        Item {
            width: parent.width
            height: Theme.controlHeightSmall

            Label {
                role: "heading"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(root.month, "MMMM yyyy")
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingTiny

                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.showingToday
                    text: "Today"
                    iconName: "back"
                    compact: true
                    onClicked: root.goToToday()
                }

                HeaderButton {
                    iconName: "chevron-left"
                    tooltipText: "Previous month"
                    onClicked: root.shift(-1)
                }

                HeaderButton {
                    iconName: "chevron-right"
                    tooltipText: "Next month"
                    onClicked: root.shift(1)
                }
            }
        }

        Row {
            width: parent.width

            Repeater {
                model: 7

                delegate: Label {
                    required property int index

                    width: parent.width / 7
                    // Named as the rest of the shell's dates are; 4 January 1970 was a Sunday.
                    text: Qt.formatDate(new Date(1970, 0, 4 + (root.firstWeekday + index) % 7), "ddd").substring(0, 2)
                    horizontalAlignment: Text.AlignHCenter
                    role: "caption"
                    font.weight: Font.DemiBold
                    color: Theme.overlay
                }
            }
        }

        Grid {
            id: days
            width: parent.width
            columns: 7

            // Six weeks, whatever the month, so the calendar keeps its height.
            Repeater {
                model: 42

                delegate: Item {
                    id: cell

                    required property int index
                    readonly property int day: cell.index - root.leadingBlanks + 1
                    readonly property bool inMonth: cell.day > 0 && cell.day <= root.dayCount
                    readonly property date date: new Date(root.month.getFullYear(), root.month.getMonth(), cell.day)
                    readonly property bool isToday: root.showingToday && cell.day === root.today.getDate()
                    readonly property bool isSelected: root.selectable && cell.inMonth
                        && cell.date.toDateString() === root.selected.toDateString()
                    readonly property int weekday: (root.firstWeekday + cell.index) % 7
                    readonly property string mark: cell.inMonth ? root.marks[CalendarEvents.dateKey(cell.date)] || "" : ""

                    width: days.width / 7
                    height: root.cellHeight

                    Rectangle {
                        id: back
                        anchors.centerIn: parent
                        visible: cell.isToday || cell.isSelected || hover.hovered && root.selectable && cell.inMonth
                        width: Math.min(cell.width, cell.height) - Theme.spacingTiny
                        height: width
                        radius: Theme.borderRadius
                        color: cell.isToday ? Theme.accent : cell.isSelected ? Theme.selectedFill : Theme.controlFill
                        border.width: cell.isSelected ? Theme.borderWidth : 0
                        border.color: cell.isToday ? Theme.crust : Theme.selectedBorder
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: back.bottom
                        anchors.bottomMargin: Theme.spacingTiny
                        visible: cell.mark !== ""
                        width: 4
                        height: 4
                        radius: 2
                        color: cell.isToday ? Theme.crust : cell.mark
                    }

                    HoverHandler {
                        id: hover
                        enabled: root.selectable && cell.inMonth
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: root.selectable && cell.inMonth
                        onTapped: root.picked(cell.date)
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: cell.inMonth
                        text: cell.day
                        font.weight: cell.isToday ? Font.Bold : Font.Normal
                        font.features: { "tnum": 1 }
                        color: cell.isToday
                            ? Theme.crust
                            : (cell.weekday === 0 || cell.weekday === 6 ? Theme.subtext : Theme.text)
                    }
                }
            }
        }
    }
}
