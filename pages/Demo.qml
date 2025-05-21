import QtQuick 6.0
import QtQuick.Controls 6.0
import QtQuick.Layouts 6.0

import "../components"
import "../models/FpgaModel.js" as FpgaData

Rectangle {
    id: page1
    width: parent.width
    height: parent.height
    color: "#29292B" // Background color for Page 1
    radius: 20
    opacity: 0.95 // Slight transparency for the content area

    property var inputRefs: []
    property int displayByteCount: 0
    property int startOffset: 0
    property var fn: null
    readonly property int dataSize: {
        if (fn && fn.data_size) {
            const match = fn.data_size.match(/^(\d+)B$/);
            return match ? parseInt(match[1]) : 8;
        }
        return 8;
    }
    
    readonly property string placeholderHex: {
        switch (dataSize) {
            case 8: return "0x00";
            case 16: return "0x0000";
            case 24: return "0x000000";
            case 32: return "0x00000000";
            default: return "0x00";
        }
    }

    readonly property var hexValidator: {
        switch (dataSize) {
            case 8: return /0x[0-9a-fA-F]{1,2}/;
            case 16: return /0x[0-9a-fA-F]{1,4}/;
            case 24: return /0x[0-9a-fA-F]{1,6}/;
            case 32: return /0x[0-9a-fA-F]{1,8}/;
            default: return /0x[0-9a-fA-F]{1,2}/;
        }
    }

    ListModel {
        id: cameraModel
        ListElement { label: "Camera 1"; cam_mask: 0x01; channel: 0; i2c_addr: 0x41 }
        ListElement { label: "Camera 2"; cam_mask: 0x02; channel: 1; i2c_addr: 0x41 }
        ListElement { label: "Camera 3"; cam_mask: 0x04; channel: 2; i2c_addr: 0x41 }
        ListElement { label: "Camera 4"; cam_mask: 0x08; channel: 3; i2c_addr: 0x41 }
        ListElement { label: "Camera 5"; cam_mask: 0x10; channel: 4; i2c_addr: 0x41 }
        ListElement { label: "Camera 6"; cam_mask: 0x20; channel: 5; i2c_addr: 0x41 }
        ListElement { label: "Camera 7"; cam_mask: 0x40; channel: 6; i2c_addr: 0x41 }
        ListElement { label: "Camera 8"; cam_mask: 0x80; channel: 7; i2c_addr: 0x41 }
    }
    
    ListModel {
        id: cameraModeModel
        ListElement { label: "Bars"; tp_id: 0x00}
        ListElement { label: "Solid"; tp_id: 0x01}
        ListElement { label: "Squares"; tp_id: 0x02}
        ListElement { label: "Continuous"; tp_id: 0x03}
        ListElement { label: "Live"; tp_id: 0x04}
    }

    // Define the model for accessSelector
    ListModel {
        id: accessModeModel
    }

    function updateFunctionUI(index) {
        accessModeModel.clear()

        // Defensive check: valid index and model element
        if (index < 0 || !functionSelector.model || index >= functionSelector.model.length) {
            fn = null
            hexInput.text = ""
            return
        }

        fn = functionSelector.model[index]
        if (!fn || !fn.direction) {
            console.warn("Function data is invalid")
            hexInput.text = ""
            return
        }

        const dir = fn.direction

        if (dir === "RD") {
            accessModeModel.append({ text: "Read" })
        } else if (dir === "WR") {
            accessModeModel.append({ text: "Write" })
        } else if (dir === "RW") {
            accessModeModel.append({ text: "Read" })
            accessModeModel.append({ text: "Write" })
        }

        accessSelector.currentIndex = 0
        hexInput.text = ""
    }


    // HEADER
    Text {
        text: "MOTION Blood Flow Demo"
        font.pixelSize: 20
        font.weight: Font.Bold
        color: "white"
        horizontalAlignment: Text.AlignHCenter
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 10
        }
    }

    // LAYOUT
    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // Left Column (Input Panel)
        ColumnLayout {
            spacing: 20

            // Trigger
            Rectangle {
                id: triggerContainer
                width: 500
                height: 200
                color: "#1E1E20"
                radius: 10
                border.color: "#3E4E6F"
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    Text {
                        text: "PWM Control"
                        color: "#BDC3C7"
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignLeft

                        Text {
                            text: "Frame Sync"
                            color: "#BDC3C7"
                            font.pixelSize: 14
                            Layout.preferredWidth: 80
                            verticalAlignment: Text.AlignVCenter
                        }

                        TextField {
                            id: fsFrequency
                            placeholderText: "Freq"
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 40
                            enabled: MOTIONConnector.sensorConnected
                            font.pixelSize: 12
                            background: Rectangle {
                                radius: 6
                                color: "#2B2B2E"
                                border.color: "#555"
                            }
                            validator: IntValidator { bottom: 1; top: 240 }
                        }

                        TextField {
                            id: fsPulseWidth
                            placeholderText: "PulseWidth"
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 40
                            font.pixelSize: 12
                            enabled: MOTIONConnector.sensorConnected 
                            inputMethodHints: Qt.ImhDigitsOnly
                            background: Rectangle {
                                radius: 6
                                color: "#2B2B2E"
                                border.color: "#555"
                            }
                            validator: IntValidator { bottom: 1; top: 100 }
                        }
                        Item {
                            Layout.preferredWidth: 10
                        }
                        Button {
                            id: fsButton
                            text: "Trigger"
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 50
                            hoverEnabled: true  // Enable hover detection
                            enabled: MOTIONConnector.sensorConnected 

                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? "#BDC3C7" : "#7F8C8D"  // Gray out text when disabled
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                id: fsButtonBackground
                                color: {
                                    if (!parent.enabled) {
                                        return "#3A3F4B";  // Disabled color
                                    }
                                    return parent.hovered ? "#4A90E2" : "#3A3F4B";  // Blue on hover, default otherwise
                                }
                                radius: 4
                                border.color: {
                                    if (!parent.enabled) {
                                        return "#7F8C8D";  // Disabled border color
                                    }
                                    return parent.hovered ? "#FFFFFF" : "#BDC3C7";  // White border on hover, default otherwise
                                }
                            }

                            onClicked: {
                                console.log("Frame Sync Trigger");          
                            }
                        }

                        Item {
                            Layout.preferredWidth: 5
                        }

                        Text {
                            id: fsState
                            text: "OFF"
                            color: "red"
                            font.pixelSize: 14
                            Layout.preferredWidth: 40
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignLeft

                        Text {
                            text: "Laser Sync"
                            color: "#BDC3C7"
                            font.pixelSize: 14
                            Layout.preferredWidth: 80
                            verticalAlignment: Text.AlignVCenter
                        }

                        TextField {
                            id: lsFrequency
                            placeholderText: "Freq"
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 40
                            font.pixelSize: 12
                            background: Rectangle {
                                radius: 6
                                color: "#2B2B2E"
                                border.color: "#555"
                            }
                            validator: IntValidator { bottom: 1; top: 240 }
                        }

                        TextField {
                            id: lsPulseWidth
                            placeholderText: "PulseWidth"
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 40
                            font.pixelSize: 12
                            inputMethodHints: Qt.ImhDigitsOnly
                            background: Rectangle {
                                radius: 6
                                color: "#2B2B2E"
                                border.color: "#555"
                            }
                            validator: IntValidator { bottom: 1; top: 100 }
                        }
                        Item {
                            Layout.preferredWidth: 10
                        }

                        Button {
                            id: lsButton
                            text: "Trigger"
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 50
                            hoverEnabled: true  // Enable hover detection
                            enabled: MOTIONConnector.sensorConnected 

                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? "#BDC3C7" : "#7F8C8D"  // Gray out text when disabled
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                id: lsButtonBackground
                                color: {
                                    if (!parent.enabled) {
                                        return "#3A3F4B";  // Disabled color
                                    }
                                    return parent.hovered ? "#4A90E2" : "#3A3F4B";  // Blue on hover, default otherwise
                                }
                                radius: 4
                                border.color: {
                                    if (!parent.enabled) {
                                        return "#7F8C8D";  // Disabled border color
                                    }
                                    return parent.hovered ? "#FFFFFF" : "#BDC3C7";  // White border on hover, default otherwise
                                }
                            }

                            onClicked: {
                                console.log("Laser Sync Trigger");          
                            }
                        }
                        

                        Item {
                            Layout.preferredWidth: 5
                        }

                        Text {
                            id: lsState
                            text: "OFF"
                            color: "red"
                            font.pixelSize: 14
                            Layout.preferredWidth: 40
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            Rectangle {
                id: fpgaContainer
                width: 500
                height: 400
                color: "#1E1E20"
                radius: 10
                border.color: "#3E4E6F"
                border.width: 2

                // Title
                Text {
                    id: fpgaTitle
                    text: "FPGA I2C Utility"
                    color: "#BDC3C7"
                    font.pixelSize: 16
                    font.bold: true
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                ColumnLayout {
                    id: fpgaLayout
                    anchors.top: fpgaTitle.bottom
                    anchors.topMargin: 12
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 12
                    spacing: 10
                    enabled: MOTIONConnector.consoleConnected 

                    // FPGA + Function Combo Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ComboBox {
                            id: fpgaSelector
                            model: FpgaData.fpgaAddressModel
                            textRole: "label"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32

                            onCurrentIndexChanged: {
                                accessModeModel.clear()
                                functionSelector.currentIndex = 0;
                                updateFunctionUI(0)
                            }
                        }

                        ComboBox {
                            id: functionSelector
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            model: fpgaSelector.currentIndex >= 0 ? FpgaData.fpgaAddressModel[fpgaSelector.currentIndex].functions : []
                            textRole: "name"
                            enabled: fpgaSelector.currentIndex >= 0

                            onCurrentIndexChanged: updateFunctionUI(currentIndex)
                            onModelChanged: {
                                if (functionSelector.model.length > 0) {
                                    functionSelector.currentIndex = 0;
                                    updateFunctionUI(0);
                                }
                            }
                        }
                    }

                    // Access + Input + Execute Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ComboBox {
                            id: accessSelector
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 32
                            model: accessModeModel
                            textRole: "text"
                        }

                        TextField {
                            id: hexInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            placeholderText: placeholderHex
                            enabled: accessSelector.currentText === "Write"
                            validator: RegularExpressionValidator { regularExpression: hexValidator }
                        }

                        Button {
                            id: exeButton
                            text: "Execute"
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 40
                            hoverEnabled: true
                            enabled: functionSelector.currentIndex >= 0 &&
                                    (accessSelector.currentText === "Read" || (hexInput.acceptableInput && hexInput.text.length > 0))

                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? "#BDC3C7" : "#7F8C8D"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                color: parent.hovered ? "#4A90E2" : "#3A3F4B"
                                border.color: parent.hovered ? "#FFFFFF" : "#BDC3C7"
                                radius: 4
                            }

                            onClicked: {
                                const fpga = FpgaData.fpgaAddressModel[fpgaSelector.currentIndex];
                                const i2cAddr = fpga.i2c_addr;
                                const muxIdx = fpga.mux_idx;
                                const channel = fpga.channel;

                                const fn = functionSelector.model[functionSelector.currentIndex];
                                const offset = fn.start_address;
                                const dir = accessSelector.currentText;
                                const length = parseInt(fn.data_size.replace("B", "")) / 8;
                                const data = hexInput.text;

                                if (dir === "Read") {
                                    console.log(`READ from ${fpga.label} @ 0x${offset.toString(16)}`);
                                    let result = MOTIONConnector.i2cReadBytes("CONSOLE", muxIdx, channel, i2cAddr, offset, length)
                                    if (result.length === 0) {
                                        console.log("Read failed or returned empty array.")     
                                        i2cStatus.text = "Read failed"
                                        i2cStatus.color = "red"                              
                                    }else{
                                        console.log("Read Success:")
                                        let hexStr = "0x";
                                        for (let i = 0; i < result.length; i++) {
                                            let hexByte = result[i].toString(16).toUpperCase().padStart(2, "0");
                                            hexStr += hexByte;
                                            console.log(hexByte);
                                        }
                                        hexInput.text = hexStr;
                                        i2cStatus.text = "Read successful"
                                        i2cStatus.color = "lightgreen"
                                    }
                                    cleari2cStatusTimer.start()
                                } else {                                    
                                    console.log(`WRITE to ${fpga.label} @ 0x${offset.toString(16)} = ${data}`);

                                    let sanitized = data.replace(/0x/gi, "").replace(/\s+/g, "");
                                    let dataToSend = [];

                                    if (sanitized.length > length * 2) {
                                        console.warn("Input too long, trimming.");
                                        sanitized = sanitized.slice(-length * 2);
                                    } else if (sanitized.length < length * 2) {
                                        sanitized = sanitized.padStart(length * 2, "0");
                                    }

                                    let fullValue = parseInt(sanitized, 16);

                                    var i;
                                    for (i = length - 1; i >= 0; i--) {
                                        let b = (fullValue >> (i * 8)) & 0xFF;
                                        dataToSend.push(b);
                                    }

                                    console.log("Data to send:", dataToSend.map(b => "0x" + b.toString(16).padStart(2, "0")).join(" "));

                                    let success = MOTIONConnector.i2cWriteBytes("CONSOLE", muxIdx, channel, i2cAddr, offset, dataToSend);

                                    if (success) {
                                        console.log("Write successful.");
                                        i2cStatus.text = "Write successful"
                                        i2cStatus.color = "lightgreen"
                                    } else {
                                        console.log("Write failed.");
                                        i2cStatus.text = "Write failed"
                                        i2cStatus.color = "red"
                                    }
                                    cleari2cStatusTimer.start()
                                }
                            }
                        }
                    }

                    Text {
                        id: i2cStatus
                        text: ""
                        color: "#BDC3C7"
                        font.pixelSize: 12
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Timer {
                        id: cleari2cStatusTimer
                        interval: 2000
                        running: false
                        repeat: false
                        onTriggered: i2cStatus.text = ""
                    }
                }
            }
        }

        // RIGHT COLUMN (Status Panel + Histogram)
        ColumnLayout {
            spacing: 20
			            
			// Histogram Panel
            Rectangle {
                id: camerahContainer
                width: 500
                height: 470
                color: "#1E1E20"
                radius: 10
                border.color: "#3E4E6F"
                border.width: 2
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    Text {
                        text: "Camera Control"
                        color: "#BDC3C7"
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // Spacer between title and dropdowns
                    Rectangle {
                        color: "transparent"
                        height: 6
                        Layout.fillWidth: true
                    }
                    
                    // Live Histogram Viewer
                    HistogramView {
                        id: histogramWidget
                        Layout.preferredWidth: 380
                        Layout.preferredHeight: 250
                        Layout.alignment: Qt.AlignHCenter
                    }
                    
                    // Row: Dropdown + Offset + Byte Count
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.preferredHeight: 36

                        ComboBox {
                            id: cameraSelector
                            model: cameraModel
                            textRole: "label"
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 32
                            enabled: MOTIONConnector.sensorConnected
                        }

                        ComboBox {
                            id: patternSelector
                            model: cameraModeModel
                            textRole: "label"
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 32
                            enabled: MOTIONConnector.sensorConnected
                        }

                        Button {
                            id: idCameraCapButton
                            text: "Capture"
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 45
                            hoverEnabled: true  // Enable hover detection
                            enabled: MOTIONConnector.sensorConnected 

                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? "#BDC3C7" : "#7F8C8D"  // Gray out text when disabled
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                id: cameraCapButtonBackground
                                color: {
                                    if (!parent.enabled) {
                                        return "#3A3F4B";  // Disabled color
                                    }
                                    return parent.hovered ? "#4A90E2" : "#3A3F4B";  // Blue on hover, default otherwise
                                }
                                radius: 4
                                border.color: {
                                    if (!parent.enabled) {
                                        return "#7F8C8D";  // Disabled border color
                                    }
                                    return parent.hovered ? "#FFFFFF" : "#BDC3C7";  // White border on hover, default otherwise
                                }
                            }

                            onClicked: {
                                let addr = cameraModel.get(cameraSelector.currentIndex)
                                console.log("Capture Histogram from " + addr.label);          
                                                      
                                // Call get single frame
                            }
                        }

                        Item {
                            Layout.preferredWidth: 5
                        }
                        
                        Text {
                            id: cameraCapStatus
                            text: "Not Configured"
                            color: "#BDC3C7"
                            font.pixelSize: 12
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                    }
                }
            }

			// Status Panel (Connection Indicators)
            Rectangle {
                id: statusPanel
                width: 500
                height: 130
                color: "#1E1E20"
                radius: 10
                border.color: "#3E4E6F"
                border.width: 2
                

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    // Connection status text
                    Text {
                        id: statusText
                        text: "System State: " + (MOTIONConnector.state === 0 ? "Disconnected"
                                        : MOTIONConnector.state === 1 ? "Sensor Connected"
                                        : MOTIONConnector.state === 2 ? "Console Connected"
                                        : MOTIONConnector.state === 3 ? "Ready"
                                        : "Running")
                        font.pixelSize: 16
                        color: "#BDC3C7"
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    // Connection Indicators (TX, HV)
                    RowLayout {
                        spacing: 20
                        anchors.horizontalCenter: parent.horizontalCenter

                        // Sensor LED
                        RowLayout {
                            spacing: 5
                            // LED circle
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: MOTIONConnector.sensorConnected ? "green" : "red"
                                border.color: "black"
                                border.width: 1
                            }
                            // Label for Snsor
                            Text {
                                text: "Sensor"
                                font.pixelSize: 16
                                color: "#BDC3C7"
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        // Console LED
                        RowLayout {
                            spacing: 5
                            // LED circle
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: MOTIONConnector.consoleConnected ? "green" : "red"
                                border.color: "black"
                                border.width: 1
                            }
                            // Label for Console
                            Text {
                                text: "Console"
                                font.pixelSize: 16
                                color: "#BDC3C7"
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }

    }
    
    // **Connections for MOTIONConnector signals**
    Connections {
        target: MOTIONConnector

        function onSignalConnected(descriptor, port) {
            console.log(descriptor + " connected on " + port);
            statusText.text = "Connected: " + descriptor + " on " + port;
        }

        function onSignalDisconnected(descriptor, port) {
            console.log(descriptor + " disconnected from " + port);
            statusText.text = "Disconnected: " + descriptor + " from " + port;
        }

        function onSignalDataReceived(descriptor, message) {
            console.log("Data from " + descriptor + ": " + message);
        }
    }


    Component.onCompleted: {
        
    }

    Component.onDestruction: {
        console.log("Closing UI, clearing MOTIONConnector...");
        MOTIONConnector.stop_monitoring();
        MOTIONConnector = null;  // Ensure QML does not access it
    }
}
