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

        Label {
            role: "caption"
            text: "Saved"
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
        height: Theme.controlHeightSmall

        Repeater {
            model: root.pages

            delegate: Tab {
                id: tab

                required property var modelData
                required property int index

                x: tab.index <= tabStrip.activeIndex
                    ? tab.index * (tabStrip.restWidth + tabStrip.gap)
                    : (tab.index - 1) * (tabStrip.restWidth + tabStrip.gap) + tabStrip.activeWidth + tabStrip.gap
                width: tab.current ? tabStrip.activeWidth : tabStrip.restWidth
                height: tabStrip.height
                text: tab.modelData.label
                iconName: tab.modelData.icon
                current: tab.index === tabStrip.activeIndex
                showText: tab.current
                onClicked: root.activePage = tab.modelData.id

                Behavior on x {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
                }
                Behavior on width {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
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
