pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services
import qs.theme
import "../components/Format.js" as Format

// One day's events from your calendars: each with its time and place and a Join for a
// meeting not yet over. Click one to change it, or + for a new one; until Dux Calendar
// has an account, what connects one.
Column {
    id: root

    property date day: new Date()
    property date now: new Date()
    // The event the form changes; adding opens it empty.
    property var editing: null
    property bool adding: false
    // The day the form's event starts on: its own, or the one picked; picking another moves it there.
    property date formDay: new Date()
    readonly property bool formOpen: root.adding || root.editing !== null
    readonly property bool showsEvents: CalendarService.ready && CalendarService.signedIn
    readonly property var events: CalendarService.eventsOn(root.day)

    spacing: Theme.spacingTiny

    function close() {
        root.adding = false;
        root.editing = null;
    }

    function create() {
        root.formDay = root.day;
        root.adding = true;
    }

    function open(event) {
        if (!event.readOnly) {
            root.formDay = new Date(event.start);
            root.adding = false;
            root.editing = event;
        } else if (event.url !== "") {
            Qt.openUrlExternally(event.url);
        }
    }

    function dayName(date) {
        const today = new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate());
        const days = Math.round((new Date(date.getFullYear(), date.getMonth(), date.getDate()) - today) / 86400000);
        return days === 0 ? "Today" : days === 1 ? "Tomorrow" : days === -1 ? "Yesterday" : Qt.formatDate(date, "dddd, d MMMM");
    }

    // An event's hours on this day: those of a day it only starts or ends on are open-ended.
    function hours(event) {
        const first = new Date(root.day.getFullYear(), root.day.getMonth(), root.day.getDate()).getTime();
        const next = new Date(root.day.getFullYear(), root.day.getMonth(), root.day.getDate() + 1).getTime();
        const before = event.start < first;
        const after = event.end > next;
        if (event.allDay || before && after)
            return "All day";
        if (before)
            return "Until " + Format.time(new Date(event.end));
        if (after)
            return "From " + Format.time(new Date(event.start));
        return Format.time(new Date(event.start)) + " – " + Format.time(new Date(event.end));
    }

    Item {
        width: parent.width
        height: Theme.controlHeightSmall

        Label {
            role: "section"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.adding ? "New event · " + root.dayName(root.formDay)
                : root.editing ? "Edit event · " + root.dayName(root.formDay)
                : root.showsEvents ? root.dayName(root.day) : "Calendar"
        }

        Label {
            role: "caption"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.formOpen
            text: "Pick a day above to move it"
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingTiny
            visible: root.showsEvents && !root.formOpen

            Label {
                role: "caption"
                anchors.verticalCenter: parent.verticalCenter
                visible: CalendarService.syncing || CalendarService.syncedAt > 0
                text: CalendarService.syncing ? "Syncing…" : "Synced " + Format.ago(CalendarService.syncedAt, root.now.getTime())
            }

            HeaderButton {
                iconName: "refresh"
                tooltipText: "Sync now"
                busy: CalendarService.syncing
                onClicked: CalendarService.refresh()
            }

            HeaderButton {
                iconName: "plus"
                tooltipText: "New event"
                visible: CalendarService.writableCalendars.length > 0
                onClicked: root.create()
            }
        }
    }

    Label {
        role: "caption"
        visible: CalendarService.status === "starting"
        text: "Starting Dux Calendar…"
    }

    Notice {
        width: parent.width
        visible: CalendarService.status === "failed"
        heading: "Dux Calendar didn't start"
        detail: "Run dcal daemon in a terminal to see why."
    }

    // No account yet: Google from here, the rest from dcal.
    Column {
        width: parent.width
        spacing: Theme.spacingSmall
        visible: CalendarService.ready && !CalendarService.signedIn

        Label {
            width: parent.width
            wrapMode: Text.Wrap
            text: CalendarService.signInState !== ""
                ? "Finish signing in to Google in your browser, ticking every box it asks about."
                : "Connect a calendar to see and change its events here."
        }

        Row {
            spacing: Theme.spacingSmall

            ActionButton {
                text: CalendarService.signInState !== "" ? "Waiting for Google…" : "Connect Google"
                kind: "primary"
                enabled: CalendarService.signInState === ""
                onClicked: CalendarService.signIn("")
            }

            ActionButton {
                visible: CalendarService.signInState !== ""
                text: "Cancel"
                onClicked: CalendarService.cancelSignIn()
            }
        }

        Label {
            role: "caption"
            width: parent.width
            wrapMode: Text.Wrap
            text: "Microsoft, iCloud, CalDAV, or an iCal link: run dcal account add in a terminal."
        }
    }

    Notice {
        width: parent.width
        visible: CalendarService.ready && CalendarService.accountProblem !== null
        heading: CalendarService.accountProblem ? CalendarService.accountProblem.message : ""
        detail: CalendarService.accountProblem && CalendarService.accountProblem.signIn && CalendarService.accountProblem.kind !== "google"
            ? "Run dcal account reauth " + CalendarService.accountProblem.id + " in a terminal." : ""
    }

    ActionButton {
        visible: CalendarService.ready && CalendarService.accountProblem !== null
            && CalendarService.accountProblem.signIn && CalendarService.accountProblem.kind === "google"
        text: CalendarService.signInState !== "" ? "Waiting for Google…" : "Sign in again"
        enabled: CalendarService.signInState === ""
        onClicked: CalendarService.signIn(CalendarService.accountProblem.id)
    }

    Notice {
        width: parent.width
        visible: CalendarService.signInError !== ""
        toneColor: Theme.error
        heading: "Google sign-in didn't finish"
        detail: CalendarService.signInError
    }

    Loader {
        id: form
        width: parent.width
        active: root.formOpen
        visible: root.formOpen

        sourceComponent: EventForm {
            width: form.width
            event: root.editing
            day: root.formDay
            onClosed: root.close()
        }
    }

    onDayChanged: {
        if (root.formOpen)
            root.formDay = root.day;
    }

    Label {
        role: "caption"
        visible: root.showsEvents && !root.formOpen && CalendarService.loaded && root.events.length === 0
        text: "Nothing scheduled"
    }

    Repeater {
        model: root.showsEvents && !root.formOpen ? root.events : []

        delegate: Item {
            id: row

            required property var modelData
            readonly property bool over: row.modelData.end <= root.now.getTime()
            readonly property bool clickable: !row.modelData.readOnly || row.modelData.url !== ""

            width: root.width
            height: Math.max(Theme.controlHeight, details.implicitHeight + Theme.spacingTiny * 2)
            opacity: row.over || row.modelData.declined ? Theme.disabledOpacity : 1

            Rectangle {
                anchors.fill: parent
                radius: Theme.borderRadius
                color: Theme.controlFill
                visible: hover.hovered && row.clickable
            }

            Rectangle {
                id: stripe
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: details.implicitHeight
                radius: width / 2
                color: CalendarService.color(row.modelData)
            }

            Column {
                id: details
                anchors.left: stripe.right
                anchors.leftMargin: Theme.spacingSmall
                anchors.right: join.visible ? join.left : parent.right
                anchors.rightMargin: Theme.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingMicro

                Label {
                    role: "title"
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.modelData.title
                    font.strikeout: row.modelData.declined
                }

                Label {
                    role: "caption"
                    width: parent.width
                    elide: Text.ElideRight
                    text: [root.hours(row.modelData), row.modelData.location].filter(Boolean).join(" · ")
                }
            }

            HoverHandler {
                id: hover
                cursorShape: row.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            TapHandler {
                enabled: row.clickable
                onTapped: root.open(row.modelData)
            }

            ActionButton {
                id: join
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                visible: row.modelData.meetingUrl !== "" && !row.over && !row.modelData.declined
                compact: true
                text: "Join"
                iconName: "meeting"
                onClicked: Qt.openUrlExternally(row.modelData.meetingUrl)
            }
        }
    }
}
