import QtQuick
import QtQuick.Controls

Pane {
    id: root
    required property var colors
    property real textScale: 1
    property color paneBackground: colors.background
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 15 * textScale
    palette.window: colors.background
    palette.windowText: colors.foreground
    palette.base: colors.background_alt
    palette.alternateBase: colors.surface_alt
    palette.text: colors.foreground
    palette.button: colors.surface
    palette.buttonText: colors.foreground
    palette.highlight: colors.selection
    palette.highlightedText: colors.foreground
    palette.mid: colors.muted
    palette.light: colors.surface_alt
    palette.dark: colors.background_alt
    background: Rectangle { color: root.paneBackground }
}
