pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.services

// What runs whether or not config.ini is valid: the notification server, so no app's
// notification is lost, the IPC targets behind the laptop's keys, and one that tells
// `speshell` whether config.ini is valid. Runtime holds the rest.
Scope {
    id: root

    // A switch's IPC `set`, to on, off, or toggle: `apply` takes whether it's on, and
    // returns false when the switch couldn't change.
    function setSwitch(name, available, current, state, apply) {
        if (state !== "on" && state !== "off" && state !== "toggle")
            return "error: " + name + " takes on, off, or toggle, not " + state;
        if (!available)
            return "error: no " + name + " switch here";
        return apply(state === "toggle" ? !current : state === "on") !== false ? "" : "error: could not change " + name;
    }

    NotificationServer {
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;
            NotificationService.addNotification(notification);
        }
    }

    IpcHandler {
        target: "config"

        // "loading", "valid", or "invalid", for `speshell` to say why a target is missing.
        function status(): string { return ConfigService.status; }
    }

    // For laptop keys: each change shows the OSD. `state` is on, off, or toggle.
    IpcHandler {
        target: "brightness"

        function up(): void { BrightnessService.stepFromKey(1); }
        function down(): void { BrightnessService.stepFromKey(-1); }
        function set(percent: int): void {
            BrightnessService.setPercent(percent);
            BrightnessService.commit();
            OsdService.showLevel("brightness");
        }
        function get(): string { return BrightnessService.available ? String(BrightnessService.percent) : ""; }
        function keyboard(): void { BrightnessService.cycleKeyboard(); }
    }

    IpcHandler {
        target: "awake"

        function set(state: string): string {
            return root.setSwitch("awake", true, IdleService.keepAwake, state, on => IdleService.setKeepAwake(on));
        }
        function get(): string { return IdleService.keepAwake ? "on" : "off"; }
    }

    IpcHandler {
        target: "touchpad"

        function set(state: string): string {
            return root.setSwitch("touchpad", InputService.available, InputService.touchpadEnabled, state,
                on => InputService.setFromKey(on));
        }
        function get(): string { return InputService.available ? (InputService.touchpadEnabled ? "on" : "off") : ""; }
    }

    IpcHandler {
        target: "airplane"

        function set(state: string): string {
            return root.setSwitch("airplane", RadioService.available, RadioService.airplaneMode, state,
                on => RadioService.setAirplaneMode(on, true));
        }
        function get(): string { return RadioService.available ? (RadioService.airplaneMode ? "on" : "off") : ""; }
    }

    IpcHandler {
        target: "nightlight"

        function set(state: string): string {
            return root.setSwitch("nightlight", NightLightService.available, NightLightService.enabled, state,
                on => NightLightService.setFromKey(on));
        }
        function get(): string { return NightLightService.available ? (NightLightService.enabled ? "on" : "off") : ""; }
    }
}
