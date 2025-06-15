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
    property int rawValue: 0 
    
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
        ListElement { label: "Camera 1"; cam_num: 1; cam_mask: 0x01; channel: 0; i2c_addr: 0x41 }
        ListElement { label: "Camera 2"; cam_num: 2; cam_mask: 0x02; channel: 1; i2c_addr: 0x41 }
        ListElement { label: "Camera 3"; cam_num: 3; cam_mask: 0x04; channel: 2; i2c_addr: 0x41 }
        ListElement { label: "Camera 4"; cam_num: 4; cam_mask: 0x08; channel: 3; i2c_addr: 0x41 }
        ListElement { label: "Camera 5"; cam_num: 5; cam_mask: 0x10; channel: 4; i2c_addr: 0x41 }
        ListElement { label: "Camera 6"; cam_num: 6; cam_mask: 0x20; channel: 5; i2c_addr: 0x41 }
        ListElement { label: "Camera 7"; cam_num: 7; cam_mask: 0x40; channel: 6; i2c_addr: 0x41 }
        ListElement { label: "Camera 8"; cam_num: 8; cam_mask: 0x80; channel: 7; i2c_addr: 0x41 }
        ListElement { label: "Camera ALL"; cam_num: 9; cam_mask: 0xFF; channel: 7; i2c_addr: 0x41 }
    }
    
    ListModel {
        id: filteredPatternModel
    }
    
    ListModel {
        id: cameraModeModel
        ListElement { label: "Bars"; tp_id: 0x00}
        ListElement { label: "Solid"; tp_id: 0x01}
        ListElement { label: "Squares"; tp_id: 0x02}
        ListElement { label: "Continuous"; tp_id: 0x03}
        ListElement { label: "Live"; tp_id: 0x04}
        ListElement { label: "Stream"; tp_id: 0x04}
    }


    function readFpgaRegister(fpgaLabel, funcName, field) {
        
        const fModel = FpgaData.fpgaAddressModel.find(fpga => fpga.label === fpgaLabel);

        if (!fModel) {
            console.error("FPGA Label not found");
            return;
        }

        let  i2cAddr = fModel.i2c_addr;
        let  muxIdx = fModel.mux_idx;
        let  channel = fModel.channel;
        const myFn = fModel.functions.find(fn => fn.name === funcName);

        if (!myFn) {
            console.error("Function not found");
            return;
        }

        const offset = myFn.start_address;
        const data_len = parseInt(myFn.data_size.replace("B", "")) / 8;

        console.log(`READ from ${fModel.label} @ 0x${offset.toString(16)}`);
        let result = MOTIONConnector.i2cReadBytes("CONSOLE", muxIdx, channel, i2cAddr, offset, data_len);

        if (result.length === 0) {
            console.log("Read failed or returned empty array.");
            statusText.text = "Read " + funcName + " Failed";
            statusText.color = "red";
        } else {
            let fullValue = 0;
            for (let i = 0; i < result.length; i++) {
                fullValue = (fullValue << 8) | result[i];
            }

            let rawValue = fullValue;  // store globally

            if (myFn.unit && myFn.scale) {
                field.text = (fullValue * myFn.scale).toFixed(2);
            } else {
                let hexStr = "0x" + fullValue.toString(16).toUpperCase().padStart(length * 2, "0");
                field.text = hexStr;
            }
        }
    }

    function updateLaserUI() {
        readFpgaRegister("TA", "PULSE WIDTH", taPulseWidth);
        readFpgaRegister("TA", "CURRENT DRV", taDrive);
        readFpgaRegister("Seed", "DDS CURRENT", ddsCurrent);
        readFpgaRegister("Seed", "DDS CL", ddsCurrentLimit);
        readFpgaRegister("Seed", "CW CURRENT", cwSeedCurrent);
        readFpgaRegister("Seed", "CW CL", cwSeedCurrentLimit);
    }

    function updatePatternOptions() {
        filteredPatternModel.clear()
        let selectedCam = cameraModel.get(cameraSelector.currentIndex)
        if (selectedCam && selectedCam.cam_num === 9) {  // Camera ALL
            for (let i = 0; i < cameraModeModel.count; i++) {
                let mode = cameraModeModel.get(i)
                if (mode.label === "Stream") {
                    filteredPatternModel.append(mode)
                }
            }
        } else {
            for (let i = 0; i < cameraModeModel.count; i++) {
                filteredPatternModel.append(cameraModeModel.get(i))
            }
        }
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
            topMargin: 5
            bottomMargin: 5
        }
    }

    // LAYOUT
    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Left Column (Input Panel)
        ColumnLayout {
            spacing: 10

            // fpga container
            Rectangle {
                id: fpgaContainer
                width: 500
                height: 640
                color: "#1E1E20"
                radius: 10
                border.color: "#3E4E6F"
                border.width: 2
                enabled: MOTIONConnector.consoleConnected

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    GroupBox {
                        title: "TA"
                        Layout.fillWidth: true

                        GridLayout {
                            columns: 4
                            width: parent.width

                            Text { text: "TA Drive:"; color: "white" }
                            
                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "Current (mA)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: taDrive
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 30
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 0; top: 1000 }
                                    background: Rectangle {
                                        radius: 6; color: "#2B2B2E"; border.color: "#555"
                                    }
                                }
                            }

                            Item { Layout.preferredHeight: 30 } // Empty spacer
                            Item { Layout.preferredHeight: 30 } // Empty spacer

                            Text { text: "TA Pulse:"; color: "white" }
                            
                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "PulseWidth (uS)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: taPulseWidth
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 30
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 0; top: 1000 }
                                    background: Rectangle {
                                        radius: 6; color: "#2B2B2E"; border.color: "#555"
                                    }
                                }
                            }
                            
                            Item { Layout.preferredHeight: 30 } // Empty spacer

                            Button {
                                id: btnUpdateTa
                                text: "Update"
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 40
                                hoverEnabled: true
                                enabled: MOTIONConnector.consoleConnected

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#BDC3C7" : "#7F8C8D"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {                     
                                    color: {
                                        if (!parent.enabled) {
                                            return "#3A3F4B";  // Disabled color
                                        }
                                        return parent.hovered ? "#4A90E2" : "#3A3F4B";  // Blue on hover, default otherwise
                                    }
                                    border.color: {
                                        if (!parent.enabled) {
                                            return "#7F8C8D";  // Disabled border color
                                        }
                                        return parent.hovered ? "#FFFFFF" : "#BDC3C7";  // White border on hover, default otherwise
                                    }
                                    radius: 4
                                }

                                onClicked: {
                                    console.log("Update TA Settings");
                                }
                            }
                        }
                    }

                    GroupBox {
                        title: "Seed"
                        Layout.fillWidth: true

                        GridLayout {
                            columns: 4
                            width: parent.width

                            Text { text: "DDS:"; color: "white" }
                                                        
                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "Current (mA)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: ddsCurrent
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 30
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 0; top: 1000 }
                                    background: Rectangle {
                                        radius: 6; color: "#2B2B2E"; border.color: "#555"
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "Limit (mA)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: ddsCurrentLimit
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 30
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 0; top: 1000 }
                                    background: Rectangle {
                                        radius: 6; color: "#2B2B2E"; border.color: "#555"
                                    }
                                }
                            }

                            Item { Layout.preferredHeight: 30 } // Empty spacer

                            Text { text: "CW:"; color: "white" }
                            
                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "Current (mA)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: cwSeedCurrent
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 30
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 0; top: 1000 }
                                    background: Rectangle {
                                        radius: 6; color: "#2B2B2E"; border.color: "#555"
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "Limit (mA)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: cwSeedCurrentLimit
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 30
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 0; top: 1000 }
                                    background: Rectangle {
                                        radius: 6; color: "#2B2B2E"; border.color: "#555"
                                    }
                                }
                            }

                            Button {
                                id: btnUpdateSeed
                                text: "Update"
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 40
                                hoverEnabled: true
                                enabled: MOTIONConnector.consoleConnected 

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#BDC3C7" : "#7F8C8D"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {                     
                                    color: {
                                        if (!parent.enabled) {
                                            return "#3A3F4B";  // Disabled color
                                        }
                                        return parent.hovered ? "#4A90E2" : "#3A3F4B";  // Blue on hover, default otherwise
                                    }
                                    border.color: {
                                        if (!parent.enabled) {
                                            return "#7F8C8D";  // Disabled border color
                                        }
                                        return parent.hovered ? "#FFFFFF" : "#BDC3C7";  // White border on hover, default otherwise
                                    }
                                    radius: 4
                                }

                                onClicked: {
                                    console.log("Update Seed Settings");
                                }
                            }
                        }
                    }

                    GroupBox {
                        title: "Safety (OPT/EE)"
                        Layout.fillWidth: true

                        GridLayout {
                            columns: 4
                            width: parent.width

                            Text { text: "PulseWidth Limit:"; color: "white" }                            
                            
                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "Lower (uS)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: pwLowerLimit
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 30
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 0; top: 1000 }
                                    background: Rectangle {
                                        radius: 6; color: "#2B2B2E"; border.color: "#555"
                                    }
                                }
                            }                     
                            
                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "Upper (uS)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: pwUpperLimit
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 30
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 0; top: 1000 }
                                    background: Rectangle {
                                        radius: 6; color: "#2B2B2E"; border.color: "#555"
                                    }
                                }
                            }

                            Item { Layout.preferredHeight: 30 } // Empty spacer

                            Text { text: "Period Limit:"; color: "white" }
                            
                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "Lower (mS)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: periodLowerLimit
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 30
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 0; top: 1000 }
                                    background: Rectangle {
                                        radius: 6; color: "#2B2B2E"; border.color: "#555"
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "Upper (mS)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: periodUpperLimit
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 30
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 0; top: 1000 }
                                    background: Rectangle {
                                        radius: 6; color: "#2B2B2E"; border.color: "#555"
                                    }
                                }
                            }
                            
                            Item { Layout.preferredHeight: 30 } // Empty spacer

                            Text { text: "Drive Current:"; color: "white" }

                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "Limit (mA)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: driveCurrentLimit
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 30
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 0; top: 1000 }
                                    background: Rectangle {
                                        radius: 6; color: "#2B2B2E"; border.color: "#555"
                                    }
                                }
                            }
                            
                            Item { Layout.preferredHeight: 30 } // Empty spacer
                            Item { Layout.preferredHeight: 30 } // Empty spacer

                            Text { text: "CW Current:"; color: "white" }

                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "Limit (mA)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: cwSafetyCurrentLimit
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 30
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 0; top: 1000 }
                                    background: Rectangle {
                                        radius: 6; color: "#2B2B2E"; border.color: "#555"
                                    }
                                }
                            }
                            
                            Item { Layout.preferredHeight: 30 } // Empty spacer
                            Item { Layout.preferredHeight: 30 } // Empty spacer

                            Text { text: "PWM Current:"; color: "white" }

                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "Limit (mA)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: pwmCurrentLimit
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 30
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 0; top: 1000 }
                                    background: Rectangle {
                                        radius: 6; color: "#2B2B2E"; border.color: "#555"
                                    }
                                }
                            }
                                                        
                            Button {
                                id: btnUpdateSafety
                                text: "Update"
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 40
                                hoverEnabled: true
                                enabled: MOTIONConnector.consoleConnected 

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#BDC3C7" : "#7F8C8D"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {                                    
                                    color: {
                                        if (!parent.enabled) {
                                            return "#3A3F4B";  // Disabled color
                                        }
                                        return parent.hovered ? "#4A90E2" : "#3A3F4B";  // Blue on hover, default otherwise
                                    }
                                    border.color: {
                                        if (!parent.enabled) {
                                            return "#7F8C8D";  // Disabled border color
                                        }
                                        return parent.hovered ? "#FFFFFF" : "#BDC3C7";  // White border on hover, default otherwise
                                    }
                                    radius: 4
                                }

                                onClicked: {
                                    console.log("Update Safety Settings");
                                }
                            }
                        }
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
                height: 360
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
                    
                    // Row: Dropdowns
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.preferredHeight: 36

                        ComboBox {
                            id: cameraSelector
                            model: cameraModel
                            textRole: "label"
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 32
                            enabled: MOTIONConnector.sensorConnected

                            onCurrentIndexChanged: {
                                updatePatternOptions()
                            }
                        }

                        ComboBox {
                            id: patternSelector
                            model: filteredPatternModel
                            textRole: "label"
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 32
                            enabled: MOTIONConnector.sensorConnected
                            onCurrentIndexChanged: {
                                
                            }
                        }

                        Button {
                            id: idCameraCapButton
                            text: {
                                let mode = filteredPatternModel.get(patternSelector.currentIndex)
                                return (mode && mode.label === "Stream") ? (MOTIONConnector.isStreaming ? "Stop" : "Start") : "Capture"
                            }
                            Layout.preferredWidth: 100
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
                                let cam = cameraModel.get(cameraSelector.currentIndex)
                                let tp = filteredPatternModel.get(patternSelector.currentIndex)

                                if (tp && tp.label === "Stream") {
                                    if (MOTIONConnector.isStreaming) {
                                        MOTIONConnector.stopCameraStream(cam.cam_num)
                                        cameraCapStatus.text = "Stopped"
                                        cameraCapStatus.color = "red"
                                    } else {
                                        MOTIONConnector.startCameraStream(cam.cam_num)
                                        cameraCapStatus.text = "Streaming"
                                        cameraCapStatus.color = "lightgreen"
                                    }
                                } else {
                                    console.log("Capture Histogram from " + cam.cam_num + " TestPattern: " + tp.tp_id)
                                    
                                    Qt.callLater(() => {
                                        cameraCapStatus.text = "Capturing..."
                                        cameraCapStatus.color = "orange"
                                    })

                                    MOTIONConnector.getCameraHistogram(cam.cam_num, tp.tp_id)
                                }
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

            // Trigger
            Rectangle {
                id: triggerContainer
                width: 500
                height: 120
                color: "#1E1E20"
                radius: 10
                border.color: "#3E4E6F"
                border.width: 2
                enabled: MOTIONConnector.sensorConnected

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 10

                    GroupBox {
                        title: "Trigger"
                        Layout.fillWidth: true
                        background: Item {}
                        topPadding: 20

                        GridLayout {
                            columns: 4
                            width: parent.width

                            // Frequency
                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "Frequency (Hz)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: fsFrequency
                                    placeholderText: "1 - 100"
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 24
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 1; top: 100 }
                                    background: Rectangle {
                                        radius: 6
                                        color: "#2B2B2E"
                                        border.color: "#555"
                                    }
                                }
                            }

                            // PulseWidth
                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "PulseWidth (µs)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: fsPulseWidth
                                    placeholderText: "e.g. 500"
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 24
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 1; top: 1000 }
                                    background: Rectangle {
                                        radius: 6; color: "#2B2B2E"; border.color: "#555"
                                    }
                                }
                            }

                            // Laser Delay
                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "Laser Delay (µs)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: lsDelay
                                    placeholderText: "e.g. 100"
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 24
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 0; top: 1000 }
                                    background: Rectangle {
                                        radius: 6; color: "#2B2B2E"; border.color: "#555"
                                    }
                                }
                            }

                            // Laser PulseWidth
                            ColumnLayout {
                                Layout.columnSpan: 1
                                Layout.alignment: Qt.AlignLeft
                                spacing: 2

                                Text {
                                    text: "Laser PW (µs)"
                                    color: "#BDC3C7"
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: lsPulseWidth
                                    placeholderText: "e.g. 100"
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 24
                                    enabled: MOTIONConnector.consoleConnected
                                    font.pixelSize: 12
                                    validator: IntValidator { bottom: 0; top: 1000 }
                                    background: Rectangle {
                                        radius: 6; color: "#2B2B2E"; border.color: "#555"
                                    }
                                }
                            }

                            Button {
                                id: btnStartTrigger
                                text: "Start Trigger"
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 34
                                enabled: MOTIONConnector.consoleConnected
                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#BDC3C7" : "#7F8C8D"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {                     
                                    color: {
                                        if (!parent.enabled) {
                                            return "#3A3F4B";  // Disabled color
                                        }
                                        return parent.hovered ? "#4A90E2" : "#3A3F4B";  // Blue on hover, default otherwise
                                    }
                                    border.color: {
                                        if (!parent.enabled) {
                                            return "#7F8C8D";  // Disabled border color
                                        }
                                        return parent.hovered ? "#FFFFFF" : "#BDC3C7";  // White border on hover, default otherwise
                                    }
                                    radius: 4
                                }
                                onClicked: {
                                    var json_trigger_data = {
                                        "TriggerFrequencyHz": parseInt(fsFrequency.text),
                                        "TriggerPulseWidthUsec": parseInt(fsPulseWidth.text),
                                        "LaserPulseDelayUsec": parseInt(lsDelay.text),
                                        "LaserPulseWidthUsec": parseInt(lsPulseWidth.text),
                                        "EnableSyncOut": false,
                                        "EnableTaTrigger": true
                                    }
                                    var jsonString = JSON.stringify(json_trigger_data);
                                    if (MOTIONConnector.setTrigger(jsonString)) {
                                        MOTIONConnector.startTrigger()
                                    } else {
                                        console.log("Failed to apply trigger config")
                                    }
                                }
                            }

                            Button {
                                id: btnStopTrigger
                                text: "Stop Trigger"
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 34
                                enabled: MOTIONConnector.consoleConnected
                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#BDC3C7" : "#7F8C8D"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {                     
                                    color: {
                                        if (!parent.enabled) {
                                            return "#3A3F4B";  // Disabled color
                                        }
                                        return parent.hovered ? "#4A90E2" : "#3A3F4B";  // Blue on hover, default otherwise
                                    }
                                    border.color: {
                                        if (!parent.enabled) {
                                            return "#7F8C8D";  // Disabled border color
                                        }
                                        return parent.hovered ? "#FFFFFF" : "#BDC3C7";  // White border on hover, default otherwise
                                    }
                                    radius: 4
                                }
                                onClicked: MOTIONConnector.stopTrigger()
                            }

                            // Status Label aligned right
                            Text {
                                id: triggerStatus
                                text: MOTIONConnector.triggerState
                                color: triggerStatus.text === "ON" ? "lightgreen" : "red"
                                font.pixelSize: 14
                                Layout.columnSpan: 2
                                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                            }
                        }
                    }
                }
            }

			// Status Panel (Connection Indicators)
            Rectangle {
                id: statusPanel
                width: 500
                height: 120
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

    Timer {
        id: consoleUpdateTimer
        interval: 500
        running: false
        onTriggered: {            
            if (MOTIONConnector.consoleConnected) {
                const config = MOTIONConnector.queryTriggerConfig()
                if (config) {
                    fsFrequency.text = config.TriggerFrequencyHz.toString()
                    fsPulseWidth.text = config.TriggerPulseWidthUsec.toString()
                    lsDelay.text = config.LaserPulseDelayUsec.toString()
                    lsPulseWidth.text = config.LaserPulseWidthUsec.toString()
                }
                
                updateLaserUI();
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
        
        function onHistogramReady(bins) {
            if(bins.length != 1024){
                console.log("Histogram received, bins: " + bins.length)
            }
            histogramWidget.histogramData = bins
            histogramWidget.maxValue = Math.max(...bins)
            histogramWidget.forceRepaint?.()

            Qt.callLater(() => {
                cameraCapStatus.text = "Ready"
                cameraCapStatus.color = "lightgreen"
            });                     
        }
        
        function onConnectionStatusChanged() {          
            if (MOTIONConnector.sensorConnected) {
            }   
            if (MOTIONConnector.consoleConnected) {
                consoleUpdateTimer.start()
            }            
        }

        function onIsStreamingChanged() {
            cameraCapStatus.text = MOTIONConnector.isStreaming ? "Streaming" : "Stopped"
            cameraCapStatus.color = MOTIONConnector.isStreaming ? "lightgreen" : "red"
        }

        function onUpdateCapStatus(message) {
            cameraCapStatus.text = message
            cameraCapStatus.color = "orange"
        }

    }

    // Run refresh logic immediately on page load if Sensor is already connected
    Component.onCompleted: {
        if (MOTIONConnector.sensorConnected) {
        }   
        if (MOTIONConnector.consoleConnected) {
            consoleUpdateTimer.start()
        }    
        updatePatternOptions()
    }

    Component.onDestruction: {
        console.log("Closing UI, clearing MOTIONConnector...");
        MOTIONConnector.stop_monitoring();
        MOTIONConnector = null;  // Ensure QML does not access it
    }
}
