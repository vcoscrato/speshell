pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services
import qs.theme
import "../../services/ThemeProvider.js" as ThemeProvider

// The themes, each previewed in its own colors over its wallpaper; the active theme's
// wallpapers; and how wallpapers and effects behave.
Column {
    id: root

    property bool presented: false
    readonly property bool wallpapersShown: ThemeService.wallpaperEnabled
    readonly property var ownWallpapers: ThemeService.wallpapers.filter(wallpaper => wallpaper.theme === ThemeService.themeId)
    readonly property var shuffleOptions: [
        { value: "off", label: "Off" },
        { value: "wallpaper", label: "Wallpaper" },
        { value: "theme", label: "Theme" },
        { value: "both", label: "Theme and wallpaper" }
    ]
    readonly property var powerOptions: [
        { value: "maximum", label: "Maximum" },
        { value: "balanced", label: "Balanced" },
        { value: "saver", label: "Saver" }
    ]

    spacing: Theme.spacingSmall

    // Pick up theme folders added since the last scan.
    onPresentedChanged: if (root.presented) ThemeService.scan()

    Item {
        width: parent.width
        height: Theme.controlHeightSmall

        Label {
            role: "section"
            anchors.verticalCenter: parent.verticalCenter
            text: "Themes"
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingTiny

            HeaderButton {
                visible: root.wallpapersShown && root.ownWallpapers.length > 1
                iconName: "shuffle"
                tooltipText: "Another wallpaper from this theme"
                onClicked: ThemeService.shuffle("")
            }

            HeaderButton {
                iconName: "refresh"
                busy: ThemeService.scanning
                tooltipText: "Look for new themes"
                onClicked: ThemeService.scan()
            }
        }
    }

    Grid {
        id: tiles
        readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

        width: parent.width
        columns: 2
        spacing: Theme.spacingSmall

        Repeater {
            model: ThemeService.themes

            delegate: ThemeTile {
                width: tiles.cellWidth
            }
        }
    }

    Item {
        width: 1
        height: Theme.spacingTiny
        visible: wallpaperGrid.visible
    }

    Label {
        role: "section"
        visible: wallpaperGrid.visible
        text: ThemeService.theme.name + " wallpapers"
    }

    Grid {
        id: wallpaperGrid
        readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

        visible: root.wallpapersShown && root.ownWallpapers.length > 0
        width: parent.width
        columns: 3
        spacing: Theme.spacingSmall

        Repeater {
            model: root.wallpapersShown ? root.ownWallpapers : []

            delegate: Rectangle {
                id: wallpaperCell

                required property var modelData
                readonly property bool current: wallpaperCell.modelData.path === ThemeService.wallpaper

                width: wallpaperGrid.cellWidth
                height: Math.round(wallpaperGrid.cellWidth * 10 / 16)
                radius: Theme.borderRadius
                color: Theme.controlFill
                clip: true

                Accessible.role: Accessible.Button
                Accessible.name: "Use wallpaper " + wallpaperCell.modelData.title
                Accessible.onPressAction: ThemeService.setWallpaper(wallpaperCell.modelData.path)

                Image {
                    anchors.fill: parent
                    source: ThemeProvider.fileUrl(wallpaperCell.modelData.path)
                    sourceSize: Qt.size(256, 160)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: wallpaperMouse.containsMouse ? Theme.alpha(Theme.text, 0.12) : "transparent"
                    border.width: wallpaperCell.current ? 2 : Theme.borderWidth
                    border.color: wallpaperCell.current ? Theme.accent : Theme.controlBorder
                }

                MouseArea {
                    id: wallpaperMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!wallpaperCell.current)
                            EffectsService.picked(wallpaperCell, wallpaperMouse);
                        ThemeService.setWallpaper(wallpaperCell.modelData.path);
                    }
                }
            }
        }
    }

    Item {
        width: 1
        height: Theme.spacingTiny
    }

    SettingRow {
        label: "Draw wallpaper"
        info: "Show the theme's wallpaper on the desktop. Turn off if another app sets your wallpaper."

        ToggleSwitch {
            checked: ThemeService.wallpaperEnabled
            tooltipText: "Draw wallpaper"
            onToggled: on => ConfigService.setProperty("Appearance", "drawWallpaper", on ? "true" : "false")
        }
    }

    SettingRow {
        label: "Shuffle at launch"
        info: "Pick a random wallpaper, theme, or both each time Speshell starts."

        SelectMenu {
            options: root.shuffleOptions
            currentValue: ThemeService.launchShuffle || "off"
            onValueSelected: value => ConfigService.setProperty("Appearance", "shuffleAtLaunch", value)
        }
    }

    SettingRow {
        label: "Power use"
        info: "Maximum animates the theme's effects at your display's refresh rate, Balanced at 60 fps. "
            + "Saver turns them off along with the interface's motion. Saving modes also look less often "
            + "for recordings started outside Speshell. The sliders set how fast each kind of effect plays."

        SelectMenu {
            options: root.powerOptions
            currentValue: PowerService.mode
            onValueSelected: value => ConfigService.setProperty("Power", "mode", value)
        }
    }

    Row {
        id: speeds
        readonly property real columnWidth: (width - spacing * 2) / 3

        enabled: EffectsService.enabled
        opacity: enabled ? 1 : Theme.disabledOpacity
        width: parent.width
        spacing: Theme.spacingMedium

        Repeater {
            model: [
                { speed: "launcherSpeed", key: "launcherTransitionSpeed", label: "Launcher" },
                { speed: "controlsSpeed", key: "controlEffectsSpeed", label: "Controls" },
                { speed: "wallpaperSpeed", key: "wallpaperTransitionSpeed", label: "Wallpaper" }
            ]

            StepSlider {
                id: speed
                required property var modelData

                width: speeds.columnWidth
                label: speed.modelData.label
                from: 0
                to: 2
                value: EffectsService[speed.modelData.speed]
                format: value => value <= 0 ? "Off" : value + "×"
                onCommitted: value => ConfigService.setProperty("Appearance", speed.modelData.key, value)
            }
        }
    }

    // A theme, previewed in its own colors over the wallpaper it comes with: a bar
    // across the top and a dropdown under it.
    component ThemeTile: Rectangle {
        id: tile

        required property var modelData
        readonly property bool current: tile.modelData.id === ThemeService.themeId
        readonly property var colors: Theme.mergePalette(tile.modelData.colors)
        readonly property string wallpaperPath: tile.current
            ? ThemeService.wallpaper
            : ThemeService.wallpaperFor(tile.modelData.id)

        height: preview.height + nameRow.height + Theme.spacingSmall * 2
        radius: Theme.borderRadius
        color: tileMouse.containsMouse
            ? Theme.cardHover
            : (tile.current ? Theme.selectedFill : Theme.controlFill)
        border.width: tile.current ? 2 : Theme.borderWidth
        border.color: tile.current ? Theme.accent : Theme.controlBorder

        Accessible.role: Accessible.Button
        Accessible.name: "Use theme " + tile.modelData.name
        Accessible.description: tile.current ? "Current theme" : "Switch theme"
        Accessible.onPressAction: ThemeService.setTheme(tile.modelData.id)

        Rectangle {
            id: preview

            readonly property real unit: preview.width / 100

            x: Theme.spacingTiny + 1
            y: Theme.spacingTiny + 1
            width: tile.width - x * 2
            height: Math.round(preview.width * 10 / 16)
            radius: Theme.borderRadius
            clip: true
            gradient: Gradient {
                GradientStop { position: 0; color: tile.colors.base }
                GradientStop { position: 1; color: tile.colors.crust }
            }

            Image {
                anchors.fill: parent
                visible: tile.wallpaperPath !== ""
                source: tile.wallpaperPath !== "" ? ThemeProvider.fileUrl(tile.wallpaperPath) : ""
                sourceSize: Qt.size(320, 200)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            // The bar: the mark and two workspaces, the clock, and a few buttons.
            Rectangle {
                id: miniBar
                width: parent.width
                height: Math.round(preview.unit * 7)
                color: tile.colors.base
                border.width: 1
                border.color: tile.colors.surface1

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: preview.unit * 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: preview.unit * 1.5

                    Rectangle {
                        width: preview.unit * 3
                        height: width
                        radius: 1
                        color: tile.colors.accent
                    }

                    Repeater {
                        model: 2

                        delegate: Rectangle {
                            required property int index

                            width: preview.unit * 3
                            height: width
                            radius: 1
                            color: index === 0 ? Theme.alpha(tile.colors.accent, 0.35) : tile.colors.surface0
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: preview.unit * 16
                    height: preview.unit * 1.8
                    radius: height / 2
                    color: Theme.alpha(tile.colors.text, 0.8)
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: preview.unit * 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: preview.unit * 1.5

                    Repeater {
                        model: 4

                        delegate: Rectangle {
                            required property int index

                            width: preview.unit * 2.2
                            height: width
                            radius: width / 2
                            color: index === 1 ? tile.colors.accent : Theme.alpha(tile.colors.text, 0.55)
                        }
                    }
                }
            }

            // A dropdown under the bar: a header, a selected row, plain rows, a slider,
            // and a switch.
            Rectangle {
                id: miniPanel

                readonly property real pad: preview.unit * 3

                anchors.right: parent.right
                anchors.rightMargin: preview.unit * 4
                y: miniBar.height + preview.unit * 2
                width: preview.unit * 40
                height: miniColumn.height + miniPanel.pad * 2
                color: tile.colors.base
                border.width: 1
                border.color: tile.colors.surface1

                Column {
                    id: miniColumn
                    x: miniPanel.pad
                    y: miniPanel.pad
                    width: parent.width - miniPanel.pad * 2
                    spacing: preview.unit * 2

                    Rectangle {
                        width: parent.width * 0.45
                        height: preview.unit * 1.6
                        radius: height / 2
                        color: Theme.alpha(tile.colors.text, 0.75)
                    }

                    Repeater {
                        model: 3

                        delegate: Rectangle {
                            id: miniRow

                            required property int index
                            readonly property bool selected: miniRow.index === 0

                            width: miniColumn.width
                            height: preview.unit * 6
                            radius: 1
                            color: miniRow.selected ? Theme.alpha(tile.colors.accent, 0.18) : tile.colors.surface0
                            border.width: miniRow.selected ? 1 : 0
                            border.color: Theme.alpha(tile.colors.accent, 0.7)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: preview.unit * 1.5
                                anchors.verticalCenter: parent.verticalCenter
                                width: miniRow.width * (miniRow.selected ? 0.5 : 0.35 + 0.1 * miniRow.index)
                                height: preview.unit
                                radius: height / 2
                                color: miniRow.selected ? tile.colors.accent : Theme.alpha(tile.colors.text, 0.45)
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: preview.unit * 4

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: miniSwitch.left
                            anchors.rightMargin: preview.unit * 2
                            anchors.verticalCenter: parent.verticalCenter
                            height: preview.unit * 1.4
                            radius: height / 2
                            color: tile.colors.surface2

                            Rectangle {
                                width: parent.width * 0.6
                                height: parent.height
                                radius: parent.radius
                                color: tile.colors.accent
                            }
                        }

                        Rectangle {
                            id: miniSwitch
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: preview.unit * 7
                            height: preview.unit * 4
                            radius: height / 2
                            color: tile.colors.accent

                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: preview.unit * 0.6
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.height - preview.unit * 1.2
                                height: width
                                radius: width / 2
                                color: tile.colors.base
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: nameRow
            anchors.left: preview.left
            anchors.right: preview.right
            anchors.top: preview.bottom
            anchors.topMargin: Theme.spacingTiny
            height: Math.max(nameText.implicitHeight, checkIcon.height) + Theme.spacingMicro

            Rectangle {
                id: accentDot
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingMicro
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: tile.colors.accent
            }

            Label {
                id: nameText
                anchors.left: accentDot.right
                anchors.leftMargin: Theme.spacingSmall - 2
                anchors.right: checkIcon.visible ? checkIcon.left : parent.right
                anchors.rightMargin: Theme.spacingTiny
                anchors.verticalCenter: parent.verticalCenter
                text: tile.modelData.name
                font.weight: tile.current ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }

            AppIcon {
                id: checkIcon
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                name: "check"
                size: Theme.iconSizeTiny
                iconColor: Theme.accent
                visible: tile.current
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!tile.current)
                    EffectsService.picked(tile, tileMouse);
                ThemeService.setTheme(tile.modelData.id);
            }
        }
    }
}
