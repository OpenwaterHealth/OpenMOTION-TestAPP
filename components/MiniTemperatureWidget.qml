import QtQuick 6.0
import QtQuick.Controls 6.0

Rectangle {
    id: root
    width: 100
    height: 100
    color: "transparent"

    // API
    property real   temperature: 0
    property string tempName: "TEMP #1"
    property real   maxTemp: 70            // scale 0..maxTemp (like original 70)

    // Dynamic color
    property color gaugeColor: temperature <= 40 ? "#3498DB"
                               : (temperature <= 70 ? "#F1C40F" : "#E74C3C")

    // Gauge drawing
    Canvas {
        id: arcCanvas
        anchors.centerIn: parent
        width: 88
        height: 88

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const cx = width / 2;
            const cy = height / 2;
            const r  = 38;                 // radius scaled down from 60
            const bg = "#D0D3D4";
            const lw = 8;                  // line width scaled from 10

            // Background arc (270° from 135° to 405°)
            ctx.beginPath();
            ctx.arc(cx, cy, r, Math.PI * 0.75, Math.PI * 2.25, false);
            ctx.lineWidth = lw;
            ctx.strokeStyle = bg;
            ctx.lineCap = "round";
            ctx.stroke();

            // Foreground arc (scaled by temperature/maxTemp)
            const clamped = Math.max(0, Math.min(temperature, maxTemp));
            const sweepDeg = (clamped / maxTemp) * 270.0;
            ctx.beginPath();
            ctx.arc(cx, cy, r,
                    Math.PI * 0.75,
                    Math.PI * (0.75 + (sweepDeg / 180.0)),
                    false);
            ctx.lineWidth = lw;
            ctx.strokeStyle = gaugeColor;
            ctx.lineCap = "round";
            ctx.stroke();
        }
    }

    // Redraw when temp changes
    onTemperatureChanged: arcCanvas.requestPaint()
    onMaxTempChanged: arcCanvas.requestPaint()
    onWidthChanged: arcCanvas.requestPaint()
    onHeightChanged: arcCanvas.requestPaint()

    // Temperature value
    Text {
        text: temperature.toFixed(0) + "°C"
        anchors.centerIn: parent
        font.pixelSize: 16                 // scaled from 24
        font.weight: Font.Bold
        color: "#4B4B4B"
    }

    // Label below (outside the 100x100 box, like your original)
    Text {
        text: tempName
        anchors {
            top: parent.bottom
            horizontalCenter: parent.horizontalCenter
            topMargin: 4
        }
        font.pixelSize: 12                 // scaled from 16
        font.weight: Font.Medium
        color: "#BDC3C7"
    }
}
