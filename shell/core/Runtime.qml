pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.bar
import qs.services
import "../services/Duration.js" as Duration
import "../components/Format.js" as Format

// The running shell, once config.ini is valid: the IPC targets behind `speshell` that
// need it, and the windows on each screen. Daemon holds the rest.
Scope {
    id: root

    property bool startupAssessmentComplete: false

    function reportStartupIssues() {
        if (root.startupAssessmentComplete || !FeatureSupport.issuesReady)
            return;
        root.startupAssessmentComplete = true;
        const issues = FeatureSupport.issues || [];
        if (issues.length === 0)
            return;
        NotificationService.addInternalNotification(
            "configured-features",
            "Some configured features are unavailable",
            issues.map(issue => issue.detail).join("\n")
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

    readonly property string noWallpaper: "error: Speshell doesn't draw the wallpaper: [Appearance] drawWallpaper is false"

    function openWallpapers(toggle) {
        if (!ThemeService.wallpaperEnabled)
            return root.noWallpaper;
        if (toggle)
            ThemeService.toggleGallery("wallpapers");
        else
            ThemeService.openGallery("wallpapers");
        return "";
    }

    function noTimer(action, name) {
        return "no timer to " + action + (name !== "" ? ": " + name : "");
    }

    // Panels save to config.ini as they change; a save that fails says so.
    Connections {
        target: ConfigService
        function onFeedbackChanged() {
            if (ConfigService.feedback.tone === "error")
                NotificationService.addInternalNotification("config", "Speshell config", ConfigService.feedback.text);
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
            return Object.keys(PanelService.panels).filter(PanelService.isSupported)
                .map(name => name + "\t" + PanelService.panels[name].label).join("\n");
        }
    }

    IpcHandler {
        target: "timer"

        // A length and a name: "25", "10 pasta", "bread at 21:30".
        function start(text: string): string {
            const parsed = Duration.parseTimer(text);
            return root.reply(TimerService.start(parsed.seconds, parsed.name) !== null,
                "not a length: " + text + " (minutes, or like 1h30 or 90s)");
        }
        // To the timer named, or the one that ends first.
        function add(text: string): string {
            const parsed = Duration.parseTimer(text);
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

        // STATE is active or busy, TONE neutral, accent, success, warning, or error.
        function publish(id: string, state: string, label: string, detail: string,
                         iconName: string, tone: string): string {
            return root.reply(ActivityService.publish(id, state, label, detail, iconName, tone),
                "not an activity: the id is letters, digits, and . _ -, the state active or busy, "
                    + "and the tone neutral, accent, success, warning, or error");
        }

        function clear(id: string): void { ActivityService.clear(id); }
        function list(): string { return JSON.stringify(ActivityService.activities); }
        function refresh(): void { ToolsService.refresh(); }
    }

    IpcHandler {
        target: "tool"

        function run(name: string, mode: string): string {
            if (!ToolsService.tool(name))
                return "error: no tool " + name + " (see speshell tool list)";
            return root.reply(ToolsService.run(name, mode), name + " is not installed (see speshell tool list)");
        }
        function list(): string {
            return ToolsService.tools.map(tool => tool.id + "\t" + tool.label).join("\n");
        }
    }

    IpcHandler {
        target: "theme"

        function list(): string {
            return ThemeService.themes.map(theme => theme.id + "\t" + theme.name).join("\n");
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
                return root.noWallpaper;
            return root.reply(ThemeService.setWallpaper(path),
                path + " is not in a theme folder in " + ThemeService.themesDirs.join(" or "));
        }
        function get(): string { return ThemeService.wallpaper; }
        // The theme gallery, at the current theme's wallpapers.
        function open(): string { return root.openWallpapers(false); }
        function toggle(): string { return root.openWallpapers(true); }
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

    OsdWindow {}

    NotificationToastWindow {}

    DictationWindow {}
}
