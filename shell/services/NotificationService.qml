pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Notifications: the history, the toasts on screen and when each expires, Do Not
// Disturb (kept across restarts), and Speshell's own notices.
Singleton {
    id: root

    property bool dndEnabled: false
    property bool dndChangedThisSession: false
    // Maximum simultaneous toasts; -1 shows every toast.
    readonly property int maxVisible: ConfigService.settings.notifications.maxVisible
    property var notificationHistory: []
    property var activePopups: []
    property int popupCounter: 0
    // While the pointer rests on the toasts, none expires; the time held is added back.
    property bool popupsHeld: false
    property double heldSince: 0
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
        const popups = root.activePopups.slice();
        popups.push(popup);
        while (root.maxVisible > 0 && popups.length > root.maxVisible) {
            const evicted = popups.shift();
            if (evicted.notification && evicted.notification.tracked)
                evicted.notification.expire();
        }
        root.activePopups = popups;
        root.schedulePopupExpiry();
    }

    function setPopupsHeld(held) {
        if (held === root.popupsHeld)
            return;
        if (held) {
            root.heldSince = Date.now();
            popupExpiryTimer.stop();
        } else {
            const paused = Date.now() - root.heldSince;
            for (const popup of root.activePopups) {
                if (popup.expiresAt >= 0)
                    popup.expiresAt += paused;
            }
        }
        root.popupsHeld = held;
        root.schedulePopupExpiry();
    }

    function popupById(popupId) {
        for (let i = 0; i < root.activePopups.length; i++) {
            if (root.activePopups[i].popupId === popupId)
                return root.activePopups[i];
        }
        return null;
    }

    function removePopup(popupId) {
        const current = root.activePopups.slice();
        for (let i = 0; i < current.length; i++) {
            if (current[i].popupId === popupId) {
                current.splice(i, 1);
                break;
            }
        }
        root.activePopups = current;
        // The last toast gone, nothing is left under the pointer.
        if (current.length === 0)
            root.popupsHeld = false;
        root.schedulePopupExpiry();
    }

    function dismissPopup(popupId) {
        const popup = root.popupById(popupId);
        if (!popup)
            return;
        root.removePopup(popupId);
        if (popup.notification && popup.notification.tracked)
            popup.notification.dismiss();
    }

    function expirePopup(popupId) {
        const popup = root.popupById(popupId);
        if (!popup)
            return;
        root.removePopup(popupId);
        if (popup.notification && popup.notification.tracked)
            popup.notification.expire();
    }

    // The desktop entry of the app that sent `notification`, a toast or a history
    // entry; none for Speshell's own notices.
    function entryOf(notification) {
        if (root.isInternal(notification))
            return null;
        return WindowService.entryFor(notification.desktopEntry) ?? WindowService.entryFor(notification.appName);
    }

    // A click runs the default action, then brings the app's window forward, from the
    // tray too, since apps rarely raise themselves; without an action, it opens the app.
    function activatePopup(popupId) {
        const popup = root.popupById(popupId);
        if (!popup)
            return;
        if (popup.defaultAction)
            popup.defaultAction.invoke();
        WindowService.show(root.entryOf(popup), !!popup.defaultAction);
        if (!popup.defaultAction)
            root.dismissPopup(popupId);
        else if (!popup.resident)
            root.removePopup(popupId);
    }

    function invokePopupAction(popupId, action) {
        const popup = root.popupById(popupId);
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
        const history = root.notificationHistory.filter(item => item.id !== entry.id);
        history.unshift(entry);
        root.notificationHistory = history.slice(0, 50);
    }

    // alwaysShow lets a notice the user asked for, like the timer, through Do Not Disturb.
    // A critical one (urgency 2), like a nearly empty battery, stays until dismissed.
    // A notice replaces the one shown with its id.
    function addInternalNotification(id, summary, body, alwaysShow, urgency) {
        const critical = urgency === 2;
        const entry = {
            id: "internal:" + String(id || "notice"),
            desktopEntry: "",
            appName: "Speshell",
            appIcon: "",
            image: "",
            summary: String(summary || "Speshell notice"),
            body: String(body || ""),
            urgency: critical ? 2 : 1,
            time: new Date()
        };
        root.prependHistory(entry);
        root.dismissInternal(id);

        if (!alwaysShow && !root.showsPopup(entry.urgency))
            return;

        root.pushPopup(Object.assign({}, entry, {
            popupId: root.popupCounter++,
            notification: null,
            defaultAction: null,
            actions: [],
            resident: false,
            duration: critical ? -1 : 8000,
            expiresAt: critical ? -1 : Date.now() + 8000
        }));
    }

    // Takes Speshell's notice `id` off the screen, as when what it warned of is over.
    function dismissInternal(id) {
        const internalId = "internal:" + String(id || "notice");
        root.activePopups.filter(popup => popup.id === internalId)
            .forEach(popup => root.removePopup(popup.popupId));
    }

    function removeHistoryAt(index) {
        const current = root.notificationHistory.slice();
        if (index >= 0 && index < current.length) {
            current.splice(index, 1);
            root.notificationHistory = current;
        }
    }

    function timeoutForNotification(notification) {
        const requestedMilliseconds = Number(notification.expireTimeout);
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
        const result = [];
        let defaultAction = null;
        const actions = notification.actions || [];
        for (let i = 0; i < actions.length; i++) {
            if (actions[i].identifier === "default")
                defaultAction = actions[i];
            else
                result.push({ text: actions[i].text || "Action", action: actions[i] });
        }
        return { defaultAction: defaultAction, actions: result };
    }

    function schedulePopupExpiry() {
        popupExpiryTimer.stop();
        if (root.popupsHeld)
            return;
        const now = Date.now();
        let earliest = -1;
        for (let i = 0; i < root.activePopups.length; i++) {
            const expiresAt = Number(root.activePopups[i].expiresAt);
            if (expiresAt >= 0 && (earliest < 0 || expiresAt < earliest))
                earliest = expiresAt;
        }
        if (earliest >= 0) {
            popupExpiryTimer.interval = Math.max(1, earliest - now);
            popupExpiryTimer.start();
        }
    }

    function expireDuePopups() {
        const now = Date.now();
        const due = [];
        for (let i = 0; i < root.activePopups.length; i++) {
            const popup = root.activePopups[i];
            if (popup.expiresAt >= 0 && popup.expiresAt <= now)
                due.push(popup.popupId);
        }
        for (let j = 0; j < due.length; j++)
            root.expirePopup(due[j]);
        root.schedulePopupExpiry();
    }

    // Its text on one line, as a row shows it.
    function compactText(value) {
        return String(value || "").replace(/\s+/g, " ").trim();
    }

    // What a notification says first: its summary, else its body, else its app.
    function summaryText(notification) {
        return root.compactText(notification.summary) || root.compactText(notification.body)
            || notification.appName || "Notification";
    }

    // Its body, when the summary doesn't already say it.
    function bodyText(notification) {
        const summary = root.compactText(notification.summary);
        const body = root.compactText(notification.body);
        return summary !== "" && body !== "" && body !== summary ? String(notification.body).trim() : "";
    }

    // Its image, as a contact's picture or a track's cover, else its app's icon.
    function iconSource(notification) {
        return notification.image || (notification.appIcon ? Quickshell.iconPath(notification.appIcon, true) : "");
    }

    // One of Speshell's own notices.
    function isInternal(notification) {
        return String(notification.id).indexOf("internal:") === 0;
    }

    function historyEntry(notification, receivedAt) {
        return {
            id: notification.id,
            desktopEntry: notification.desktopEntry,
            appName: notification.appName,
            appIcon: notification.appIcon,
            image: notification.image,
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
        const receivedAt = new Date();
        const history = root.notificationHistory.slice();
        for (let i = 0; i < history.length; i++) {
            if (history[i].id === notification.id) {
                history[i] = root.historyEntry(notification, receivedAt);
                root.notificationHistory = history;
                break;
            }
        }
        for (let j = 0; j < root.activePopups.length; j++) {
            const popup = root.activePopups[j];
            if (popup.notification === notification) {
                const timeout = root.timeoutForNotification(notification);
                popup.duration = timeout;
                popup.expiresAt = timeout < 0 ? -1 : Date.now() + timeout;
                root.schedulePopupExpiry();
                break;
            }
        }
    }

    function addNotification(notification) {
        if (!notification)
            return;

        const receivedAt = new Date();
        const actions = root.notificationActions(notification);
        if (!notification.transient)
            root.prependHistory(root.historyEntry(notification, receivedAt));

        if (!root.showsPopup(notification.urgency)) {
            if (notification.tracked)
                notification.expire();
            return;
        }

        const popupId = root.popupCounter++;
        const timeout = root.timeoutForNotification(notification);
        const update = () => root.updateNotification(notification);
        notification.summaryChanged.connect(update);
        notification.bodyChanged.connect(update);
        notification.closed.connect(() => root.removePopup(popupId));
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
            // Milliseconds on screen, or -1 until dismissed; the toast draws what is left.
            duration: timeout,
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
                const state = JSON.parse(stateFile.text() || "{}");
                root.dndEnabled = !!(state && state.dndEnabled === true);
            } catch (stateError) {
                console.warn("[Speshell] Ignoring unreadable notification state:", stateError);
            }
        }
    }
}
