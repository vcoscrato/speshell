import QtQuick
import qs.services

// Keep awake's switch among the panel buttons, a cup in the accent while on. Shown on
// battery, where idling runs.
BarButton {
    id: root

    visible: !BatteryService.pluggedIn
    label: IdleService.keepAwake ? "Keep awake: on" : "Keep awake: off"
    iconName: "awake"
    tone: IdleService.keepAwake ? "accent" : ""
    onClicked: pointer => {
        EffectsService.picked(root, pointer);
        IdleService.setKeepAwake(!IdleService.keepAwake);
    }
}
