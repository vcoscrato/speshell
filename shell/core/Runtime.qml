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

    // An IPC action's reply: "" when it went through, else "error: " and why, which
    // `speshell` prints as it fails.
    function reply(ok, why) {
        return ok ? "" : "error: " + why;
    }

    function openWallpapers(toggle) {
        if (!ThemeService.wallpaperEnabled)
            return "error: Speshell doesn't draw the wallpaper: [Appearance] drawWallpaper is false";
        if (toggle)
            ThemeService.toggleGallery("wallpapers");
        else
            ThemeService.openGallery("wallpapers");
        return "";
    }

    // A switch's IPC `set`, to on, off, or toggle: `apply` takes whether it's on.
    function setSwitch(name, available, current, state, apply) {
        if (state !== "on" && state !== "off" && state !== "toggle")
            return "error: " + name + " takes on, off, or toggle, not " + state;
        if (!available)
            return "error: no " + name + " switch here";
        apply(state === "toggle" ? !current : state === "on");
        return "";
    }

    function noTimer(action, name) {
        return "no timer to " + action + (name !== "" ? ": " + name : "");
    }

    // Panels save to config.ini as they change; a save that fails says so.
    Connections {
        target: ConfigService
        function onOperationMessageChanged() {
            if (ConfigService.operationFailed && ConfigService.operationMessage !== "")
                NotificationService.addInternalNotification("config", "Speshell config", ConfigService.operationMessage);
        }
    }

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

        function open(name: string): string {
            return root.reply(PanelService.open(name), "no " + name + " panel here (see speshell panel list)");
        }
        function toggle(name: string): string {
            return root.reply(PanelService.toggle(name), "no " + name + " panel here (see speshell panel list)");
        }
        function close(): void { PanelService.dismiss(); }
        function list(): string {
            return Object.keys(PanelService.labels).filter(PanelService.isSupported)
                .map(name => name + "\t" + PanelService.labels[name]).join("\n");
        }
    }

    IpcHandler {
        target: "timer"

        // A length and a name: "25", "10 pasta", "bread at 21:30".
        function start(text: string): string {
            const parsed = TimerProvider.parseTimer(text);
            return root.reply(TimerService.start(parsed.seconds, parsed.name) !== null,
                "not a length: " + text + " (minutes, or like 1h30 or 90s)");
        }
        // To the timer named, or the one that ends first.
        function add(text: string): string {
            const parsed = TimerProvider.parseTimer(text);
            return root.reply(TimerService.add(TimerService.find(parsed.name), parsed.seconds),
                "no timer to add to, or not a length: " + text);
        }
        function pause(name: string): string {
            return root.reply(TimerService.pause(TimerService.find(name)), root.noTimer("pause", name));
        }
        function resume(name: string): string {
            return root.reply(TimerService.resume(TimerService.find(name)), root.noTimer("resume", name));
        }
        function toggle(name: string): string {
            return root.reply(TimerService.toggle(TimerService.find(name)), root.noTimer("toggle", name));
        }
        function stop(name: string): string {
            return root.reply(TimerService.stop(TimerService.find(name)), root.noTimer("stop", name));
        }
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

        function run(name: string, mode: string): string {
            if (!ToolsService.tool(name))
                return "error: no tool " + name + " (see speshell tool list)";
            return root.reply(ToolsService.run(name, mode), name + " is not installed (see speshell tool list)");
        }
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

    IpcHandler {
        target: "theme"

        function list(): string {
            return ThemeService.themes.map(function(theme) { return theme.id + "\t" + theme.name; }).join("\n");
        }
        function get(): string { return ThemeService.themeId; }
        function set(id: string): string {
            return root.reply(ThemeService.setTheme(id), "no theme " + id + " (see speshell theme list)");
        }
        // To another wallpaper of the theme `id`, or of the current one when "".
        function shuffle(id: string): string {
            return root.reply(ThemeService.shuffle(id), "no other wallpaper to shuffle to");
        }
        function rescan(): void { ThemeService.scan(); }
        // The theme gallery.
        function open(): void { ThemeService.openGallery(); }
        function close(): void { ThemeService.closeGallery(); }
        function toggle(): void { ThemeService.toggleGallery(); }
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): string {
            if (!ThemeService.wallpaperEnabled)
                return "error: Speshell doesn't draw the wallpaper: [Appearance] drawWallpaper is false";
            return root.reply(ThemeService.setWallpaper(path),
                path + " is not in a theme folder in " + ThemeService.themesDirs.join(" or "));
        }
        function get(): string { return ThemeService.wallpaper; }
        // The theme gallery, at the current theme's wallpapers.
        function open(): string { return root.openWallpapers(false); }
        function toggle(): string { return root.openWallpapers(true); }
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

    ThemeGallery {}

    LevelOsdWindow {}

    NotificationToastWindow {}
}
