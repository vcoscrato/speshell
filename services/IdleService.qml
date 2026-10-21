pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower

// What idling does, by [Idle]: dim the screen and keyboard, lock, turn the displays
// off, and sleep, each undone by input; apps' idle inhibitors hold it off, as Keep
// awake does. Whatever puts the system to sleep, as closing the lid, locks first.
Singleton {
    id: root

    readonly property var settings: ConfigService.settings.idle
    // Keep awake, the bar's switch on battery: nothing idles until it's turned off, for
    // this session.
    property bool keepAwake: false
    // Nothing idles with the charger in, either.
    readonly property bool idling: !root.keepAwake && UPower.onBattery
    // Sleep also waits for playing media.
    readonly property bool sleepAllowed: !MediaService.playing
    property bool screenOff: false

    function setKeepAwake(on) {
        root.keepAwake = !!on;
    }

    function setScreenOff(off) {
        if (root.screenOff === off)
            return;
        root.screenOff = off;
        HyprlandService.dispatch("hl.dsp.dpms({ action = \"" + (off ? "off" : "on") + "\" })", off ? "dpms off" : "dpms on");
    }

    function lock() {
        if (!PowerService.locked && PowerService.lockerAvailable)
            PowerService.runAction("lock");
    }

    IdleMonitor {
        enabled: root.idling && root.settings.dimAfter > 0
        timeout: root.settings.dimAfter * 60
        onIsIdleChanged: isIdle ? BrightnessService.dim() : BrightnessService.undim()
        onEnabledChanged: if (!enabled) BrightnessService.undim()
    }

    IdleMonitor {
        enabled: root.idling && root.settings.lockAfter > 0
        timeout: root.settings.lockAfter * 60
        onIsIdleChanged: if (isIdle) root.lock()
    }

    IdleMonitor {
        enabled: root.idling && root.settings.screenOffAfter > 0 && HyprlandService.running
        timeout: root.settings.screenOffAfter * 60
        onIsIdleChanged: root.setScreenOff(isIdle)
        onEnabledChanged: if (!enabled) root.setScreenOff(false)
    }

    IdleMonitor {
        enabled: root.idling && root.sleepAllowed && root.settings.sleepAfter > 0
        timeout: root.settings.sleepAfter * 60
        onIsIdleChanged: if (isIdle && !PowerService.busy) PowerService.runAction("sleep")
    }

    // Locks, then lets the system sleep once the locker has had time to cover the
    // screen, as PowerService's own Sleep does.
    Connections {
        target: SessionService

        function onAboutToSleep() {
            root.setScreenOff(false);
            if (PowerService.locked || !PowerService.lockerAvailable || !PowerService.runAction("lock")) {
                SessionService.releaseSleep();
                return;
            }
            sleepRelease.restart();
        }
    }

    Timer {
        id: sleepRelease
        interval: 1000
        onTriggered: SessionService.releaseSleep()
    }
}
