import QtQuick
import qs.components
import qs.services

// The screen's brightness, as the Displays panel and the OSD show it.
LevelRow {
    from: BrightnessService.minimumPercent
    value: BrightnessService.percent
    valueText: BrightnessService.percent + "%"
    progressColor: Theme.yellow
    onAdjusted: nextValue => BrightnessService.setPercent(nextValue)
    onReleased: BrightnessService.commit()

    // Labelled as the setting rows around it in the panel are.
    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: "Brightness"
    }
}
