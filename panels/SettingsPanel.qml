pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.panels.settings
import qs.services
import qs.theme

// Speshell's settings in pages, each saved to config.ini as it changes.
Card {
    id: root

    property bool presented: false
    property string activePage: "general"
    readonly property var pages: [
        { id: "general", label: "General", icon: "settings" },
        { id: "appearance", label: "Appearance", icon: "palette" },
        { id: "bar", label: "Bar", icon: "bar" },
        { id: "launcher", label: "Launcher", icon: "search" },
        { id: "about", label: "About", icon: "info" }
    ]
    readonly property var pageComponents: ({
        general: generalPage,
        appearance: appearancePage,
        bar: barPage,
        launcher: launcherPage,
        about: aboutPage
    })

    // Untyped, for the property only some pages have.
    readonly property var pageItem: page.item

    title: "Settings"
    iconName: "config"

    onActivePageChanged: pageEnter.restart()

    headerActions: Row {
        spacing: Theme.spacingTiny
        opacity: savedTimer.running ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration }
        }

        AppIcon {
            name: "check"
            size: Theme.iconSizeTiny
            iconColor: Theme.success
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "Saved"
            font.pixelSize: Theme.fontSizeCaption
            font.family: Theme.fontFamily
            color: Theme.success
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Timer {
        id: savedTimer
        interval: 1600
    }

    Connections {
        target: ConfigService

        function onSavingConfigChanged() {
            if (!ConfigService.savingConfig && !ConfigService.operationFailed)
                savedTimer.restart();
        }
    }

    FontMetrics {
        id: tabMetrics
        font.pixelSize: Theme.fontSizeSmall
        font.family: Theme.fontFamily
        font.bold: true
    }

    // Page tabs: the current one shows its name, the others share the remaining width.
    Item {
        id: tabStrip

        readonly property int gap: Theme.spacingTiny
        readonly property int activeIndex: Math.max(0, root.pages.findIndex(entry => entry.id === root.activePage))
        // Reading the font keeps this current when the text scale changes.
        readonly property real activeWidth: Math.min(
            tabStrip.width - (Theme.controlHeight + tabStrip.gap) * (root.pages.length - 1),
            Theme.iconSizeSmall + Theme.spacingTiny
                + Math.ceil(tabMetrics.advanceWidth(root.pages[tabStrip.activeIndex].label))
                + Theme.spacingMedium * 2)
        readonly property real restWidth: (tabStrip.width - tabStrip.activeWidth - tabStrip.gap * (root.pages.length - 1))
            / (root.pages.length - 1)

        width: parent.width
        height: Math.max(Theme.controlHeight, tabMetrics.height + Theme.spacingSmall * 2)

        Repeater {
            model: root.pages

            delegate: Rectangle {
                id: tab

                required property var modelData
                required property int index
                readonly property bool current: tab.index === tabStrip.activeIndex

                x: tab.index <= tabStrip.activeIndex
                    ? tab.index * (tabStrip.restWidth + tabStrip.gap)
                    : (tab.index - 1) * (tabStrip.restWidth + tabStrip.gap) + tabStrip.activeWidth + tabStrip.gap
                width: tab.current ? tabStrip.activeWidth : tabStrip.restWidth
                height: tabStrip.height
                radius: Theme.borderRadiusSmall
                clip: true
                color: tab.current
                    ? Theme.alpha(Theme.accent, Theme.tintStrong)
                    : (tabMouse.containsMouse ? Theme.cardHover : Theme.controlFill)
                border.width: Theme.borderWidth
                border.color: tab.current ? Theme.selectedBorder : "transparent"

                Behavior on x {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
                }
                Behavior on width {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
                }

                Accessible.role: Accessible.PageTab
                Accessible.name: tab.modelData.label
                Accessible.selected: tab.current
                Accessible.onPressAction: root.activePage = tab.modelData.id

                Row {
                    anchors.centerIn: parent
                    spacing: tab.current ? Theme.spacingTiny : 0

                    AppIcon {
                        name: tab.modelData.icon
                        size: Theme.iconSizeSmall
                        iconColor: tab.current
                            ? Theme.accent
                            : (tabMouse.containsMouse ? Theme.text : Theme.subtext)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        width: Math.min(implicitWidth, tab.width - Theme.iconSizeSmall
                            - Theme.spacingTiny - Theme.spacingSmall * 2)
                        elide: Text.ElideRight
                        visible: tab.current
                        opacity: tab.current ? 1 : 0
                        text: tab.modelData.label
                        font: tabMetrics.font
                        color: Theme.text
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.animDuration }
                        }
                    }
                }

                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activePage = tab.modelData.id
                }

                Tooltip {
                    visible: !tab.current && tabMouse.containsMouse
                    text: tab.modelData.label
                }
            }
        }
    }

    Notice {
        visible: ConfigService.operationFailed && ConfigService.operationMessage !== ""
        detail: ConfigService.operationMessage
        toneColor: Theme.error
    }

    Loader {
        id: page

        width: parent.width
        sourceComponent: root.pageComponents[root.activePage]

        onLoaded: {
            if ("presented" in root.pageItem)
                root.pageItem.presented = Qt.binding(() => root.presented);
        }

        ParallelAnimation {
            id: pageEnter

            NumberAnimation {
                target: page
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.animDuration
            }
            NumberAnimation {
                target: page
                property: "x"
                from: Theme.spacingSmall
                to: 0
                duration: Theme.animDuration
                easing.type: Theme.animEasing
            }
        }
    }

    Component {
        id: generalPage
        GeneralPage {}
    }

    Component {
        id: appearancePage
        AppearancePage {}
    }

    Component {
        id: barPage
        BarPage {}
    }

    Component {
        id: launcherPage
        LauncherPage {}
    }

    Component {
        id: aboutPage
        AboutPage {}
    }
}
