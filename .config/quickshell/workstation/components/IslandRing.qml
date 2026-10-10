import QtQuick
import "../models/IslandMotion.js" as Motion

Canvas {
    id: root
    property real value: 0
    property real animatedValue: value
    property real lineWidth: 7
    property color trackColor: "#334455"
    property color fillColor: "#89b4fa"
    property real phase: 0
    property real speed: 1
    property bool reduceMotion: false

    onValueChanged: {
        root.animatedValue = value;
        requestPaint();
    }
    onAnimatedValueChanged: requestPaint()
    onTrackColorChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onPhaseChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        var radius = Math.max(0, Math.min(width, height) / 2 - root.lineWidth / 2);
        var centerX = width / 2;
        var centerY = height / 2;
        ctx.lineWidth = root.lineWidth;
        ctx.lineCap = "round";
        ctx.beginPath();
        ctx.strokeStyle = root.trackColor;
        ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
        ctx.stroke();
        ctx.beginPath();
        ctx.strokeStyle = root.fillColor;
        ctx.arc(centerX, centerY, radius, -Math.PI / 2,
            -Math.PI / 2 + Math.PI * 2 * Math.max(0, Math.min(1, root.animatedValue)));
        ctx.stroke();
        if (root.phase > 0 && root.animatedValue > 0) {
            ctx.globalAlpha = 0.12 + Math.sin(root.phase) * 0.05;
            ctx.beginPath();
            ctx.strokeStyle = root.fillColor;
            ctx.arc(centerX, centerY, radius + root.lineWidth * 0.75, -Math.PI / 2,
                -Math.PI / 2 + Math.PI * 2 * Math.max(0, Math.min(1, root.animatedValue)));
            ctx.stroke();
        }
    }

    Behavior on animatedValue {
        SpringAnimation {
            spring: Motion.spring(Motion.primary, root.speed, root.reduceMotion)
            damping: Motion.damping(Motion.primary, root.reduceMotion)
            mass: Motion.primary.mass
        }
    }
}
