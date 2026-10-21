//@ pragma UseQApplication
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.bar
import qs.services
import "../services/TimerProvider.js" as TimerProvider
import "../components/Format.js" as Format

// The running shell, once config.ini is valid: the notification server, the IPC
// targets behind `speshell`, and the windows on each screen.
Scope {
    id: root

    property bool startupAssessmentComplete: false

    function reportStartupIssues() {
        if (root.startupAssessmentComplete || !FeatureSupport.issuesReady)
            return;
        root.startupAssessmentComplete = true;
        var issues = FeatureSupport.issues || [];
        if (issues.length === 0)
            return;
        NotificationService.addInternalNotification(
            "configured-features",
            "Some configured features are unavailable",
            issues.map(function(issue) { return issue.detail; }).join("\n")
        );
    }

    Connections {
        target: FeatureSupport
        function onIssuesReadyChanged() { Qt.callLater(root.reportStartupIssues); }
    }

    Component.onCompleted: root.reportStartupIssues()

    NotificationServer {
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: function(notification) {
            notification.tracked = true;
            NotificationService.addNotification(notification);
        }
    }

    IpcHandler {
        target: "launcher"

        function open(): void { LauncherService.open(); }
        function close(): void { LauncherService.close(); }
        function toggle(): void { LauncherService.toggle(); }
    }

    IpcHandler {
        target: "panel"

        function open(name: string): bool { return PanelService.open(name); }
        function toggle(name: string): bool { return PanelService.toggle(name); }
        function close(): void { PanelService.dismiss(); }
        function list(): string {
            return Object.keys(PanelService.labels).filter(PanelService.isSupported)
                .map(name => name + "\t" + PanelService.labels[name]).join("\n");
        }
    }

    IpcHandler {
        target: "timer"

        // A length and a name: "25", "10 pasta", "bread at 21:30".
        function start(text: string): bool {
            const parsed = TimerProvider.parseTimer(text);
            return TimerService.start(parsed.seconds, parsed.name) !== null;
        }
        // To the timer named, or the one that ends first.
        function add(text: string): bool {
            const parsed = TimerProvider.parseTimer(text);
            return TimerService.add(TimerService.find(parsed.name), parsed.seconds);
        }
        function pause(name: string): bool { return TimerService.pause(TimerService.find(name)); }
        function resume(name: string): bool { return TimerService.resume(TimerService.find(name)); }
        function toggle(name: string): bool { return TimerService.toggle(TimerService.find(name)); }
        function stop(name: string): bool { return TimerService.stop(TimerService.find(name)); }
        // A line for each timer, "running 4:05 Tea", or "idle".
        function get(): string {
            const lines = TimerService.timers.filter(timer => timer.isSet).map(timer =>
                [timer.paused ? "paused" : "running", Format.clock(timer.remainingSeconds), timer.name]
                    .join(" ").trim());
            return lines.length > 0 ? lines.join("\n") : "idle";
        }
    }

    IpcHandler {
        target: "activity"

        function publish(id: string, state: string, label: string, detail: string,
                         iconName: string, tone: string): void {
            ActivityService.publish("ipc", {
                id: id,
                state: state,
                label: label,
                detail: detail,
                iconName: iconName,
                tone: tone,
                priority: 50
            });
        }

        function clear(id: string): void { ActivityService.clear("ipc", id); }
        function list(): string { return JSON.stringify(ActivityService.activities); }
        function refresh(): void { processActivities.refresh(); }
    }

    IpcHandler {
        target: "tool"

        function run(name: string, mode: string): bool { return ToolsService.run(name, mode); }
        function list(): string {
            return ToolsService.tools.map(function(tool) { return tool.id + "\t" + tool.label; }).join("\n");
        }
    }

    // For laptop keys: each change shows the OSD. `state` is on, off, or toggle.
    IpcHandler {
        target: "brightness"

        function up(): void { BrightnessService.stepFromKey(1); }
        function down(): void { BrightnessService.stepFromKey(-1); }
        function set(percent: int): void {
            BrightnessService.setPercent(percent);
            BrightnessService.commit();
            OsdService.showPercent("brightness", "Brightness", BrightnessService.percent);
        }
        function get(): string { return BrightnessService.available ? String(BrightnessService.percent) : ""; }
        function keyboard(): void { BrightnessService.cycleKeyboard(); }
    }

    IpcHandler {
        target: "awake"

        function set(state: string): bool {
            if (state !== "on" && state !== "off" && state !== "toggle")
                return false;
            IdleService.setKeepAwake(state === "toggle" ? !IdleService.keepAwake : state === "on");
            return true;
        }
        function get(): string { return IdleService.keepAwake ? "on" : "off"; }
    }

    IpcHandler {
        target: "touchpad"

        function set(state: string): bool {
            if (!InputService.available || (state !== "on" && state !== "off" && state !== "toggle"))
                return false;
            InputService.setFromKey(state === "toggle" ? !InputService.touchpadEnabled : state === "on");
            return true;
        }
        function get(): string { return InputService.available ? (InputService.touchpadEnabled ? "on" : "off") : ""; }
    }

    IpcHandler {
        target: "airplane"

        function set(state: string): bool {
            if (!RadioService.available || (state !== "on" && state !== "off" && state !== "toggle"))
                return false;
            RadioService.setAirplaneMode(state === "toggle" ? !RadioService.airplaneMode : state === "on", true);
            return true;
        }
        function get(): string { return RadioService.available ? (RadioService.airplaneMode ? "on" : "off") : ""; }
    }

    IpcHandler {
        target: "nightlight"

        function set(state: string): bool {
            if (!NightLightService.available || (state !== "on" && state !== "off" && state !== "toggle"))
                return false;
            NightLightService.setFromKey(state === "toggle" ? !NightLightService.enabled : state === "on");
            return true;
        }
        function get(): string { return NightLightService.available ? (NightLightService.enabled ? "on" : "off") : ""; }
    }

    IpcHandler {
        target: "theme"

        function list(): string {
            return ThemeService.themes.map(function(theme) { return theme.id + "\t" + theme.name; }).join("\n");
        }
        function get(): string { return ThemeService.themeId; }
        function set(id: string): bool { return ThemeService.setTheme(id); }
        function shuffle(id: string): bool { return ThemeService.shuffle(id === "*" ? "" : id); }
        function rescan(): void { ThemeService.scan(); }
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): bool { return ThemeService.setWallpaper(path); }
        function get(): string { return ThemeService.wallpaper; }
    }

    ActivityProcessAdapter {
        id: processActivities
    }

    Variants {
        model: ThemeService.wallpaperEnabled ? Quickshell.screens : []

        WallpaperWindow {}
    }

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    LauncherOverlay {}

    LevelOsdWindow {}

    NotificationToastWindow {}
}
