pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import Quickshell
import qs.components
import qs.services
import qs.theme
import "../components/Format.js" as Format

// The notification history, Do Not Disturb, and clearing it.
Card {
    id: root
    title: "Notifications" + (notifList.length > 0 ? " (" + notifList.length + ")" : "")
    iconName: "bell"

    property var notifList: NotificationService.notificationHistory
    readonly property int maxVisibleNotifications: 5
    property bool presented: false

    // Now, to the half minute, for how long ago each notification came.
    property double now: Date.now()
    property string expandedNotificationId: ""
    readonly property int notificationRowHeight: Math.max(48,
        Math.ceil((Theme.fontSizeNormal + Theme.fontSizeCaption) * 1.25)
            + Theme.spacingMedium)

    headerActions: Row {
        spacing: Theme.spacingSmall

        HeaderButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.notifList.length > 0
            iconName: "bell-clear"
            tooltipText: "Clear notifications"
            onClicked: NotificationService.clearHistory()
        }

        ActionButton {
            text: "Do not disturb"
            iconName: NotificationService.dndEnabled ? "bell-off" : "bell"
            compact: true
            checked: NotificationService.dndEnabled
            onClicked: NotificationService.setDndEnabled(!NotificationService.dndEnabled)
        }
    }

    function notificationKey(notification) {
        return String(notification && notification.id !== undefined ? notification.id : "");
    }

    function toggleExpanded(notification) {
        var key = root.notificationKey(notification);
        root.expandedNotificationId = root.expandedNotificationId === key ? "" : key;
    }

    function listHeightForRows(rows) {
        if (rows === 0) return 0;
        return root.notificationRowHeight * rows + Theme.spacingTiny * (rows - 1);
    }

    function compactText(value) {
        return String(value || "").replace(/\s+/g, " ").trim();
    }

    function primaryText(notification) {
        var summary = root.compactText(notification.summary);
        if (summary !== "") return summary;

        var body = root.compactText(notification.body);
        if (body !== "") return body;

        return notification.appName || "Notification";
    }

    // The second line: the body when the summary leaves one, else the app.
    function detailText(notification) {
        var summary = root.compactText(notification.summary);
        var body = root.compactText(notification.body);
        if (summary !== "" && body !== "" && body !== summary)
            return body;
        return root.compactText(notification.appName);
    }

    function iconSource(notification) {
        return notification.appIcon ? Quickshell.iconPath(notification.appIcon, true) : "";
    }

    function isInternal(notification) {
        return String(notification.id).indexOf("internal:") === 0;
    }

    onPresentedChanged: {
        if (root.presented)
            root.now = Date.now();
        else
            root.expandedNotificationId = "";
    }

    Timer {
        interval: 30000
        running: root.presented
        repeat: true
        onTriggered: root.now = Date.now()
    }

    Column {
        width: parent.width
        spacing: Theme.spacingSmall

        ListView {
            width: parent.width
            readonly property int compactHeight: root.listHeightForRows(
                Math.min(root.notifList.length, root.maxVisibleNotifications))
            height: root.expandedNotificationId === ""
                ? compactHeight
                : Math.max(compactHeight, Math.min(contentHeight, 240))
            clip: true
            spacing: Theme.spacingTiny
            boundsBehavior: Flickable.StopAtBounds
            model: root.notifList

            Behavior on height {
                NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
            }

            T.ScrollBar.vertical: StyledScrollBar {
                policy: root.notifList.length > root.maxVisibleNotifications
                    ? T.ScrollBar.AsNeeded
                    : T.ScrollBar.AlwaysOff
            }

            delegate: Rectangle {
                id: notificationRow
                required property var modelData
                required property int index
                readonly property bool expanded: root.expandedNotificationId
                    === root.notificationKey(notificationRow.modelData)

                width: ListView.view.width
                height: expanded
                    ? Math.max(root.notificationRowHeight,
                        rowContent.implicitHeight + Theme.spacingSmall * 2)
                    : root.notificationRowHeight
                radius: Theme.borderRadius
                clip: true
                color: notifMouse.containsMouse ? Theme.cardHover : Theme.controlFill

                Accessible.role: Accessible.Button
                Accessible.name: root.primaryText(notificationRow.modelData)
                Accessible.description: expanded ? "Collapse notification" : "Read full notification"
                Accessible.onPressAction: root.toggleExpanded(notificationRow.modelData)

                Behavior on height {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
                }

                // Critical notifications keep a red edge in the history too.
                Rectangle {
                    visible: notificationRow.modelData.urgency === 2
                    width: 2
                    height: parent.height
                    color: Theme.error
                }

                Item {
                    id: sourceIcon
                    readonly property string source: root.iconSource(notificationRow.modelData)
                    x: Theme.spacingSmall
                    y: notificationRow.expanded
                        ? Theme.spacingSmall + 1
                        : (root.notificationRowHeight - height) / 2
                    width: Theme.iconSizeMedium
                    height: width

                    Image {
                        id: sourceImage
                        anchors.fill: parent
                        source: sourceIcon.source
                        sourceSize: Qt.size(parent.width * 2, parent.height * 2)
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }

                    SpeshellMark {
                        anchors.centerIn: parent
                        size: Theme.iconSizeMedium - 2
                        visible: !sourceImage.visible && root.isInternal(notificationRow.modelData)
                    }

                    AppIcon {
                        anchors.centerIn: parent
                        name: "bell"
                        size: Theme.iconSizeSmall
                        iconColor: Theme.overlay
                        visible: !sourceImage.visible && !root.isInternal(notificationRow.modelData)
                    }
                }

                Column {
                    id: rowContent
                    anchors {
                        left: sourceIcon.right
                        right: dismissBtn.left
                        top: parent.top
                        leftMargin: Theme.spacingSmall
                        rightMargin: Theme.spacingTiny
                        topMargin: notificationRow.expanded
                            ? Theme.spacingSmall
                            : (root.notificationRowHeight - rowContent.implicitHeight) / 2
                    }
                    spacing: Theme.spacingMicro

                    Item {
                        width: parent.width
                        height: summaryText.implicitHeight

                        Label {
                            id: summaryText
                            role: "title"
                            anchors.left: parent.left
                            anchors.right: ageText.left
                            anchors.rightMargin: Theme.spacingSmall
                            text: root.primaryText(notificationRow.modelData)
                            elide: Text.ElideRight
                            wrapMode: notificationRow.expanded ? Text.Wrap : Text.NoWrap
                        }

                        Label {
                            id: ageText
                            role: "caption"
                            anchors.right: parent.right
                            anchors.baseline: summaryText.baseline
                            text: Format.ago(notificationRow.modelData.time, root.now)
                            color: Theme.overlay
                        }
                    }

                    Label {
                        width: parent.width
                        text: notificationRow.expanded
                            ? String(notificationRow.modelData.body || root.compactText(notificationRow.modelData.appName)).trim()
                            : root.detailText(notificationRow.modelData)
                        color: Theme.subtext
                        elide: notificationRow.expanded ? Text.ElideNone : Text.ElideRight
                        wrapMode: notificationRow.expanded ? Text.Wrap : Text.NoWrap
                        maximumLineCount: notificationRow.expanded ? 12 : 1
                        visible: text !== ""
                    }

                    Label {
                        role: "caption"
                        width: parent.width
                        visible: notificationRow.expanded && root.compactText(notificationRow.modelData.body) !== ""
                        text: root.compactText(notificationRow.modelData.appName)
                        color: Theme.overlay
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    id: dismissBtn
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingTiny
                    anchors.top: parent.top
                    anchors.topMargin: notificationRow.expanded
                        ? Theme.spacingTiny
                        : (notificationRow.height - height) / 2
                    z: 2
                    iconName: "close"
                    size: Theme.controlHeightSmall
                    iconSize: Theme.iconSizeSmall
                    iconColor: containsMouse ? Theme.error : Theme.overlay
                    hoverColor: Theme.alpha(Theme.error, Theme.tintStrong)
                    tooltipText: "Dismiss notification"
                    onClicked: NotificationService.removeHistoryAt(notificationRow.index)
                }

                MouseArea {
                    id: notifMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    z: 1
                    onClicked: root.toggleExpanded(notificationRow.modelData)
                }
            }
        }

        EmptyState {
            visible: root.notifList.length === 0
            iconName: NotificationService.dndEnabled ? "bell-off" : "bell"
            title: NotificationService.dndEnabled ? "Do Not Disturb is on" : "All caught up"
            detail: NotificationService.dndEnabled
                ? "Only critical ones pop up; the rest wait here."
                : "New notifications will show up here."
        }
    }
}
