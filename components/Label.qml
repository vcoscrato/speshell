import QtQuick
import qs.theme

// Speshell's text, in one of a few roles that set its size, weight, and color; set any
// of them to differ. Plain text unless `textFormat` says otherwise.
//   body     most text: values, settings, messages (the default)
//   title    a row's or an empty state's name
//   caption  the line under a title, hints, and units
//   section  a panel's or a group's heading
//   heading  a panel's own subject, like a timer's name or the date
//   display  the one figure a panel is for, like the time left or the temperature
Text {
    id: root

    property string role: "body"

    textFormat: Text.PlainText
    color: root.role === "caption" || root.role === "section" ? Theme.subtext : Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: root.role === "title" ? Theme.fontSizeNormal
        : root.role === "caption" ? Theme.fontSizeCaption
        : root.role === "heading" ? Theme.fontSizeLarge
        : root.role === "display" ? Theme.fontSizeHuge
        : Theme.fontSizeSmall
    font.weight: root.role === "title" || root.role === "display" ? Font.Medium
        : root.role === "heading" ? Font.DemiBold
        : Font.Normal
    font.capitalization: root.role === "section" ? Font.AllUppercase : Font.MixedCase
    font.letterSpacing: root.role === "section" ? 0.8 : 0
}
