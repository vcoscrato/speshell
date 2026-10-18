pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services
import qs.theme

// The weather: the conditions now, the next hours, and the coming days, each day's
// range drawn on the week's.
Card {
    id: root

    property bool presented: false
    // The time, so passing hours drop off between refreshes.
    property date now: new Date()

    readonly property var hours: WeatherService.hours
        .filter(hour => hour.time.getTime() + 3600 * 1000 > root.now.getTime())
        .slice(1, 9)
    readonly property var days: WeatherService.days
        .filter(day => day.date.getTime() + 24 * 3600 * 1000 > root.now.getTime())
        .slice(0, 7)
    readonly property var today: root.days.length > 0 ? root.days[0] : null
    // The next sunrise or sunset: { sunrise: bool, time: Date }, or null.
    readonly property var nextSun: {
        const now = root.now.getTime();
        for (const day of WeatherService.days) {
            if (day.sunrise.getTime() > now)
                return { sunrise: true, time: day.sunrise };
            if (day.sunset.getTime() > now)
                return { sunrise: false, time: day.sunset };
        }
        return null;
    }
    readonly property real weekLow: Math.min.apply(null, root.days.map(day => day.low))
    readonly property real weekHigh: Math.max.apply(null, root.days.map(day => day.high))

    title: "Weather"
    iconName: "cloud"

    onPresentedChanged: {
        root.now = new Date();
        if (root.presented)
            WeatherService.refreshIfStale();
    }

    Timer {
        interval: 60 * 1000
        repeat: true
        running: root.presented
        onTriggered: root.now = new Date()
    }

    headerActions: [
        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: WeatherService.ready
            spacing: Theme.spacingTiny

            AppIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "location"
                size: Theme.iconSizeTiny
                iconColor: Theme.subtext
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.width * 0.55)
                text: WeatherService.place
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeCaption
                font.family: Theme.fontFamily
                color: Theme.subtext
            }
        },

        RefreshButton {
            active: WeatherService.status === "loading"
            enabled: !active
            tooltipText: "Refresh the weather"
            onClicked: WeatherService.refresh()
        }
    ]

    // ── Loading, or why there is no forecast ──
    EmptyState {
        visible: !WeatherService.ready
        iconName: "weather-cloudy"
        busy: WeatherService.status === "loading" || WeatherService.status === ""
        title: WeatherService.status === "unknown" ? "No place called “" + WeatherService.location + "”"
            : WeatherService.status === "offline" ? "The weather is unavailable"
            : "Looking up the weather"
        detail: WeatherService.status === "unknown" ? "Check the location in Settings › Weather."
            : WeatherService.status === "offline" ? "Speshell will try again in a few minutes."
            : ""
        actionLabel: WeatherService.status === "offline" ? "Try again" : ""
        actionIconName: "refresh"
        onActivated: WeatherService.refresh()
    }

    // ── Now ──
    Item {
        visible: WeatherService.ready
        width: parent.width
        height: nowRow.height

        Row {
            id: nowRow
            spacing: Theme.spacingMedium

            AppIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: WeatherService.current.icon
                size: 44
                iconColor: Theme.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: WeatherService.temperatureText(WeatherService.current.temperature)
                font.pixelSize: Theme.fontSizeHuge
                font.family: Theme.fontFamily
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: Theme.text
            }
        }

        Column {
            anchors.left: nowRow.right
            anchors.leftMargin: Theme.spacingLarge
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingMicro

            Text {
                width: parent.width
                text: WeatherService.current.condition
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                width: parent.width
                text: "Feels like " + WeatherService.temperatureText(WeatherService.current.apparent)
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                color: Theme.subtextBright
            }

            Text {
                visible: root.today !== null
                width: parent.width
                text: root.today ? "High " + WeatherService.temperatureText(root.today.high)
                    + " · Low " + WeatherService.temperatureText(root.today.low) : ""
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                font.features: { "tnum": 1 }
                color: Theme.subtext
            }
        }
    }

    Row {
        visible: WeatherService.ready
        width: parent.width

        Stat {
            width: parent.width / 4
            iconName: "weather-humidity"
            text: Math.round(WeatherService.current.humidity) + "%"
            label: "Humidity"
        }

        Stat {
            width: parent.width / 4
            iconName: "weather-wind"
            text: Math.round(WeatherService.current.wind) + " " + WeatherService.windUnit
            label: "Wind"
        }

        Stat {
            width: parent.width / 4
            iconName: "weather-rain-chance"
            text: (root.today ? Math.round(root.today.rain) : 0) + "%"
            label: "Rain today"
        }

        Stat {
            width: parent.width / 4
            iconName: root.nextSun && root.nextSun.sunrise ? "weather-sunrise" : "weather-sunset"
            text: root.nextSun ? Qt.formatTime(root.nextSun.time, "HH:mm") : "–"
            label: root.nextSun && root.nextSun.sunrise ? "Sunrise" : "Sunset"
        }
    }

    Separator {}

    // ── The next hours ──
    Row {
        visible: WeatherService.ready
        width: parent.width

        Repeater {
            model: root.hours

            delegate: Column {
                id: hour

                required property var modelData

                width: parent.width / Math.max(1, root.hours.length)
                spacing: Theme.spacingTiny

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(hour.modelData.time, "HH:mm")
                    font.pixelSize: Theme.fontSizeCaption
                    font.family: Theme.fontFamily
                    font.features: { "tnum": 1 }
                    color: Theme.subtext
                }

                AppIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: hour.modelData.icon
                    size: Theme.iconSizeMedium
                    iconColor: Theme.subtextBright
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: WeatherService.temperatureText(hour.modelData.temperature)
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: Theme.text
                }

                // Kept for every hour, so the row stays level.
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: hour.modelData.rain >= 10 ? 1 : 0
                    text: hour.modelData.rain + "%"
                    font.pixelSize: Theme.fontSizeMicro
                    font.family: Theme.fontFamily
                    font.features: { "tnum": 1 }
                    color: Theme.sky
                }
            }
        }
    }

    Separator {}

    // ── The coming days ──
    Column {
        visible: WeatherService.ready
        width: parent.width

        Repeater {
            model: root.days

            delegate: Item {
                id: day

                required property var modelData
                required property int index

                width: parent.width
                height: Math.max(Theme.controlHeightSmall + Theme.spacingTiny, dayName.implicitHeight + Theme.spacingSmall)

                Text {
                    id: dayName
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    text: day.index === 0 ? "Today" : Qt.formatDate(day.modelData.date, "ddd")
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.weight: day.index === 0 ? Font.DemiBold : Font.Normal
                    color: day.index === 0 ? Theme.accent : Theme.text
                }

                AppIcon {
                    id: dayIcon
                    anchors.left: dayName.right
                    anchors.verticalCenter: parent.verticalCenter
                    name: day.modelData.icon
                    size: Theme.iconSizeMedium
                    iconColor: Theme.subtextBright
                }

                Text {
                    id: dayRain
                    anchors.left: dayIcon.right
                    anchors.leftMargin: Theme.spacingTiny
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    opacity: day.modelData.rain >= 20 ? 1 : 0
                    text: Math.round(day.modelData.rain) + "%"
                    font.pixelSize: Theme.fontSizeCaption
                    font.family: Theme.fontFamily
                    font.features: { "tnum": 1 }
                    color: Theme.sky
                }

                Text {
                    id: dayLow
                    anchors.left: dayRain.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    horizontalAlignment: Text.AlignRight
                    text: WeatherService.temperatureText(day.modelData.low)
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.features: { "tnum": 1 }
                    color: Theme.subtext
                }

                // The day's low to high, on the week's scale.
                Item {
                    anchors.left: dayLow.right
                    anchors.leftMargin: Theme.spacingSmall
                    anchors.right: dayHigh.left
                    anchors.rightMargin: Theme.spacingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.controlFill
                    }

                    Rectangle {
                        readonly property real span: Math.max(1, root.weekHigh - root.weekLow)

                        x: parent.width * (day.modelData.low - root.weekLow) / span
                        width: Math.max(height, parent.width * (day.modelData.high - day.modelData.low) / span)
                        height: parent.height
                        radius: height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.alpha(Theme.accent, 0.45) }
                            GradientStop { position: 1; color: Theme.accent }
                        }
                    }
                }

                Text {
                    id: dayHigh
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    horizontalAlignment: Text.AlignRight
                    text: WeatherService.temperatureText(day.modelData.high)
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: Theme.text
                }
            }
        }
    }

    component Separator: Rectangle {
        visible: WeatherService.ready
        width: parent ? parent.width : 0
        height: Theme.separatorThickness
        color: Theme.separator
    }

    // A small icon and its value over what it measures.
    component Stat: Column {
        id: stat

        property string iconName: ""
        property string text: ""
        property string label: ""

        spacing: Theme.spacingMicro

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingTiny

            AppIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: stat.iconName
                size: Theme.iconSizeSmall
                iconColor: Theme.subtextBright
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: stat.text
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: Theme.text
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: stat.label
            font.pixelSize: Theme.fontSizeMicro
            font.family: Theme.fontFamily
            color: Theme.subtext
        }
    }
}
