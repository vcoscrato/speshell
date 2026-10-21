pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services
import qs.theme
import "../components/Format.js" as Format
import "../services/CalendarEvents.js" as CalendarEvents

// A new event, or a change to `event`: its title, times or all day, place, and
// calendar. It starts on `day`, which picking another in the month above moves, and
// keeps the days an event runs. Enter saves, Escape leaves; an event can be deleted
// from here, a repeating one also alone.
Column {
    id: root

    property var event: null
    property date day: new Date()
    property bool allDay: root.event ? root.event.allDay : false
    // The days from its start day to its end's; an all-day event ends the day after its last.
    property int endDays: root.event ? CalendarEvents.endDays(root.event) : 0
    property string calendarId: root.event ? root.event.calendarId
        : CalendarService.writableCalendars.length > 0 ? CalendarService.writableCalendars[0].id : ""
    property string errorText: ""
    property bool busy: false
    property bool confirmingDelete: false
    readonly property bool canSave: title.text.trim() !== "" && root.calendarId !== "" && !root.busy

    signal closed()

    spacing: Theme.spacingSmall

    function save() {
        if (!root.canSave)
            return;
        root.busy = true;
        root.errorText = "";
        CalendarService.save(root.event, {
            title: title.text,
            day: root.day,
            allDay: root.allDay,
            startText: start.text,
            endText: end.text,
            endDays: root.endDays,
            location: place.text,
            calendarId: root.calendarId
        }, root.finish);
    }

    function remove(onlyThis) {
        root.busy = true;
        root.errorText = "";
        CalendarService.remove(root.event, onlyThis, root.finish);
    }

    function finish(error) {
        root.busy = false;
        root.confirmingDelete = false;
        if (error === "")
            root.closed();
        else
            root.errorText = error;
    }

    // The next hour today, or the morning another day.
    function suggestStart() {
        const now = new Date();
        const today = root.day.toDateString() === now.toDateString();
        start.text = today && now.getHours() < 23 ? (now.getHours() + 1) + ":00" : "9:00";
    }

    // Hidden fields forget their text: an event made timed again starts afresh.
    // A day off made timed ends the day it starts.
    onAllDayChanged: {
        if (!root.allDay && start.text === "")
            root.suggestStart();
        if (!root.allDay && root.endDays === 1)
            root.endDays = 0;
    }

    Component.onCompleted: {
        if (root.event) {
            title.text = root.event.title;
            place.text = root.event.location;
            if (!root.event.allDay) {
                start.text = Format.time(new Date(root.event.start));
                end.text = Format.time(new Date(root.event.end));
            }
        } else {
            root.suggestStart();
        }
        title.focusInput();
    }

    Field {
        id: title
        placeholder: root.event ? "Title" : "New event"
        onAccepted: root.save()
        onCancelled: root.closed()
    }

    Item {
        width: parent.width
        height: Theme.controlHeight

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSmall

            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: root.allDay
                tooltipText: "All day"
                onToggled: newState => root.allDay = newState
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "All day"
            }

            Item { width: Theme.spacingSmall; height: 1 }

            Field {
                id: start
                width: 84
                visible: !root.allDay
                placeholder: "9:00"
                onAccepted: root.save()
                onCancelled: root.closed()
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.allDay
                text: "–"
                color: Theme.subtext
            }

            Field {
                id: end
                width: 84
                visible: !root.allDay
                placeholder: "An hour"
                onAccepted: root.save()
                onCancelled: root.closed()
            }
        }

        // An event stays in its calendar; a new one can go in any you can write to.
        SelectMenu {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.event === null && CalendarService.writableCalendars.length > 1
            options: CalendarService.writableCalendars.map(calendar => ({ value: calendar.id, label: calendar.name }))
            currentValue: root.calendarId
            onValueSelected: value => root.calendarId = value
        }
    }

    Field {
        id: place
        iconName: "location"
        placeholder: "Place"
        onAccepted: root.save()
        onCancelled: root.closed()
    }

    Label {
        role: "caption"
        width: parent.width
        visible: root.allDay ? root.endDays > 1 : root.endDays > 0
        text: "Ends " + Qt.formatDate(new Date(root.day.getFullYear(), root.day.getMonth(),
            root.day.getDate() + root.endDays - (root.allDay ? 1 : 0)), "dddd, d MMMM")
    }

    Label {
        role: "caption"
        width: parent.width
        wrapMode: Text.Wrap
        visible: root.event !== null && root.event.recurring
        text: "This event repeats: changes reach every time it happens."
    }

    Label {
        role: "caption"
        width: parent.width
        wrapMode: Text.Wrap
        visible: root.errorText !== ""
        text: root.errorText
        color: Theme.error
    }

    Item {
        width: parent.width
        height: Theme.controlHeight

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSmall
            visible: root.event !== null

            ActionButton {
                visible: !root.confirmingDelete
                enabled: !root.busy
                text: "Delete"
                iconName: "trash"
                kind: "danger"
                onClicked: root.confirmingDelete = true
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.confirmingDelete
                text: root.event !== null && root.event.recurring ? "Delete" : "Delete this event?"
            }

            ActionButton {
                visible: root.confirmingDelete && root.event.recurring
                enabled: !root.busy
                text: "Only this one"
                kind: "danger"
                onClicked: root.remove(true)
            }

            ActionButton {
                visible: root.confirmingDelete
                enabled: !root.busy
                text: root.event !== null && root.event.recurring ? "Every one" : "Delete"
                kind: "danger"
                onClicked: root.remove(false)
            }

            ActionButton {
                visible: root.confirmingDelete
                text: "Keep"
                onClicked: root.confirmingDelete = false
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSmall
            visible: !root.confirmingDelete

            ActionButton {
                visible: root.event !== null && root.event.url !== ""
                text: "Open"
                tooltipText: "Open in its calendar"
                onClicked: Qt.openUrlExternally(root.event.url)
            }

            ActionButton {
                text: "Cancel"
                onClicked: root.closed()
            }

            ActionButton {
                text: root.busy ? "Saving…" : "Save"
                kind: "primary"
                enabled: root.canSave
                onClicked: root.save()
            }
        }
    }
}
