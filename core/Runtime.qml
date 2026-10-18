//@ pragma UseQApplication
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.bar
import qs.services
import "../services/TimerProvider.js" as TimerProvider

Scope {
    id: root

    property var config: null
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

        // Lengths as `!timer` takes them: minutes, or "1h30", "90s".
        function start(length: string): bool { return TimerService.start(TimerProvider.parseDuration(length)); }
        function add(length: string): bool { return TimerService.add(TimerProvider.parseDuration(length)); }
        function pause(): bool { return TimerService.pause(); }
        function resume(): bool { return TimerService.resume(); }
        function toggle(): bool { return TimerService.paused ? TimerService.resume() : TimerService.pause(); }
        function stop(): bool { return TimerService.stop(); }
        function get(): string {
            if (!TimerService.running)
                return "idle";
            return (TimerService.paused ? "paused " : "running ") + TimerProvider.formatClock(TimerService.remainingSeconds);
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

        Bar {
            config: root.config
        }
    }

    LauncherOverlay {
        config: root.config
    }

    VolumeOsdWindow {}

    ActivityOsdWindow {}

    NotificationToastWindow {}
}
