pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services
import qs.theme

// Speshell and what it runs on, its config file and the actions on it, and setup
// problems worth fixing.
Column {
    id: root

    property string quickshellVersion: ""
    property string hyprlandVersion: ""
    readonly property string compositor: HyprlandService.running
        ? "Hyprland " + (root.hyprlandVersion || "")
        : (Quickshell.env("XDG_CURRENT_DESKTOP") || "Unknown")
    readonly property string configPath: {
        const path = ConfigService.configPath || (ConfigService.configDir || "~/.config/speshell") + "/config.ini";
        const home = String(Quickshell.env("HOME") || "");
        return home !== "" && path.startsWith(home) ? "~" + path.substring(home.length) : path;
    }
    readonly property real labelWidth: Math.ceil(Math.max(
        labelMetrics.advanceWidth("Quickshell"),
        labelMetrics.advanceWidth("Compositor"),
        labelMetrics.advanceWidth("Config")))

    spacing: Theme.spacingLarge

    FontMetrics {
        id: labelMetrics
        font.pixelSize: Theme.fontSizeSmall
        font.family: Theme.fontFamily
    }

    Item {
        width: parent.width
        height: Math.max(mark.height, githubButton.height)

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingMedium

            SpeshellMark {
                id: mark
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: nameText
                anchors.verticalCenter: parent.verticalCenter
                text: "Speshell"
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamily
                font.bold: true
                color: Theme.text
            }

            Text {
                anchors.baseline: nameText.baseline
                text: SystemState.appVersion
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                color: Theme.subtext
            }
        }

        IconButton {
            id: githubButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.controlHeightSmall
            iconSize: Theme.iconSizeSmall
            iconName: "github"
            iconColor: containsMouse ? Theme.accent : Theme.subtext
            tooltipText: "Speshell on GitHub"
            onClicked: Qt.openUrlExternally("https://github.com/vcoscrato/speshell")
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingTiny

        Detail {
            labelWidth: root.labelWidth
            label: "Quickshell"
            value: root.quickshellVersion || "unknown"
        }

        Detail {
            labelWidth: root.labelWidth
            label: "Compositor"
            value: root.compositor
        }

        Detail {
            labelWidth: root.labelWidth
            label: "Config"
            value: root.configPath
            info: "A few options, like custom ! shortcuts and device names, are only in this file. "
                + "Saved changes apply right away."
        }

        // Under the path, aligned with the values.
        Row {
            x: root.labelWidth + Theme.spacingLarge
            spacing: Theme.spacingTiny

            ActionButton {
                text: "Edit"
                iconName: "notes"
                compact: true
                enabled: !ConfigService.savingConfig
                onClicked: ConfigService.openConfig()
            }

            ActionButton {
                text: ConfigService.loading ? "Loading" : "Reload"
                iconName: "refresh"
                compact: true
                enabled: !ConfigService.loading && !ConfigService.savingConfig
                onClicked: ConfigService.load()
            }

            ActionButton {
                text: SystemState.relaunching ? "Starting" : "Relaunch"
                iconName: "restart"
                compact: true
                enabled: SystemState.canRelaunch
                onClicked: SystemState.relaunch()
            }
        }
    }

    // Setup problems worth fixing; nothing when the setup is complete.
    Repeater {
        model: FeatureSupport.issues

        delegate: Notice {
            required property var modelData

            heading: modelData.title
            detail: modelData.detail
        }
    }

    // A label and its value.
    component Detail: Item {
        id: detail

        property string label: ""
        property string value: ""
        property string info: ""
        property real labelWidth: 0

        width: parent ? parent.width : 0
        height: Math.max(Theme.controlHeightSmall, valueText.implicitHeight)

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: detail.label
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            color: Theme.overlay
        }

        Text {
            id: valueText
            anchors.left: parent.left
            anchors.leftMargin: detail.labelWidth + Theme.spacingLarge
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, detail.width - x - (detailInfo.visible ? detailInfo.width + Theme.spacingSmall : 0))
            text: detail.value
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            color: Theme.text
            elide: Text.ElideMiddle
        }

        InfoTip {
            id: detailInfo
            anchors.left: valueText.right
            anchors.leftMargin: Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            visible: detail.info !== ""
            text: detail.info
        }
    }

    Process {
        running: true
        command: ["quickshell", "--version"]
        stdout: SplitParser {
            onRead: line => {
                const match = String(line || "").match(/^Quickshell\s+(\S+)/i);
                if (match)
                    root.quickshellVersion = match[1];
            }
        }
    }

    Process {
        running: HyprlandService.running
        command: ["hyprctl", "version"]
        stdout: SplitParser {
            onRead: line => {
                const match = String(line || "").match(/^Hyprland\s+(\S+)/);
                if (match && root.hyprlandVersion === "")
                    root.hyprlandVersion = match[1];
            }
        }
    }
}
