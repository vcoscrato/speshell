pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.theme

// The clock panel: the theme's clock face over the date, beside the month.
Item {
    id: root

    property bool presented: false
    property date now: new Date()
    readonly property int columnGap: Theme.spacingXL

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

    onPresentedChanged: root.schedule()
    Component.onCompleted: root.schedule()

    Connections {
        target: Theme

        function onMotionChanged() { root.schedule(); }
    }

    Timer {
        id: tick
        onTriggered: root.schedule()
    }

    Row {
        id: content
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
        }
    }
}
