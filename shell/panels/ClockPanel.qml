pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services

// The clock panel: the theme's clock face over the date, beside the month.
Item {
    id: root

    property bool presented: false
    readonly property int columnGap: Theme.spacingXL

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    Row {
        id: content
        spacing: root.columnGap

        Column {
            id: clockColumn
            spacing: Theme.spacingMedium

            ClockFace {
                id: face
                anchors.horizontalCenter: parent.horizontalCenter
                width: calendar.height - dateText.height - clockColumn.spacing
                height: width
                ticking: root.presented
            }

            Label {
                id: dateText
                role: "heading"
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(face.now, "dddd, d MMMM")
            }
        }

        MonthCalendar {
            id: calendar
            width: Theme.panelWidth
            today: face.now
        }
    }
}
