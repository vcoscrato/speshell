import QtQuick
import qs.components
import qs.services
import qs.theme

Column {
    id: root

    readonly property var config: ConfigService.config ?? ({})
    readonly property string savedLocation: String(root.config.weatherLocation ?? "")
    readonly property bool weatherEnabled: root.config.weatherEnabled ?? false
    // The location being typed; null shows the saved one. Deriving the field from both,
    // rather than copying the saved value in on change, keeps `dirty` free of a loop.
    property var locationEdit: null

    function saveLocation() {
        if (root.locationEdit !== null)
            ConfigService.setProperty("Weather", "location", root.locationEdit.trim());
        root.locationEdit = null;
        locationInput.focus = false;
    }

    spacing: Theme.spacingSmall

    SettingRow {
        label: "Show weather"
        info: "The weather beside the bar's clock, and the forecast in the clock panel. From Open-Meteo."

        ToggleSwitch {
            checked: root.weatherEnabled
            tooltipText: "Show weather"
            onToggled: on => ConfigService.setProperty("Weather", "enabled", on ? "true" : "false")
        }
    }

    SettingRow {
        enabled: root.weatherEnabled
        label: "Location"
        info: "A city name. Leave it empty to use where your IP address places you."

        Rectangle {
            implicitWidth: 180
            implicitHeight: Math.max(Theme.controlHeightSmall, locationInput.implicitHeight + Theme.spacingTiny * 2)
                + Theme.spacingMicro * 2
            radius: Theme.borderRadius
            color: Theme.controlFill
            border.width: Theme.borderWidth
            border.color: locationInput.activeFocus ? Theme.selectedBorder : Theme.controlBorder

            TextInput {
                id: locationInput

                readonly property bool dirty: root.locationEdit !== null && root.locationEdit.trim() !== root.savedLocation

                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingSmall
                anchors.right: saveButton.visible ? saveButton.left : parent.right
                anchors.rightMargin: Theme.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                text: root.locationEdit ?? root.savedLocation
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.onAccent
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                clip: true
                Accessible.name: "Weather location"
                onTextEdited: root.locationEdit = text
                onAccepted: root.saveLocation()
                Keys.onEscapePressed: {
                    root.locationEdit = null;
                    locationInput.focus = false;
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: locationInput.text === ""
                    text: "Automatic"
                    font: locationInput.font
                    color: Theme.overlay
                }
            }

            IconButton {
                id: saveButton
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingMicro
                anchors.verticalCenter: parent.verticalCenter
                visible: locationInput.dirty
                size: Theme.controlHeightSmall - Theme.spacingTiny
                iconName: "check"
                iconSize: Theme.iconSizeSmall
                iconColor: Theme.accent
                tooltipText: "Save location (Enter)"
                onClicked: root.saveLocation()
            }
        }
    }

    Notice {
        visible: root.weatherEnabled && WeatherService.status === "unknown"
        heading: "Location not found"
        detail: "Open-Meteo knows no place called “" + root.savedLocation + "”. Try the nearest city."
    }

    Notice {
        visible: root.weatherEnabled && WeatherService.status === "offline"
        heading: "Weather unavailable"
        detail: "The forecast didn't load. Speshell tries again in a couple of minutes."
    }
}
