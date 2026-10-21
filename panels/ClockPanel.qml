pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services
import qs.theme

// The clock panel: the theme's clock face over the date, beside the month, and with
// Dux Calendar installed, the picked day's events under them.
Item {
    id: root

    property bool presented: false
    property date now: new Date()
    property date selected: new Date()
    readonly property int columnGap: Theme.spacingXL
    // Each day's dot takes its first event's color.
    readonly property var marks: {
        const marks = {};
        for (const key in CalendarService.days) {
            const shown = CalendarService.days[key].find(event => !event.declined);
            if (shown)
                marks[key] = CalendarService.color(shown);
        }
        return marks;
    }

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    // Next second, or next minute when the face keeps still.
    function schedule() {
        tick.stop();
        if (!root.presented)
            return;
        root.now = new Date();
        const next = new Date(root.now.getTime());
        next.setMilliseconds(0);
        next.setSeconds(Theme.motion ? next.getSeconds() + 1 : 60);
        tick.interval = Math.max(20, next.getTime() - Date.now());
        tick.start();
    }

    onPresentedChanged: {
        root.selected = new Date();
        agenda.close();
        root.schedule();
    }
    Component.onCompleted: root.schedule()

    Connections {
        target: Theme

        function onMotionChanged() { root.schedule(); }
    }

    Timer {
        id: tick
        onTriggered: root.schedule()
    }

    // The calendar loads the days this panel shows, while it shows.
    Binding {
        target: CalendarService
        property: "watching"
        value: true
        when: root.presented
    }

    Binding {
        target: CalendarService
        property: "month"
        value: calendar.month
        when: root.presented
    }

    Binding {
        target: CalendarService
        property: "day"
        value: root.selected
        when: root.presented
    }

    Column {
        id: content
        spacing: Theme.spacingLarge

        Row {
            id: panes
            spacing: root.columnGap

            Column {
                id: clockColumn
                spacing: Theme.spacingMedium

                ClockFace {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: calendar.height - dateText.height - clockColumn.spacing
                    height: width
                    hours: root.now.getHours()
                    minutes: root.now.getMinutes()
                    seconds: root.now.getSeconds()
                    running: Theme.motion
                }

                Label {
                    id: dateText
                    role: "heading"
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(root.now, "dddd, d MMMM")
                }
            }

            MonthCalendar {
                id: calendar
                width: Theme.panelWidth
                today: root.now
                selected: root.selected
                selectable: agenda.showsEvents
                marks: root.marks
                onPicked: day => root.selected = day
            }
        }

        DayAgenda {
            id: agenda
            width: panes.width
            visible: CalendarService.installed
            day: root.selected
            now: root.now
        }
    }
}
