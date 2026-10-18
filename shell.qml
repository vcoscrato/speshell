//@ pragma UseQApplication
//@ pragma AppId speshell
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs.services
import qs.theme
import qs.core

ShellRoot {
    id: root

    function applyConfig(configValue) {
        if (!configValue)
            return;
        Theme.textScale = configValue.textScale;
        ThemeService.wallpaperEnabled = configValue.drawWallpaper;
        EffectsService.launcherSpeed = configValue.launcherTransitionSpeed;
        EffectsService.wallpaperSpeed = configValue.wallpaperTransitionSpeed;
        EffectsService.controlsSpeed = configValue.controlEffectsSpeed;
        ThemeService.launchShuffle = configValue.shuffleAtLaunch;
        AudioService.scrollStep = configValue.audioScrollStep;
        AudioService.outputQuickSwitch = configValue.audioQuickSwitch;
        AudioService.outputDeviceNames = configValue.audioDeviceNames;
        AudioService.inputQuickSwitch = configValue.audioInputQuickSwitch;
        AudioService.inputDeviceNames = configValue.audioInputDeviceNames;
        WeatherService.location = configValue.weatherLocation;
        WeatherService.enabled = configValue.weatherEnabled;
        FeatureSupport.configuredBacklightDevice = configValue.backlightDevice;
        PowerService.lockCommand = configValue.powerMenu.lockCommand;
        PowerService.mode = configValue.powerMode;
        NotificationService.maxVisible = configValue.maxVisibleNotification;
        ToolsService.ocrLanguages = configValue.tools.ocrLanguages;
        ToolsService.dictationLanguages = configValue.tools.dictationLanguages;
        ToolsService.dictationVocabulary = configValue.tools.dictationVocabulary;
        ToolsService.dictationModel = configValue.tools.dictationModel;
    }

    Connections {
        target: ConfigService

        function onConfigChanged() {
            if (ConfigService.config)
                root.applyConfig(ConfigService.config);
        }
    }

    Binding {
        target: Theme
        property: "paletteOverride"
        value: ThemeService.colors
    }

    // Saver keeps the interface still.
    Binding {
        target: Theme
        property: "motion"
        value: PowerService.mode !== "saver"
    }

    Binding {
        target: EffectsService
        property: "dir"
        value: ThemeService.activeEffectsDir
    }

    LazyLoader {
        active: ConfigService.valid

        component: Runtime {
            config: ConfigService.config
        }
    }

    ConfigErrorWindow {
        active: ConfigService.invalid
    }

    Component.onCompleted: ConfigService.load()
}
