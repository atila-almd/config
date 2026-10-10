import QtQuick
import "../models/IslandMotion.js" as Motion

Item {
    id: root
    required property var palette
    property real cornerRadius: Math.min(height / 2, 28)
    property bool raised: false
    property bool interactive: true
    property bool reduceMotion: false
    property real speed: palette && palette.speed ? palette.speed : 1
    property real sheenX: width * 0.32
    property real sheenY: height * 0.18
    property real sheenOpacity: 0.075
    property real maxTilt: 2
    property bool grain: true
    signal hoveredChangedExternally(bool hovered)

    clip: true
    layer.enabled: true
    layer.smooth: true

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.raised ? root.palette.glassFillRaised : root.palette.glassFill
        border.width: 1
        border.color: root.palette.rim
        antialiasing: true
    }

    // A narrow top-left highlight and a quieter lower inner edge make the
    // translucent slab read as convex without introducing another surface.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        radius: 1
        opacity: 0.8
        color: root.palette.innerLight
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.min(14, root.height * 0.22)
        radius: root.cornerRadius
        opacity: 0.22
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 1.0; color: root.palette.shadow }
        }
    }

    // A small moving ellipse is the specular light. The compositor supplies
    // the backdrop blur for this translucent layer footprint.
    Rectangle {
        width: Math.max(34, root.width * 0.42)
        height: Math.max(18, root.height * 0.9)
        x: root.sheenX - width / 2
        y: root.sheenY - height / 2
        radius: height / 2
        rotation: -18
        color: root.palette.innerLight
        opacity: root.interactive ? root.sheenOpacity : root.sheenOpacity * 0.45
    }

    // Low-cost deterministic grain avoids a perfectly flat tint while keeping
    // the idle surface free of a repainting noise timer.
    Text {
        anchors.fill: parent
        visible: root.grain
        text: "·  ·   ·    ·  ·   ·    ·  ·   ·    ·  ·   ·    ·  ·   ·    ·  ·   ·"
        color: root.palette.foreground
        opacity: 0.025
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 9
        wrapMode: Text.Wrap
        lineHeight: 0.8
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignTop
    }

    HoverHandler {
        enabled: root.interactive
        onPointChanged: {
            root.sheenX = point.position.x;
            root.sheenY = point.position.y;
            if (root.interactive && root.width > 0)
                root.rotation = (point.position.x / root.width - 0.5) * root.maxTilt * 2;
        }
        onHoveredChanged: {
            root.hoveredChangedExternally(hovered);
            if (!hovered) root.rotation = 0;
        }
    }

    Behavior on cornerRadius {
        SpringAnimation {
            spring: Motion.spring(Motion.primary, root.speed, root.reduceMotion)
            damping: Motion.damping(Motion.primary, root.reduceMotion)
            mass: Motion.primary.mass
        }
    }
    Behavior on rotation {
        SpringAnimation {
            spring: Motion.spring(Motion.hover, root.speed, root.reduceMotion)
            damping: Motion.damping(Motion.hover, root.reduceMotion)
            mass: Motion.hover.mass
        }
    }
}
