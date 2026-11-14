pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import qs.components
import qs.services
import "../components/Format.js" as Format

// The System window: what this machine's modules declare, module by module, what differs
// on it, and what Apply would do. Every change goes through SystemService into the
// modules' .conf files. Apply and Update run here, and while one runs, the page is the
// run: its steps, its output, and what it asks. Follows SystemService.shown; its page
// exists only while it shows.
ModalWindow {
    id: root

    // "overview", "aur", or a module's id.
    property string selected: "overview"
    // Where Add puts a package: the module last picked, while it is on.
    property string target: ""
    // Mapped, until the panel has faded out.
    property bool presenting: false

    readonly property bool opened: SystemService.shown
    // An apply or update here, running or with its result unseen.
    readonly property bool showingRun: SystemService.runState !== ""
    readonly property string query: searchField.text.trim()
    readonly property var steps: SystemService.plan
    readonly property bool broken: SystemService.errors.length > 0
    readonly property var onModules: SystemService.modules.filter(module => module.on).map(module => module.id)
    readonly property string targetModule: root.onModules.includes(root.target) ? root.target : (root.onModules[0] || "")
    readonly property string hostName: SystemService.host.charAt(0).toUpperCase() + SystemService.host.slice(1)
    readonly property var selectedModule: SystemService.modules.find(module => module.id === root.selected) || null
    readonly property int declaredCount: Object.keys(root.declaredHere()).length
    // What the edit button opens: the .conf of the module shown, or this machine's.
    readonly property string editedFile: root.selectedModule && root.query === "" && !root.showingRun
        ? root.selectedModule.file : SystemService.machine !== "" ? SystemService.machine + ".conf" : ""
    // The time now, for how long ago the last apply was, kept while the window shows.
    property double nowMs: Date.now()
    readonly property string appliedText: SystemService.appliedAt > 0
        ? "Last applied " + Format.ago(SystemService.appliedAt, root.nowMs) : "Not applied here yet"

    // The search: what the modules have that matches, then what the repositories and the
    // AUR offer besides, which the arrow keys walk and Enter adds from.
    readonly property var searchDeclared: {
        const needle = root.query.toLowerCase();
        const found = [];
        if (needle === "")
            return found;
        for (const module of SystemService.modules)
            for (const pkg of module.packages)
                if (pkg.name.includes(needle))
                    found.push({ name: pkg.name, module: module.id, on: module.on, installed: pkg.installed });
        return found.sort((a, b) => a.name.localeCompare(b.name));
    }
    readonly property var searchRepos: {
        const declared = root.declaredHere();
        return SystemService.repoResults.filter(pkg => !declared[pkg.name]);
    }
    readonly property var searchAur: {
        const skip = root.declaredHere();
        for (const pkg of SystemService.repoResults)
            skip[pkg.name] = true;
        return SystemService.aurResults.filter(pkg => !skip[pkg.name]);
    }
    readonly property var searchOffered: root.searchRepos.concat(root.searchAur)
    property int searchIndex: 0
    // Whether the arrow keys picked it, so the page follows; the pointer's pick stays put.
    property bool searchByKeys: false

    // The names of the packages the modules on here declare, as a set.
    function declaredHere() {
        const names = {};
        for (const module of SystemService.modules)
            if (module.on)
                for (const pkg of module.packages)
                    names[pkg.name] = true;
        return names;
    }

    function addOffered(index) {
        const pkg = root.searchOffered[index];
        if (pkg && root.targetModule !== "")
            SystemService.addPackage(pkg.name, root.targetModule);
    }

    // Scrolls the page so ITEM shows whole.
    function reveal(item) {
        const top = item.mapToItem(pageLoader, 0, 0).y;
        if (top < content.contentY)
            content.contentY = top;
        else if (top + item.height > content.contentY + content.height)
            content.contentY = top + item.height - content.height;
    }

    function pick(id) {
        SystemService.dismissRun();
        searchField.text = "";
        root.selected = id;
        if (id !== "overview" && id !== "aur")
            root.target = id;
    }

    // A row of a module's page for ITEMS ({ title, note, pillText, error }): the one item
    // after VERB, or their count and NOUN, opening to list them, with what of them waits
    // on an apply or differs.
    function fold(iconName, verb, noun, items) {
        if (items.length === 0)
            return null;
        if (items.length === 1)
            return {
                iconName: iconName, title: verb + " " + items[0].title, note: items[0].note || "",
                pillText: items[0].pillText || "", error: items[0].error === true, file: items[0].file || "", items: []
            };
        const differing = items.filter(item => item.error).length;
        const waiting = items.filter(item => (item.pillText || "") !== "").length;
        return {
            iconName: iconName, title: verb + " " + items.length + " " + noun, note: "",
            pillText: differing > 0 ? (differing === 1 ? "1 differs" : differing + " differ") : waiting > 0 ? waiting + " on apply" : "",
            error: differing > 0, items: items
        };
    }

    function stepIcon(kind) {
        return ({
            disable: "power", leave: "users", unlinger: "restart",
            install: "plus", explicit: "check", demote: "back", remove: "trash",
            link: "link", copy: "lock", mode: "lock", unlink: "link", delete: "trash",
            trigger: "refresh", join: "users", linger: "restart", enable: "power", run: "tools"
        })[kind] || "info";
    }

    // Opens FILE of the modules' directory in your editor, and steps aside for it.
    function openFile(file) {
        SystemService.openFile(file);
        SystemService.close();
    }

    visible: root.presenting && root.targetScreen !== null
    WlrLayershell.namespace: "speshell-system"
    takesKeyboard: root.opened
    focusGrabActive: root.opened

    onOpenedChanged: {
        if (!root.opened)
            return;
        root.targetScreen = HyprlandService.focusedScreen();
        root.presenting = true;
        root.nowMs = Date.now();
        searchField.text = "";
        if (!root.showingRun)
            searchField.focusInput();
    }

    Timer {
        interval: 60 * 1000
        repeat: true
        running: root.presenting
        onTriggered: root.nowMs = Date.now()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.crust, 0.30)
        opacity: panel.opacity

        MouseArea {
            anchors.fill: parent
            onClicked: SystemService.close()
        }
    }

    Item {
        id: panel

        anchors.centerIn: parent
        width: Math.min(980, root.width - Theme.spacingXL * 2)
        height: Math.min(680, root.height - Theme.spacingXL * 4)
        opacity: root.opened ? 1 : 0
        scale: root.opened ? 1 : 0.98

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast; easing.type: Theme.animEasing }
        }

        Behavior on scale {
            NumberAnimation { duration: Theme.animDurationFast; easing.type: Theme.animEasing }
        }

        onOpacityChanged: {
            if (panel.opacity === 0 && !root.opened)
                root.presenting = false;
        }

        Surface {
            anchors.fill: parent
            backdrop: true
            rounded: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => mouse.accepted = true
        }

        // ── Header ──────────────────────────────────────────────
        Item {
            id: header

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingLarge
            height: Theme.controlHeight

            IconDisc {
                id: titleDisc
                anchors.verticalCenter: parent.verticalCenter
                iconName: "package"
                lit: true
            }

            Column {
                anchors.left: titleDisc.right
                anchors.leftMargin: Theme.spacingMedium
                anchors.right: headerActions.left
                anchors.rightMargin: Theme.spacingMedium
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingMicro

                Label {
                    role: "heading"
                    text: "System"
                }

                Label {
                    width: parent.width
                    role: "caption"
                    elide: Text.ElideRight
                    text: SystemService.machine !== ""
                        ? root.hostName + " · " + root.declaredCount + " packages in " + root.onModules.length + " modules"
                        : "~/.config/speshell/system"
                }
            }

            Row {
                id: headerActions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingSmall

                Field {
                    id: searchField
                    width: 300
                    visible: SystemService.machine !== "" && !root.showingRun
                    iconName: "search"
                    placeholder: "Find or add a package"
                    clearable: true
                    onTextChanged: {
                        root.searchIndex = 0;
                        SystemService.search(searchField.text);
                    }
                    onAccepted: root.addOffered(root.searchIndex)
                    onKeyPressed: event => {
                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                            const last = root.searchOffered.length - 1;
                            root.searchByKeys = true;
                            root.searchIndex = Math.max(0, Math.min(last, root.searchIndex + (event.key === Qt.Key_Down ? 1 : -1)));
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            if (searchField.text !== "")
                                searchField.text = "";
                            else
                                SystemService.close();
                            event.accepted = true;
                        }
                    }
                }

                HeaderButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.editedFile !== ""
                    iconName: "notes"
                    tooltipText: "Open " + root.editedFile
                    onClicked: root.openFile(root.editedFile)
                }

                HeaderButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "close"
                    tooltipText: "Close"
                    onClicked: SystemService.close()
                }
            }
        }

        // ── Modules ─────────────────────────────────────────────
        Column {
            id: sidebar

            anchors.left: parent.left
            anchors.top: header.bottom
            anchors.bottom: footer.visible ? footer.top : parent.bottom
            anchors.leftMargin: Theme.spacingLarge
            anchors.topMargin: Theme.spacingLarge
            anchors.bottomMargin: footer.visible ? Theme.spacingXL : Theme.spacingLarge
            width: 220
            spacing: Theme.spacingMicro
            visible: SystemService.machine !== ""
            // A run holds the page until it ends.
            enabled: !SystemService.runActive
            opacity: enabled ? 1 : Theme.disabledOpacity

            SidebarRow {
                title: "Overview"
                count: SystemService.decisions + SystemService.errors.length
                current: root.selected === "overview" && root.query === "" && !root.showingRun
                onPicked: root.pick("overview")
            }

            SidebarRow {
                visible: SystemService.aur.length > 0
                title: "From the AUR"
                detail: String(SystemService.aur.length)
                current: root.selected === "aur" && root.query === "" && !root.showingRun
                onPicked: root.pick("aur")
            }

            Label {
                role: "section"
                leftPadding: Theme.spacingSmall
                topPadding: Theme.spacingMedium
                bottomPadding: Theme.spacingTiny
                text: "Modules"
            }

            Repeater {
                model: SystemService.modules

                SidebarRow {
                    required property var modelData

                    title: modelData.id
                    detail: !modelData.on ? "off" : modelData.packages.length > 0 ? String(modelData.packages.length) : ""
                    dimmed: !modelData.on
                    pending: modelData.pending > 0
                    current: root.selected === modelData.id && root.query === "" && !root.showingRun
                    onPicked: root.pick(modelData.id)
                }
            }
        }

        Rectangle {
            anchors.left: sidebar.right
            anchors.leftMargin: Theme.spacingMedium
            anchors.top: sidebar.top
            anchors.bottom: sidebar.bottom
            width: Theme.separatorThickness
            color: Theme.separator
            visible: sidebar.visible
        }

        // ── Content ─────────────────────────────────────────────
        Item {
            id: body

            anchors.left: sidebar.visible ? sidebar.right : parent.left
            anchors.right: parent.right
            anchors.top: sidebar.top
            anchors.bottom: sidebar.bottom
            anchors.leftMargin: sidebar.visible ? Theme.spacingMedium * 2 + Theme.separatorThickness : Theme.spacingLarge
            anchors.rightMargin: Theme.spacingLarge - Theme.spacingSmall

            Notice {
                id: editNotice
                anchors.top: parent.top
                width: parent.width - Theme.spacingSmall
                visible: SystemService.errorText !== "" && SystemService.status !== null
                detail: SystemService.errorText
                toneColor: Theme.error
                trailing: HeaderButton {
                    iconName: "close"
                    tooltipText: "Dismiss"
                    onClicked: SystemService.errorText = ""
                }
            }

            Flickable {
                id: content

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: editNotice.visible ? editNotice.bottom : parent.top
                anchors.topMargin: editNotice.visible ? Theme.spacingSmall : 0
                anchors.bottom: parent.bottom
                contentHeight: pageLoader.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                StyledScrollBar.vertical: StyledScrollBar {}

                Loader {
                    id: pageLoader
                    active: root.presenting
                    width: content.width - Theme.spacingSmall
                    sourceComponent: SystemService.status === null ? loadingPage
                        : !SystemService.configured ? setupPage
                        : root.showingRun ? runPage
                        : SystemService.machine === "" && !root.broken ? hostPage
                        : root.query !== "" ? searchPage
                        : root.selected === "aur" ? aurPage
                        : root.selectedModule ? modulePage
                        : overviewPage
                }
            }
        }

        // ── What Apply does ─────────────────────────────────────
        Item {
            id: footer

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spacingLarge
            height: Theme.controlHeight
            visible: SystemService.machine !== "" && !root.showingRun

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.top
                anchors.bottomMargin: Theme.spacingMedium
                height: Theme.separatorThickness
                color: Theme.separator
            }

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingSmall
                visible: SystemService.running

                AppIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "loader"
                    spinning: true
                    size: Theme.iconSizeSmall
                    iconColor: Theme.subtext
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "caption"
                    text: "Running in the terminal…"
                }
            }

            Row {
                id: footerButtons
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingSmall

                ActionButton {
                    text: SystemService.updates > 0 ? "Update " + SystemService.updates : "Update"
                    iconName: "refresh"
                    enabled: !SystemService.running && !root.broken
                    tooltipText: SystemService.updates === 0 ? "Everything is up to date" : ""
                    onClicked: SystemService.update()
                }

                ActionButton {
                    text: "Apply"
                    iconName: "check"
                    kind: "primary"
                    enabled: root.steps.length > 0 && !root.broken && !SystemService.running
                    onClicked: SystemService.apply()
                }
            }
        }
    }

    // ── Pages ───────────────────────────────────────────────────
    Component {
        id: loadingPage

        // Blank for a moment, since the first read is usually done by then.
        EmptyState {
            id: loading

            property bool patient: false

            visible: loading.patient || SystemService.errorText !== ""
            busy: SystemService.errorText === ""
            iconName: "alert"
            title: SystemService.errorText === "" ? "Reading your modules" : "speshell system failed"
            detail: SystemService.errorText

            Timer {
                running: true
                interval: 400
                onTriggered: loading.patient = true
            }
        }
    }

    Component {
        id: setupPage

        EmptyState {
            iconName: "package"
            title: "No modules yet"
            detail: "Start this machine's module from every package it has explicitly installed, to sort into modules from there."
            actionLabel: "Start from this machine"
            actionIconName: "plus"
            onActivated: SystemService.init()
        }
    }

    Component {
        id: hostPage

        EmptyState {
            iconName: "device-laptop"
            title: "No module for " + root.hostName
            detail: "This machine applies " + SystemService.host + ".conf, whose use lines bring in your other modules. Start it from the packages this machine has."
            actionLabel: "Start from this machine"
            actionIconName: "plus"
            onActivated: SystemService.init()
        }
    }

    // The run: how it stands, what it asks, and its output, which a review of what paru
    // builds takes the place of.
    Component {
        id: runPage

        Item {
            id: run

            readonly property var request: SystemService.request
            readonly property bool reviewing: run.request !== null && run.request.kind === "review"
            readonly property bool failed: SystemService.runState === "failed"

            height: content.height

            PageHeading {
                id: runHeading

                iconName: run.request ? ({ password: "lock", secret: "lock", text: "info", review: "package" })[run.request.kind]
                    : SystemService.runActive ? "loader" : run.failed ? "alert" : "check"
                spinning: SystemService.runActive && !run.request
                toneColor: run.request ? Theme.warning : run.failed ? Theme.error : SystemService.runActive ? Theme.accent : Theme.success
                title: SystemService.runActive
                    ? (SystemService.runKind === "update" ? "Updating " + root.hostName : "Applying your modules")
                    : run.failed ? (SystemService.runKind === "update" ? "The update stopped" : "Apply stopped")
                    : SystemService.runKind === "update" ? root.hostName + " is up to date"
                    : root.hostName + " is in sync"
                caption: run.request ? "Waiting for you"
                    : SystemService.runActive ? SystemService.runStep || "Starting"
                    : run.failed ? SystemService.runLast
                    : "Every step ran"

                ActionButton {
                    visible: run.failed
                    text: "Open in terminal"
                    iconName: "apps"
                    tooltipText: "Run it again where you can answer what it asks"
                    onClicked: SystemService.retryInTerminal()
                }

                ActionButton {
                    visible: !SystemService.runActive
                    text: "Done"
                    kind: "primary"
                    onClicked: SystemService.dismissRun()
                }
            }

            // Sized by hand, as a Loader keeps its last item's height once it unloads.
            Loader {
                id: question
                anchors.top: runHeading.bottom
                anchors.topMargin: active ? Theme.spacingLarge : 0
                width: parent.width
                height: active && item ? item.implicitHeight : 0
                active: run.request !== null && !run.reviewing
                sourceComponent: QuestionCard {}
            }

            Loader {
                anchors.top: runHeading.bottom
                anchors.topMargin: Theme.spacingLarge
                anchors.bottom: parent.bottom
                width: parent.width
                active: run.reviewing
                sourceComponent: ReviewView {}
            }

            RunLog {
                anchors.top: question.bottom
                anchors.topMargin: Theme.spacingLarge
                anchors.bottom: parent.bottom
                width: parent.width
                visible: !run.reviewing
            }
        }
    }

    // Where the machine stands, then what waits on you: what in the modules doesn't read,
    // packages no module declares, home files that differ from their module's, and Apply's steps.
    Component {
        id: overviewPage

        Column {
            spacing: 0

            PageHeading {
                iconName: root.broken ? "alert" : root.steps.length > 0 ? "refresh" : "check"
                toneColor: root.broken ? Theme.error : root.steps.length > 0 ? Theme.accent : Theme.success
                title: root.broken
                    ? (SystemService.errors.length === 1 ? "1 problem to fix" : SystemService.errors.length + " problems to fix")
                    : root.steps.length === 1 ? "1 change to apply"
                    : root.steps.length > 1 ? root.steps.length + " changes to apply"
                    : root.hostName + " is in sync"
                caption: root.broken ? "Apply waits until your modules read cleanly" : root.appliedText
            }

            PageSection {
                title: "Problems"
                visible: root.broken
            }

            Repeater {
                model: root.broken ? SystemService.errors : []

                // Opens the file it is in.
                EntryRow {
                    required property var modelData

                    iconName: "alert"
                    title: modelData.message
                    note: modelData.file === "" ? "" : modelData.file + (modelData.line > 0 ? ", line " + modelData.line : "")
                    clickable: modelData.file !== ""
                    onClicked: root.openFile(modelData.file)
                }
            }

            PageSection {
                title: "Not in any module"
                count: SystemService.undeclared.length
                visible: SystemService.undeclared.length > 0
            }

            Repeater {
                model: SystemService.undeclared

                EntryRow {
                    id: looseRow

                    required property string modelData
                    readonly property bool leaving: SystemService.removals.includes(modelData)

                    iconName: "package"
                    title: modelData
                    note: SystemService.fromAur[modelData] ? "AUR" : ""
                    struck: looseRow.leaving
                    pillText: looseRow.leaving ? "removes on apply" : ""
                    pillTone: Theme.error
                    actionsOnHover: true

                    HeaderButton {
                        visible: !looseRow.leaving && root.targetModule !== ""
                        iconName: "plus"
                        tooltipText: "Add to " + root.targetModule
                        onClicked: SystemService.addPackage(looseRow.modelData, root.targetModule)
                    }

                    HeaderButton {
                        iconName: looseRow.leaving ? "back" : "trash"
                        tooltipText: looseRow.leaving ? "Keep it" : "Remove it on apply"
                        onClicked: SystemService.toggleRemoval(looseRow.modelData)
                    }
                }
            }

            PageSection {
                title: "Changed here"
                count: SystemService.drift.length
                visible: SystemService.drift.length > 0
            }

            Repeater {
                model: SystemService.drift

                EntryRow {
                    id: driftRow

                    required property var modelData
                    readonly property bool changed: modelData.reason === "changed"

                    iconName: "link"
                    title: modelData.target
                    note: driftRow.changed ? "differs from " + modelData.module + "'s" : "in the way of " + modelData.module + "'s file"
                    actionsOnHover: true

                    HeaderButton {
                        visible: driftRow.changed
                        iconName: "check"
                        tooltipText: "Keep this one in " + driftRow.modelData.module
                        onClicked: SystemService.adopt(driftRow.modelData.target)
                    }

                    HeaderButton {
                        visible: driftRow.changed
                        iconName: "back"
                        tooltipText: "Restore " + driftRow.modelData.module + "'s, keeping this one aside"
                        onClicked: SystemService.restore(driftRow.modelData.target)
                    }
                }
            }

            PageSection {
                title: "On apply"
                visible: root.steps.length > 0
            }

            Repeater {
                model: SystemService.groups(root.steps)

                // A kind of step; one of several steps opens to list them.
                FoldRow {
                    required property var modelData
                    readonly property bool single: modelData.steps.length === 1

                    iconName: root.stepIcon(modelData.kind)
                    title: single ? modelData.steps[0].text : modelData.text
                    items: single ? [] : modelData.steps.map(step => ({ title: step.text, note: step.module }))
                }
            }
        }
    }

    // What this machine has from the AUR, and where each comes from, to swap for one from
    // the repositories where there is one.
    Component {
        id: aurPage

        Column {
            spacing: 0

            PageHeading {
                iconName: SystemService.aur.length > 0 ? "package" : "check"
                toneColor: SystemService.aur.length > 0 ? Theme.warning : Theme.success
                title: SystemService.aur.length === 0 ? "Nothing from the AUR"
                    : SystemService.aur.length === 1 ? "1 package from the AUR"
                    : SystemService.aur.length + " packages from the AUR"
                caption: SystemService.aur.length > 0
                    ? "Built here from scripts anyone can publish; a repository's package is the safer pick"
                    : "Every package " + root.hostName + " has comes from its repositories"
            }

            Item {
                width: parent.width
                height: Theme.spacingMedium
                visible: SystemService.aur.length > 0
            }

            Repeater {
                model: SystemService.aur

                EntryRow {
                    id: aurRow

                    required property var modelData

                    iconName: "package"
                    title: modelData.name
                    note: modelData.module !== "" ? modelData.module
                        : modelData.explicit ? "not in any module" : "installed as a dependency"
                    pillText: modelData.installed ? "" : "installs on apply"
                    actionsOnHover: true

                    HeaderButton {
                        iconName: "search"
                        tooltipText: "Look for it in the repositories"
                        onClicked: searchField.text = aurRow.modelData.name.replace(/-(bin|git)$/, "")
                    }
                }
            }
        }
    }

    // A module: whether this machine uses it, what it does besides packages, folded to a
    // row a kind, and its packages in a grid.
    Component {
        id: modulePage

        Column {
            id: page

            readonly property var module: root.selectedModule
            readonly property int pending: page.module.pending
            // A row for each kind: the modules it brings in, its services, the groups it puts you in, whether it starts
            // your services at boot, the files it links and copies, the commands file changes
            // run, and the commands it runs once, each opening to list several.
            readonly property var folds: {
                const module = page.module;
                const fileStates = {
                    link: "links on apply", copy: "copies on apply", mode: "mode on apply",
                    changed: "differs", blocked: "in the way"
                };
                const fileItem = file => ({
                    title: file.target,
                    file: file.source,
                    pillText: module.on ? fileStates[file.state] || "" : "",
                    error: file.state === "changed" || file.state === "blocked"
                });
                const rows = [
                    root.fold("package", "Uses", "modules", module.uses.map(id => ({ title: id }))),
                    root.fold("power", "Enables", "services", module.services.map(service => ({
                        title: service.unit,
                        note: service.scope === "user" ? "yours" : "",
                        pillText: module.on && !service.enabled ? "enables on apply" : ""
                    }))),
                    root.fold("users", "Adds you to", "groups", module.groups.map(group => ({
                        title: group.name,
                        pillText: module.on && !group.member ? "joins on apply" : ""
                    }))),
                    module.linger ? {
                        iconName: "restart", title: "Starts your services at boot", note: "without a login",
                        pillText: "", error: false, items: []
                    } : null,
                    root.fold("link", "Links", "files into your home", module.files.filter(file => file.kind === "home").map(fileItem)),
                    root.fold("lock", "Copies", "files into /", module.files.filter(file => file.kind === "root").map(fileItem)),
                    root.fold("refresh", "Runs", "commands when files change", module.triggers.map(trigger => ({
                        title: trigger.command,
                        note: "when " + trigger.pattern + " changes"
                    }))),
                    root.fold("tools", "Runs", "commands once", module.runs.map(run => ({
                        title: run.command,
                        note: "once",
                        pillText: module.on && !run.done ? "runs on apply" : ""
                    })))
                ];
                return rows.filter(row => row !== null);
            }

            spacing: 0

            PageHeading {
                title: page.module.id
                caption: !page.module.on ? "Not used on " + root.hostName
                    : page.pending === 1 ? "1 change on apply"
                    : page.pending > 1 ? page.pending + " changes on apply" : ""

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.module.machine ? "This machine"
                        : page.module.via !== "" ? "Comes with " + page.module.via : "On " + root.hostName
                    color: Theme.subtext
                }

                ToggleSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !page.module.machine && page.module.via === ""
                    checked: page.module.on
                    tooltipText: "Use " + page.module.id + " on " + root.hostName
                    onToggled: state => SystemService.setModule(page.module.id, state)
                }
            }

            EmptyState {
                visible: page.module.packages.length === 0 && page.folds.length === 0
                iconName: "package"
                title: page.module.id + " is empty"
                detail: "Add packages to it from the search above, or lines to " + page.module.file + "."
            }

            PageSection {
                title: "What it sets up"
                visible: page.folds.length > 0
            }

            Repeater {
                model: page.folds

                FoldRow {
                    required property var modelData

                    iconName: modelData.iconName
                    title: modelData.title
                    note: modelData.note
                    pillText: modelData.pillText
                    pillTone: modelData.error ? Theme.error : Theme.warning
                    file: modelData.file || ""
                    items: modelData.items
                    dimmed: !page.module.on
                }
            }

            PageSection {
                title: "Packages"
                count: page.module.packages.length
                visible: page.module.packages.length > 0
            }

            Grid {
                id: packageGrid

                readonly property real cellWidth: (packageGrid.width - packageGrid.columnSpacing * (packageGrid.columns - 1)) / packageGrid.columns

                width: parent.width
                // Down each column first, so they read in the .conf's order.
                flow: Grid.TopToBottom
                columns: Math.max(1, Math.floor((packageGrid.width + packageGrid.columnSpacing) / (200 + packageGrid.columnSpacing)))
                rows: Math.ceil(page.module.packages.length / packageGrid.columns)
                columnSpacing: Theme.spacingTiny

                Repeater {
                    model: page.module.packages

                    PackageCell {
                        required property var modelData

                        width: packageGrid.cellWidth
                        name: modelData.name
                        note: modelData.note
                        fromAur: SystemService.fromAur[modelData.name] === true
                        installing: page.module.on && !modelData.installed
                        dimmed: !page.module.on
                    }
                }
            }
        }
    }

    // The search: what the modules have that matches, then what the repositories offer,
    // then the AUR's, which come a moment later. The arrow keys and the pointer pick one
    // to add, and Enter adds it.
    Component {
        id: searchPage

        Column {
            spacing: 0

            PageSection {
                title: "In your modules"
                count: root.searchDeclared.length
                visible: root.searchDeclared.length > 0
            }

            Repeater {
                model: root.searchDeclared

                EntryRow {
                    required property var modelData

                    iconName: "package"
                    title: modelData.name
                    note: [SystemService.fromAur[modelData.name] ? "AUR" : "",
                        modelData.on ? modelData.module : modelData.module + ", off on " + root.hostName].filter(part => part !== "").join(" · ")
                    dimmed: !modelData.on
                    pillText: modelData.on && !modelData.installed ? "installs on apply" : ""
                    clickable: true
                    onClicked: root.pick(modelData.module)
                }
            }

            PageSection {
                title: "Repositories"
                count: root.searchRepos.length
                visible: root.searchRepos.length > 0

                TargetMenu {}
            }

            Repeater {
                model: root.searchRepos

                ResultRow {
                    required property var modelData
                    required property int index

                    pkg: modelData
                    offset: index
                }
            }

            PageSection {
                title: "AUR"
                count: root.searchAur.length
                note: "built from scripts anyone can publish"
                visible: root.searchAur.length > 0 || SystemService.aurPending && root.searchRepos.length > 0

                TargetMenu {
                    visible: root.searchRepos.length === 0
                }
            }

            Repeater {
                model: root.searchAur

                ResultRow {
                    required property var modelData
                    required property int index

                    pkg: modelData
                    offset: root.searchRepos.length + index
                }
            }

            Row {
                visible: SystemService.aurPending && root.searchRepos.length > 0
                height: Theme.controlHeight
                leftPadding: Theme.spacingSmall
                spacing: Theme.spacingSmall

                AppIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "loader"
                    spinning: parent.visible
                    size: Theme.iconSizeSmall
                    iconColor: Theme.subtext
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "caption"
                    text: "Asking the AUR…"
                }
            }

            EmptyState {
                visible: SystemService.searching && root.searchOffered.length === 0 && root.searchDeclared.length === 0
                busy: true
                title: "Searching the repositories"
            }

            EmptyState {
                visible: !SystemService.searching && root.searchDeclared.length === 0 && root.searchOffered.length === 0
                iconName: "search"
                title: "Nothing for “" + root.query + "”"
                detail: "Neither your modules, the repositories, nor the AUR has a package like it."
            }
        }
    }

    // ── Parts ───────────────────────────────────────────────────
    // A row of the sidebar: the overview, with what waits on you, or a module, with its
    // package count, a dot while Apply has steps for it, and dimmed when this machine
    // doesn't use it.
    component SidebarRow: Rectangle {
        id: sideRow

        property string title: ""
        property string detail: ""
        property int count: 0
        property bool dimmed: false
        property bool current: false
        property bool pending: false

        signal picked()

        width: parent ? parent.width : 0
        height: Theme.controlHeight
        radius: Theme.borderRadius
        color: sideRow.current ? Theme.selectedFill : sideMouse.containsMouse ? Theme.controlFill : "transparent"
        border.width: sideRow.current ? Theme.borderWidth : 0
        border.color: Theme.selectedBorder

        MouseArea {
            id: sideMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sideRow.picked()
        }

        Label {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingSmall
            anchors.right: sideTrailing.left
            anchors.rightMargin: Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            role: "title"
            font.weight: sideRow.current ? Font.Medium : Font.Normal
            text: sideRow.title
            color: sideRow.dimmed ? Theme.subtext : Theme.text
            elide: Text.ElideRight
        }

        Row {
            id: sideTrailing
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSmall

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: sideRow.pending
                width: Theme.spacingSmall
                height: width
                radius: width / 2
                color: Theme.warning
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: sideRow.detail !== ""
                role: "caption"
                text: sideRow.detail
                font.features: { "tnum": 1 }
            }

            Pill {
                anchors.verticalCenter: parent.verticalCenter
                visible: sideRow.count > 0
                text: String(sideRow.count)
                toneColor: Theme.warning
            }
        }
    }

    // What the run asks, typed: sudo's password, or a run line's question.
    component QuestionCard: Column {
        id: card

        readonly property var request: SystemService.request
        readonly property bool password: card.request !== null && card.request.kind === "password"

        spacing: Theme.spacingSmall
        leftPadding: Theme.spacingSmall

        Label {
            role: "title"
            text: card.password ? "Your password, for sudo" : card.request ? card.request.subject.trim().replace(/:$/, "") : ""
        }

        Row {
            spacing: Theme.spacingSmall

            Field {
                id: answer
                width: 320
                masked: card.request !== null && card.request.kind !== "text"
                iconName: card.password ? "lock" : ""
                enabled: !SystemService.checkingPassword
                Component.onCompleted: answer.focusInput()
                onAccepted: SystemService.respond(answer.text)
                onCancelled: SystemService.decline()
                onTextChanged: SystemService.requestError = ""
            }

            ActionButton {
                text: "Cancel"
                onClicked: SystemService.decline()
            }

            ActionButton {
                text: "Continue"
                kind: "primary"
                enabled: !SystemService.checkingPassword
                onClicked: SystemService.respond(answer.text)
            }
        }

        Label {
            role: "caption"
            visible: text !== ""
            color: SystemService.requestError !== "" ? Theme.error : Theme.subtext
            text: SystemService.requestError !== "" ? SystemService.requestError
                : SystemService.checkingPassword ? "Checking…"
                : card.password ? "Asked once; the rest of this run uses it." : ""
        }

        Connections {
            target: SystemService

            function onRequestErrorChanged() {
                if (SystemService.requestError !== "") {
                    answer.text = "";
                    answer.focusInput();
                }
            }
        }
    }

    // What paru is about to build from the AUR, to build or not: each package's build
    // files, or what changed in them since it was last built here.
    component ReviewView: Item {
        id: review

        // Each package's heading, then its lines.
        function fill() {
            const notes = {
                new: "new here: its build files in full",
                changed: "what changed since you last built it",
                same: "its build files are as when you last built it"
            };
            reviewLines.clear();
            for (const pkg of SystemService.reviewPackages) {
                reviewLines.append({ text: pkg.name, kind: "package", note: notes[pkg.state] || "" });
                if (pkg.text === "")
                    continue;
                for (const line of pkg.text.replace(/\n$/, "").split("\n"))
                    reviewLines.append({ text: line, kind: review.lineKind(line, pkg.state === "changed"), note: "" });
            }
        }

        function lineKind(line, diff) {
            if (line.startsWith("=== ") || diff && /^(diff --git|index |--- |\+\+\+ )/.test(line))
                return "file";
            if (!diff)
                return "context";
            return line.startsWith("@@") ? "hunk" : line.startsWith("+") ? "add" : line.startsWith("-") ? "del" : "context";
        }

        Item {
            id: reviewHeading
            width: parent.width
            height: Math.max(reviewTitles.implicitHeight, reviewActions.height)

            Column {
                id: reviewTitles
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingSmall
                anchors.right: reviewActions.left
                anchors.rightMargin: Theme.spacingMedium
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingMicro

                Label {
                    role: "title"
                    text: SystemService.reviewPackages.length === 1 ? "Review 1 package from the AUR"
                        : "Review " + SystemService.reviewPackages.length + " packages from the AUR"
                }

                Label {
                    width: parent.width
                    role: "caption"
                    wrapMode: Text.WordWrap
                    text: "Their build scripts run on this machine, so read them before paru builds them."
                }
            }

            Row {
                id: reviewActions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingSmall

                ActionButton {
                    text: "Don't build"
                    onClicked: SystemService.decline()
                }

                ActionButton {
                    text: "Build"
                    kind: "primary"
                    enabled: SystemService.reviewPackages.length > 0
                    onClicked: SystemService.respond("")
                }
            }
        }

        CodeView {
            anchors.top: reviewHeading.bottom
            anchors.topMargin: Theme.spacingMedium
            anchors.bottom: parent.bottom
            width: parent.width
            model: ListModel {
                id: reviewLines
            }
        }

        Connections {
            target: SystemService

            function onReviewPackagesChanged() {
                review.fill();
            }
        }

        Component.onCompleted: review.fill()
    }

    // The run's output as it comes, kept at its end unless scrolled back.
    component RunLog: CodeView {
        id: log

        property bool following: true

        model: SystemService.runLog
        onMovementEnded: log.following = log.atYEnd
        onCountChanged: {
            if (log.following)
                Qt.callLater(log.positionViewAtEnd);
        }
    }

    // Rows of { text, kind, note } in a fixed-width font on a well: a heading, a package
    // with its note, a file's name, a diff's lines in their colors, or plain text.
    component CodeView: ListView {
        id: code

        clip: true
        boundsBehavior: Flickable.StopAtBounds
        topMargin: Theme.spacingSmall
        bottomMargin: Theme.spacingSmall

        StyledScrollBar.vertical: StyledScrollBar {}

        Rectangle {
            parent: code
            anchors.fill: parent
            z: -1
            radius: Theme.borderRadius
            color: Theme.alpha(Theme.mantle, 0.6)
            border.width: Theme.borderWidth
            border.color: Theme.controlBorder
        }

        delegate: Item {
            id: line

            required property string text
            required property string kind
            required property string note
            readonly property bool titled: line.kind === "heading" || line.kind === "package"

            width: ListView.view.width
            height: lineText.implicitHeight + (line.titled ? Theme.spacingMedium : 0)

            Label {
                id: lineText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: Theme.spacingMedium
                anchors.rightMargin: Theme.spacingMedium
                role: line.titled ? "title" : "caption"
                font.family: line.titled ? Theme.fontFamily : Theme.fontFamilyMono
                wrapMode: line.titled ? Text.NoWrap : Text.WrapAnywhere
                textFormat: Text.PlainText
                elide: line.titled ? Text.ElideRight : Text.ElideNone
                text: line.kind === "package" && line.note !== "" ? line.text + "  ·  " + line.note : line.text
                color: line.titled ? Theme.text
                    : line.kind === "add" ? Theme.success
                    : line.kind === "del" ? Theme.error
                    : line.kind === "hunk" ? Theme.accent
                    : line.kind === "file" ? Theme.text
                    : Theme.subtext
            }
        }
    }

    // A section's heading on a page, with its count.
    // A section's heading on a page: its title, its count, a note after them, and its
    // controls at the right.
    component PageSection: Item {
        id: section

        property string title: ""
        property int count: -1
        property string note: ""
        default property alias trailing: sectionTrailing.data

        width: parent ? parent.width : 0
        height: Theme.spacingLarge + sectionBand.height

        Item {
            id: sectionBand
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(sectionLabels.implicitHeight, sectionTrailing.implicitHeight)

            Row {
                id: sectionLabels
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingSmall

                Label {
                    id: sectionTitle
                    role: "section"
                    text: section.title
                }

                Label {
                    anchors.baseline: sectionTitle.baseline
                    visible: section.count >= 0
                    role: "caption"
                    text: String(section.count)
                    font.features: { "tnum": 1 }
                }

                Label {
                    anchors.baseline: sectionTitle.baseline
                    visible: section.note !== ""
                    role: "caption"
                    text: section.note
                }
            }

            Row {
                id: sectionTrailing
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingTiny
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingSmall
            }
        }
    }

    // A page's heading: a disc in its tone when it has `iconName`, a title with a caption
    // under it, and the page's actions at the right.
    component PageHeading: Item {
        id: heading

        property string iconName: ""
        property color toneColor: Theme.accent
        property bool spinning: false
        property string title: ""
        property string caption: ""
        default property alias actions: headingActions.data

        width: parent ? parent.width : 0
        height: Math.max(Theme.controlHeight, headingTitles.implicitHeight, headingActions.implicitHeight)

        IconDisc {
            id: headingDisc
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            visible: heading.iconName !== ""
            iconName: heading.iconName
            toneColor: heading.toneColor
            lit: true
            spinning: heading.spinning
        }

        Column {
            id: headingTitles
            anchors.left: headingDisc.visible ? headingDisc.right : parent.left
            anchors.leftMargin: headingDisc.visible ? Theme.spacingMedium : Theme.spacingSmall
            anchors.right: headingActions.left
            anchors.rightMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingMicro

            Label {
                width: parent.width
                role: "heading"
                elide: Text.ElideRight
                text: heading.title
            }

            Label {
                width: parent.width
                visible: heading.caption !== ""
                role: "caption"
                elide: Text.ElideRight
                text: heading.caption
            }
        }

        Row {
            id: headingActions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSmall
        }
    }

    // Where Add puts a package, at the head of the search's first section of results.
    component TargetMenu: Row {
        spacing: Theme.spacingSmall

        Label {
            anchors.verticalCenter: parent.verticalCenter
            role: "caption"
            text: "Adds to"
        }

        SelectMenu {
            options: root.onModules.map(id => ({ value: id, label: id }))
            currentValue: root.targetModule
            onValueSelected: value => root.target = value
        }
    }

    // A package the search offers: its name, what it is, and whether it's installed, with
    // Add while it is the one picked, by the pointer or the arrow keys.
    component ResultRow: EntryRow {
        id: result

        property var pkg: ({})
        // Its place among everything offered, which root.searchIndex counts in.
        property int offset: 0
        readonly property bool picked: root.searchIndex === result.offset

        iconName: "package"
        title: result.pkg.name
        note: result.pkg.description
        pillText: result.pkg.installed ? "installed" : ""
        pillTone: Theme.subtext
        selected: result.picked
        actionsOnHover: true
        onHoveredChanged: {
            if (result.hovered) {
                root.searchByKeys = false;
                root.searchIndex = result.offset;
            }
        }
        onPickedChanged: {
            if (result.picked && root.searchByKeys)
                root.reveal(result);
        }

        ActionButton {
            compact: true
            text: "Add to " + root.targetModule
            iconName: "plus"
            enabled: root.targetModule !== ""
            onClicked: root.addOffered(result.offset)
        }
    }

    // A package in a module's grid: its name, marked when Apply installs it and when it
    // comes from the AUR, with its note, what Apply does, and its whole name if cut short
    // on hover, and a way out of its module.
    component PackageCell: Rectangle {
        id: cell

        property string name: ""
        property string note: ""
        property bool fromAur: false
        property bool installing: false
        property bool dimmed: false
        readonly property bool hovered: cellHover.hovered
        readonly property string tip: [cellName.truncated ? cell.name : "", cell.installing ? "Installs on apply" : "", cell.note]
            .filter(part => part !== "").join(" · ")

        height: Theme.controlHeight
        radius: Theme.borderRadius
        color: cell.hovered ? Theme.controlFill : "transparent"

        HoverHandler {
            id: cellHover
        }

        AppIcon {
            id: cellMark
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            visible: cell.installing
            name: "plus"
            size: Theme.iconSizeSmall
            iconColor: Theme.warning
        }

        Label {
            id: cellName
            anchors.left: cellMark.visible ? cellMark.right : parent.left
            anchors.leftMargin: cellMark.visible ? Theme.spacingTiny : Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, cell.width - x - (cellTag.visible ? cellTag.implicitWidth + Theme.spacingSmall : 0)
                - cellRemove.width - Theme.spacingTiny)
            text: cell.name
            color: cell.dimmed ? Theme.subtext : Theme.text
            elide: Text.ElideRight
        }

        Label {
            id: cellTag
            anchors.left: cellName.right
            anchors.leftMargin: Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            visible: cell.fromAur
            role: "caption"
            text: "AUR"
        }

        HeaderButton {
            id: cellRemove
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingTiny
            anchors.verticalCenter: parent.verticalCenter
            opacity: cell.hovered ? 1 : 0
            enabled: cell.hovered
            iconName: "trash"
            tooltipText: "Take out of the module"
            onClicked: SystemService.removePackage(cell.name)
        }

        Tooltip {
            visible: cell.hovered && cell.tip !== "" && !cellRemove.containsMouse
            text: cell.tip
        }
    }

    // A row that opens, when it has items ({ title, note, pillText, error, file }), to list
    // them under it; a row or item with a file opens that file of the modules.
    component FoldRow: Column {
        id: fold

        property string iconName: ""
        property string title: ""
        property string note: ""
        property string pillText: ""
        property color pillTone: Theme.warning
        property bool dimmed: false
        property string file: ""
        property var items: []
        property bool expanded: false

        width: parent ? parent.width : 0

        EntryRow {
            iconName: fold.iconName
            title: fold.title
            note: fold.note
            pillText: fold.pillText
            pillTone: fold.pillTone
            dimmed: fold.dimmed
            clickable: fold.items.length > 0 || fold.file !== ""
            onClicked: {
                if (fold.items.length > 0)
                    fold.expanded = !fold.expanded;
                else
                    root.openFile(fold.file);
            }

            AppIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: fold.items.length > 0
                name: fold.expanded ? "chevron-down" : "chevron-right"
                size: Theme.iconSizeSmall
                iconColor: Theme.subtext
            }
        }

        Repeater {
            model: fold.expanded ? fold.items : []

            EntryRow {
                required property var modelData

                indent: Theme.iconSizeSmall + Theme.spacingSmall
                title: modelData.title
                note: modelData.note || ""
                pillText: modelData.pillText || ""
                pillTone: modelData.error ? Theme.error : Theme.warning
                dimmed: fold.dimmed
                clickable: (modelData.file || "") !== ""
                onClicked: root.openFile(modelData.file)
            }
        }
    }

    // A package, service, file, step, or trigger: its name, a note after it, what it
    // needs, and its actions, which may wait for the pointer.
    component EntryRow: Rectangle {
        id: entry

        property string iconName: ""
        property string title: ""
        property string note: ""
        property string pillText: ""
        property color pillTone: Theme.warning
        property bool dimmed: false
        property bool struck: false
        property bool clickable: false
        // Picked by the keyboard, which shows it as hovered.
        property bool selected: false
        property bool actionsOnHover: false
        // Space before the icon, for a row under another.
        property real indent: 0
        readonly property bool hovered: entryHover.hovered
        default property alias actions: entryActions.data

        signal clicked()

        width: parent ? parent.width : 0
        height: Theme.controlHeight
        radius: Theme.borderRadius
        color: entry.hovered || entry.selected ? Theme.controlFill : "transparent"

        // Over the actions too, which take the pointer from the MouseArea.
        HoverHandler {
            id: entryHover
        }

        MouseArea {
            id: entryMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: entry.clickable ? Qt.LeftButton : Qt.NoButton
            cursorShape: entry.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: entry.clicked()
        }

        AppIcon {
            id: entryIcon
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingSmall + entry.indent
            anchors.verticalCenter: parent.verticalCenter
            visible: entry.iconName !== ""
            name: entry.iconName
            size: Theme.iconSizeSmall
            iconColor: Theme.subtext
        }

        Label {
            id: entryTitle
            anchors.left: entryIcon.visible ? entryIcon.right : parent.left
            anchors.leftMargin: entryIcon.visible ? Theme.spacingSmall : Theme.spacingSmall + entry.indent
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, entry.width * 0.6)
            text: entry.title
            color: entry.dimmed || entry.struck ? Theme.subtext : Theme.text
            font.strikeout: entry.struck
            elide: Text.ElideMiddle
        }

        Label {
            anchors.left: entryTitle.right
            anchors.leftMargin: Theme.spacingMedium
            anchors.right: entryTrailing.left
            anchors.rightMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            role: "caption"
            text: entry.note
            elide: Text.ElideRight
        }

        Row {
            id: entryTrailing
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingTiny
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSmall

            Row {
                id: entryActions
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingTiny
                opacity: !entry.actionsOnHover || entry.hovered || entry.selected ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animDurationFast; easing.type: Theme.animEasing }
                }
            }

            Pill {
                anchors.verticalCenter: parent.verticalCenter
                visible: entry.pillText !== ""
                text: entry.pillText
                toneColor: entry.pillTone
            }
        }
    }
}
