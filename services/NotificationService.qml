pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool dndEnabled: false
    property bool dndChangedThisSession: false
    // Maximum simultaneous toasts; -1 shows every toast.
    property int maxVisible: 3
    property var notificationHistory: []
    property var activePopups: []
    property int popupCounter: 0
    readonly property string statePath: ConfigService.dataDir !== ""
        ? ConfigService.dataDir + "/notifications.json"
        : ""

    function setDndEnabled(enabled) {
        root.dndEnabled = !!enabled;
        root.dndChangedThisSession = true;
        if (root.statePath !== "")
            stateFile.setText(JSON.stringify({ dndEnabled: root.dndEnabled }));
    }

    // Do Not Disturb still lets critical notifications through.
    function showsPopup(urgency) {
        return !root.dndEnabled || urgency === 2;
    }

    function pushPopup(popup) {
        var popups = root.activePopups.slice();
        popups.push(popup);
        while (root.maxVisible > 0 && popups.length > root.maxVisible) {
            var evicted = popups.shift();
            if (evicted.notification && evicted.notification.tracked)
                evicted.notification.expire();
        }
        root.activePopups = popups;
        root.schedulePopupExpiry();
    }

    function popupById(popupId) {
        for (var i = 0; i < root.activePopups.length; i++) {
            if (root.activePopups[i].popupId === popupId)
                return root.activePopups[i];
        }
        return null;
    }

    function removePopup(popupId) {
        var current = root.activePopups.slice();
        for (var i = 0; i < current.length; i++) {
            if (current[i].popupId === popupId) {
                current.splice(i, 1);
                break;
            }
        }
        root.activePopups = current;
        root.schedulePopupExpiry();
    }

    function dismissPopup(popupId) {
        var popup = root.popupById(popupId);
        if (!popup)
            return;
        root.removePopup(popupId);
        if (popup.notification && popup.notification.tracked)
            popup.notification.dismiss();
    }

    function expirePopup(popupId) {
        var popup = root.popupById(popupId);
        if (!popup)
            return;
        root.removePopup(popupId);
        if (popup.notification && popup.notification.tracked)
            popup.notification.expire();
    }

    function launchDesktopEntry(desktopEntryId) {
        var requested = String(desktopEntryId || "");
        if (requested === "")
            return false;
        var entries = DesktopEntries.applications && DesktopEntries.applications.values
            ? DesktopEntries.applications.values : [];
        for (var i = 0; i < entries.length; i++) {
            var id = String(entries[i].id || "");
            if (id === requested || id === requested + ".desktop"
                    || id.replace(/\.desktop$/, "") === requested.replace(/\.desktop$/, "")) {
                entries[i].execute();
                return true;
            }
        }
        return false;
    }

    function activatePopup(popupId) {
        var popup = root.popupById(popupId);
        if (!popup)
            return;
        if (popup.defaultAction) {
            popup.defaultAction.invoke();
            if (!popup.resident)
                root.removePopup(popupId);
            return;
        }
        root.launchDesktopEntry(popup.desktopEntry);
        root.dismissPopup(popupId);
    }

    function invokePopupAction(popupId, action) {
        var popup = root.popupById(popupId);
        if (!popup || !action)
            return;
        action.invoke();
        if (!popup.resident)
            root.removePopup(popupId);
    }

    function clearHistory() {
        root.notificationHistory = [];
    }

    // Puts `entry` first in the history, replacing an older one with its id.
    function prependHistory(entry) {
        var history = root.notificationHistory.filter(function(item) { return item.id !== entry.id; });
        history.unshift(entry);
        root.notificationHistory = history.slice(0, 50);
    }

    // alwaysShow lets a notice the user asked for, like the timer, through Do Not Disturb.
    function addInternalNotification(id, summary, body, alwaysShow) {
        var entry = {
            id: "internal:" + String(id || "notice"),
            desktopEntry: "",
            appName: "Speshell",
            appIcon: "",
            summary: String(summary || "Speshell notice"),
            body: String(body || ""),
            urgency: 1,
            time: new Date()
        };
        root.prependHistory(entry);

        if (!alwaysShow && !root.showsPopup(1))
            return;

        root.pushPopup(Object.assign({}, entry, {
            popupId: root.popupCounter++,
            image: "",
            notification: null,
            defaultAction: null,
            actions: [],
            resident: false,
            expiresAt: Date.now() + 8000
        }));
    }

    function removeHistoryAt(index) {
        var current = root.notificationHistory.slice();
        if (index >= 0 && index < current.length) {
            current.splice(index, 1);
            root.notificationHistory = current;
        }
    }

    function timeoutForNotification(notification) {
        var requestedMilliseconds = Number(notification.expireTimeout);
        if (requestedMilliseconds === 0)
            return -1;
        if (isFinite(requestedMilliseconds) && requestedMilliseconds > 0)
            return Math.round(requestedMilliseconds);
        if (notification.urgency === 2)
            return 10000;
        if (notification.urgency === 0)
            return 3000;
        return 5000;
    }

    function notificationActions(notification) {
        var result = [];
        var defaultAction = null;
        var actions = notification.actions || [];
        for (var i = 0; i < actions.length; i++) {
            if (actions[i].identifier === "default")
                defaultAction = actions[i];
            else
                result.push({ text: actions[i].text || "Action", action: actions[i] });
        }
        return { defaultAction: defaultAction, actions: result };
    }

    function schedulePopupExpiry() {
        popupExpiryTimer.stop();
        var now = Date.now();
        var earliest = -1;
        for (var i = 0; i < root.activePopups.length; i++) {
            var expiresAt = Number(root.activePopups[i].expiresAt);
            if (expiresAt >= 0 && (earliest < 0 || expiresAt < earliest))
                earliest = expiresAt;
        }
        if (earliest >= 0) {
            popupExpiryTimer.interval = Math.max(1, earliest - now);
            popupExpiryTimer.start();
        }
    }

    function expireDuePopups() {
        var now = Date.now();
        var due = [];
        for (var i = 0; i < root.activePopups.length; i++) {
            var popup = root.activePopups[i];
            if (popup.expiresAt >= 0 && popup.expiresAt <= now)
                due.push(popup.popupId);
        }
        for (var j = 0; j < due.length; j++)
            root.expirePopup(due[j]);
        root.schedulePopupExpiry();
    }

    function historyEntry(notification, receivedAt) {
        return {
            id: notification.id,
            desktopEntry: notification.desktopEntry,
            appName: notification.appName,
            appIcon: notification.appIcon,
            summary: notification.summary,
            body: notification.body,
            urgency: notification.urgency,
            time: receivedAt
        };
    }

    // Apps can replace a tracked notification in place (progress, track
    // changes). Toasts bind to the live object; history and expiry need a sync.
    function updateNotification(notification) {
        if (!notification || !notification.tracked)
            return;
        var receivedAt = new Date();
        var history = root.notificationHistory.slice();
        for (var i = 0; i < history.length; i++) {
            if (history[i].id === notification.id) {
                history[i] = root.historyEntry(notification, receivedAt);
                root.notificationHistory = history;
                break;
            }
        }
        for (var j = 0; j < root.activePopups.length; j++) {
            var popup = root.activePopups[j];
            if (popup.notification === notification) {
                var timeout = root.timeoutForNotification(notification);
                popup.expiresAt = timeout < 0 ? -1 : Date.now() + timeout;
                root.schedulePopupExpiry();
                break;
            }
        }
    }

    function addNotification(notification) {
        if (!notification)
            return;

        var receivedAt = new Date();
        var actions = root.notificationActions(notification);
        if (!notification.transient)
            root.prependHistory(root.historyEntry(notification, receivedAt));

        if (!root.showsPopup(notification.urgency)) {
            if (notification.tracked)
                notification.expire();
            return;
        }

        var popupId = root.popupCounter++;
        var timeout = root.timeoutForNotification(notification);
        var update = function() { root.updateNotification(notification); };
        notification.summaryChanged.connect(update);
        notification.bodyChanged.connect(update);
        notification.closed.connect(function() { root.removePopup(popupId); });
        root.pushPopup({
            popupId: popupId,
            id: notification.id,
            desktopEntry: notification.desktopEntry,
            appName: notification.appName,
            appIcon: notification.appIcon,
            image: notification.image,
            summary: notification.summary,
            body: notification.body,
            urgency: notification.urgency,
            time: receivedAt,
            notification: notification,
            defaultAction: actions.defaultAction,
            actions: actions.actions,
            resident: notification.resident,
            expiresAt: timeout < 0 ? -1 : Date.now() + timeout
        });
    }

    Timer {
        id: popupExpiryTimer
        repeat: false
        onTriggered: root.expireDuePopups()
    }

    FileView {
        id: stateFile
        path: root.statePath
        atomicWrites: true
        printErrors: false
        onLoaded: {
            if (root.dndChangedThisSession)
                return;
            try {
                var state = JSON.parse(stateFile.text() || "{}");
                root.dndEnabled = !!(state && state.dndEnabled === true);
            } catch (stateError) {
                console.warn("[Speshell] Ignoring unreadable notification state:", stateError);
            }
        }
    }
}
