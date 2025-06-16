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

    // Properties for dynamic data
    property string firmwareVersion: "N/A"
    property string deviceId: "N/A"
    property string rgbState: "Off" // Add property for Indicator state
    property int fan_speed: 0
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

    // Define the model for accessSelector
    ListModel {
        id: accessModeModel
    }

    function updateFpgaFunctionUI(index) {
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

    function updateStates() {
        console.log("Console Updating all states...")
        MOTIONConnector.queryConsoleInfo()
        MOTIONConnector.queryRGBState() // Query Indicator state
        MOTIONConnector.queryFans() // Query Indicator state
        
    }


    // Run refresh logic immediately on page load if Console is already connected
    Component.onCompleted: {
        if (MOTIONConnector.consoleConnected) {
            console.log("Page Loaded - Console Already Connected. Fetching Info...")
            updateStates()
        }
    }

    Timer {
        id: infoTimer
        interval: 1500   // Delay to ensure Sensor is stable before fetching info
        running: false
        onTriggered: {
            console.log("Fetching Firmware Version and Device ID...")
            updateStates()
        }
    }

    Connections {
        target: MOTIONConnector

        // Handle Console Connected state
        function onConsoleConnectedChanged() {
            if (MOTIONConnector.consoleConnected) {
                infoTimer.start()          // One-time info fetch
            } else {
                console.log("Console Disconnected - Clearing Data...")
                firmwareVersion = "N/A"
                deviceId = "N/A"
                rgbState = "Off" // Indicator off
                fan_speed = 0
                
                pingResult.text = ""
                echoResult.text = ""
                toggleLedResult.text = ""
                pduResult.text = ""
                tecResult.text = ""
                seedResult.text = ""
                safetyResult.text = ""
                safety2Result.text = ""
                taResult.text = ""
            }
        }

        // Handle device info response
        function onConsoleDeviceInfoReceived(fwVersion, devId) {
            firmwareVersion = fwVersion
            deviceId = devId
        }

        function onTriggerStateChanged(state) {
            triggerStatus.text = state ? "On" : "Off";
            triggerStatus.color = state ? "green" : "red";
        }

        function onRgbStateReceived(stateValue, stateText) {
            rgbState = stateText
            rgbLedResult.text = stateText  // Display the state as text
            rgbLedDropdown.currentIndex = stateValue  // Sync ComboBox to received state
        }

        function onFanSpeedsReceived(fanVal) {
            fan_speed = fanVal
            fanSlider.value = fanVal;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Title
        Text {
            text: "Console Module Unit Tests"
            font.pixelSize: 20
            font.weight: Font.Bold
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }

        // Content Section
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1E1E20"
            radius: 10
            border.color: "#3E4E6F"
            border.width: 2
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 10

                // Vertical Stack Section
                ColumnLayout {
                    Layout.fillHeight: true
                    Layout.preferredWidth: parent.width * 0.65
                    spacing: 10
                    
                    // Communication Tests Box
                    Rectangle {
                        width: 650
                        height: 310
                        radius: 6
                        color: "#1E1E20"
                        border.color: "#3E4E6F"
                        border.width: 2

                        // Title at Top-Center with 5px Spacing
                        Text {
                            text: "Communication Tests"
                            color: "#BDC3C7"
                            font.pixelSize: 18
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.topMargin: 5  // 5px spacing from the top
                        }

                        // Content for comms tests
                        GridLayout {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.leftMargin: 20   
                            anchors.topMargin: 40    
                            columns: 5
                            rowSpacing: 10
                            columnSpacing: 10

                            // Row 1
                            // Ping Button and Result
                            Button {
                                id: pingButton
                                text: "Ping"
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 40
                                hoverEnabled: true  // Enable hover detection
                                enabled: MOTIONConnector.consoleConnected 

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#BDC3C7" : "#7F8C8D"  // Gray out text when disabled
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    id: pingButtonBackground
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
                                    if(MOTIONConnector.sendPingCommand("CONSOLE")){                                        
                                        pingResult.text = "Ping SUCCESS"
                                        pingResult.color = "green"
                                    }else{
                                        pingResult.text = "Ping FAILED"
                                        pingResult.color = "red"
                                    }
                                }
                            }
                            Text {
                                id: pingResult
                                Layout.preferredWidth: 80
                                text: ""
                                color: "#BDC3C7"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item {
                                Layout.preferredWidth: 200 
                            }

                            Button {
                                id: ledButton
                                text: "Toggle LED"
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 40
                                hoverEnabled: true  // Enable hover detection
                                enabled: MOTIONConnector.consoleConnected 

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#BDC3C7" : "#7F8C8D"  // Gray out text when disabled
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    id: ledButtonBackground
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
                                    if(MOTIONConnector.sendLedToggleCommand("CONSOLE"))
                                    {
                                        toggleLedResult.text = "LED Toggled"
                                        toggleLedResult.color = "green"
                                    }
                                    else{
                                        toggleLedResult.text = "LED Toggle FAILED"
                                        toggleLedResult.color = "red"
                                    }
                                }
                            }
                            Text {
                                id: toggleLedResult
                                Layout.preferredWidth: 80
                                color: "#BDC3C7"
                                text: ""
                            }

                            // Row 2
                            // Echo Button and Result
                            Button {
                                id: echoButton
                                text: "Echo"
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 40
                                hoverEnabled: true  // Enable hover detection
                                enabled: MOTIONConnector.consoleConnected 

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#BDC3C7" : "#7F8C8D"  // Gray out text when disabled
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    id: echoButtonBackground
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

                                    if(MOTIONConnector.sendEchoCommand("CONSOLE"))
                                    {
                                        echoResult.text = "Echo SUCCESS"
                                        echoResult.color = "green"
                                    }
                                    else{
                                        echoResult.text = "Echo FAILED"
                                        echoResult.color = "red"
                                    }
                                } 
                            }
                            Text {
                                id: echoResult
                                Layout.preferredWidth: 80
                                text: ""
                                color: "#BDC3C7"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item {
                                Layout.preferredWidth: 200 
                            }

                            ComboBox {
                                id: rgbLedDropdown
                                Layout.preferredWidth: 120
                                Layout.preferredHeight: 28
                                model: ["Off", "IND1", "IND2", "IND3"]
                                enabled: MOTIONConnector.consoleConnected  

                                onActivated: {
                                    let rgbValue = rgbLedDropdown.currentIndex  // Directly map ComboBox index to integer value
                                    MOTIONConnector.setRGBState(rgbValue)         // Assuming you implement this new method
                                    rgbLedResult.text = rgbLedDropdown.currentText
                                }
                            }
                            Text {
                                id: rgbLedResult
                                Layout.preferredWidth: 80
                                color: "#BDC3C7"
                                text: "Off"
                            }

                            // Row 3
                            // PDU Button and Result
                            Button {
                                id: pduButton
                                text: "PDU"
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 40
                                hoverEnabled: true  // Enable hover detection
                                enabled: MOTIONConnector.consoleConnected 

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#BDC3C7" : "#7F8C8D"  // Gray out text when disabled
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    id: pduButtonBackground
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
                                    var devices = MOTIONConnector.scanI2C(1, 0)
                                    if (devices && devices.includes("0x20") && devices.includes("0x48")  && devices.includes("0x4b")) {
                                        pduResult.text = "PDU SUCCESS"
                                        pduResult.color = "green"
                                    } else {
                                        pduResult.text = "PDU FAILED"
                                        pduResult.color = "red"
                                    }
                                }
                            }
                            Text {
                                id: pduResult
                                Layout.preferredWidth: 80
                                text: ""
                                color: "#BDC3C7"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item {
                                Layout.preferredWidth: 200 
                            }

                            Button {
                                id: seedButton
                                text: "Seed"
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 40
                                hoverEnabled: true  // Enable hover detection
                                enabled: MOTIONConnector.consoleConnected 

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#BDC3C7" : "#7F8C8D"  // Gray out text when disabled
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    id: seedButtonBackground
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
                                    var devices = MOTIONConnector.scanI2C(1, 5)
                                    if (devices && devices.includes("0x41")) {
                                        seedResult.text = "Seed SUCCESS"
                                        seedResult.color = "green"
                                    } else {
                                        seedResult.text = "Seed FAILED"
                                        seedResult.color = "red"
                                    }
                                }
                            }
                            Text {
                                id: seedResult
                                Layout.preferredWidth: 80
                                color: "#BDC3C7"
                                text: ""
                            }

                            // Row 4
                            // TA Button and Result
                            Button {
                                id: taButton
                                text: "TA"
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 40
                                hoverEnabled: true  // Enable hover detection
                                enabled: MOTIONConnector.consoleConnected 

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#BDC3C7" : "#7F8C8D"  // Gray out text when disabled
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    id: taButtonBackground
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
                                    var devices = MOTIONConnector.scanI2C(1, 4)
                                    if (devices && devices.includes("0x41")) {
                                        taResult.text = "TA SUCCESS"
                                        taResult.color = "green"
                                    } else {
                                        taResult.text = "TA FAILED"
                                        taResult.color = "red"
                                    }
                                }
                            }
                            Text {
                                id: taResult
                                Layout.preferredWidth: 80
                                text: ""
                                color: "#BDC3C7"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item {
                                Layout.preferredWidth: 200 
                            }

                            Button {
                                id: safetyButton
                                text: "Safety EE"
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 40
                                hoverEnabled: true  // Enable hover detection
                                enabled: MOTIONConnector.consoleConnected 

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#BDC3C7" : "#7F8C8D"  // Gray out text when disabled
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    id: safetyButtonBackground
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
                                    
                                    var devices = MOTIONConnector.scanI2C(1, 6)
                                    if (devices && devices.includes("0x41")) {
                                        safetyResult.text = "Safety EE SUCCESS"
                                        safetyResult.color = "green"
                                    } else {
                                        safetyResult.text = "Safety EE FAILED"
                                        safetyResult.color = "red"
                                    }
                                }
                            }
                            Text {
                                id: safetyResult
                                Layout.preferredWidth: 80
                                color: "#BDC3C7"
                                text: ""
                            }

                            

                            // Row 5
                            // TEC Button and Result
                            Button {
                                id: tecButton
                                text: "TEC"
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 40
                                hoverEnabled: true  // Enable hover detection
                                enabled: MOTIONConnector.consoleConnected 

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#BDC3C7" : "#7F8C8D"  // Gray out text when disabled
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    id: tecButtonBackground
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
                                    var devices = MOTIONConnector.scanI2C(1, 3)
                                    if (devices && devices.includes("0x49") && devices.includes("0x4c")) {
                                        tecResult.text = "TEC SUCCESS"
                                        tecResult.color = "green"
                                    } else {
                                        tecResult.text = "TEC FAILED"
                                        tecResult.color = "red"
                                    }
                                }
                            }
                            Text {
                                id: tecResult
                                Layout.preferredWidth: 80
                                text: ""
                                color: "#BDC3C7"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item {
                                Layout.preferredWidth: 200 
                            }

                            Button {
                                id: safety2Button
                                text: "Safety OPT"
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 40
                                hoverEnabled: true  // Enable hover detection
                                enabled: MOTIONConnector.consoleConnected 

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#BDC3C7" : "#7F8C8D"  // Gray out text when disabled
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    id: safety2ButtonBackground
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
                                    
                                    var devices = MOTIONConnector.scanI2C(1, 7)
                                    if (devices && devices.includes("0x41")) {
                                        safety2Result.text = "Safety OPT SUCCESS"
                                        safety2Result.color = "green"
                                    } else {
                                        safety2Result.text = "Safety OPT FAILED"
                                        safety2Result.color = "red"
                                    }
                                }
                            }
                            Text {
                                id: safety2Result
                                Layout.preferredWidth: 80
                                color: "#BDC3C7"
                                text: ""
                            }
                        }
                    }
                                        

                    // FPGA Utility
                    Rectangle {
                        width: 650
                        height: 140
                        radius: 8
                        color: "#1E1E20"
                        border.color: "#3E4E6F"
                        border.width: 2
                        enabled: MOTIONConnector.consoleConnected

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
                                        updateFpgaFunctionUI(0)
                                    }
                                }

                                ComboBox {
                                    id: functionSelector
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    model: fpgaSelector.currentIndex >= 0 ? FpgaData.fpgaAddressModel[fpgaSelector.currentIndex].functions : []
                                    textRole: "name"
                                    enabled: fpgaSelector.currentIndex >= 0

                                    onCurrentIndexChanged: updateFpgaFunctionUI(currentIndex)
                                    onModelChanged: {
                                        if (functionSelector.model.length > 0) {
                                            functionSelector.currentIndex = 0;
                                            updateFpgaFunctionUI(0);
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

                                DoubleValidator {
                                    id: doubleVal
                                    bottom: 0
                                }

                                RegularExpressionValidator {
                                    id: hexVal
                                    regularExpression: hexValidator
                                }

                                TextField {
                                    id: hexInput
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    placeholderText: fn && fn.unit ? `e.g. 12.8 ${fn.unit}` : placeholderHex
                                    enabled: accessSelector.currentText === "Write"
                                    validator: fn && fn.unit ? doubleVal : hexVal
                                    text: {
                                        if (!fn || rawValue === undefined) return "";
                                        if (fn.unit && fn.scale)
                                            return (rawValue * fn.scale).toFixed(2);
                                        return "0x" + rawValue.toString(16).toUpperCase();
                                    }
                                }

                                Button {
                                    id: exeButton
                                    text: "Execute"
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 40
                                    hoverEnabled: true
                                    enabled: MOTIONConnector.consoleConnected && functionSelector.currentIndex >= 0 &&
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
                                        let data = hexInput.text;

                                        if (dir === "Read") {
                                            console.log(`READ from ${fpga.label} @ 0x${offset.toString(16)}`);
                                            let result = MOTIONConnector.i2cReadBytes("CONSOLE", muxIdx, channel, i2cAddr, offset, length);

                                            if (result.length === 0) {
                                                console.log("Read failed or returned empty array.");
                                                i2cStatus.text = "Read failed";
                                                i2cStatus.color = "red";
                                            } else {
                                                let fullValue = 0;
                                                for (let i = 0; i < result.length; i++) {
                                                    fullValue = (fullValue << 8) | result[i];
                                                }

                                                rawValue = fullValue;  // store globally

                                                if (fn.unit && fn.scale) {
                                                    hexInput.text = (fullValue * fn.scale).toFixed(2);
                                                } else {
                                                    let hexStr = "0x" + fullValue.toString(16).toUpperCase().padStart(length * 2, "0");
                                                    hexInput.text = hexStr;
                                                }

                                                console.log("Read success:", hexInput.text);
                                                i2cStatus.text = "Read successful";
                                                i2cStatus.color = "lightgreen";
                                            }

                                            cleari2cStatusTimer.start();
                                        } else {
                                            console.log(`WRITE to ${fpga.label} @ 0x${offset.toString(16)} = ${data}`);

                                            let fullValue = 0;

                                            if (fn.unit && fn.scale) {
                                                const floatVal = parseFloat(data);
                                                if (isNaN(floatVal)) {
                                                    console.warn("Invalid numeric input for unit conversion.");
                                                    return;
                                                }
                                                fullValue = Math.round(floatVal / fn.scale);
                                            } else {
                                                let sanitized = data.replace(/0x/gi, "").replace(/\s+/g, "");

                                                if (sanitized.length > length * 2) {
                                                    console.warn("Input too long, trimming.");
                                                    sanitized = sanitized.slice(-length * 2);
                                                } else if (sanitized.length < length * 2) {
                                                    sanitized = sanitized.padStart(length * 2, "0");
                                                }

                                                fullValue = parseInt(sanitized, 16);
                                            }

                                            rawValue = fullValue;  // store globally

                                            let dataToSend = [];
                                            for (let i = length - 1; i >= 0; i--) {
                                                dataToSend.push((fullValue >> (i * 8)) & 0xFF);
                                            }

                                            console.log("Data to send:", dataToSend.map(b => "0x" + b.toString(16).padStart(2, "0")).join(" "));

                                            let success = MOTIONConnector.i2cWriteBytes("CONSOLE", muxIdx, channel, i2cAddr, offset, dataToSend);

                                            if (success) {
                                                console.log("Write successful.");
                                                i2cStatus.text = "Write successful";
                                                i2cStatus.color = "lightgreen";
                                            } else {
                                                console.log("Write failed.");
                                                i2cStatus.text = "Write failed";
                                                i2cStatus.color = "red";
                                            }

                                            cleari2cStatusTimer.start();
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

                    // Fan Tests Box
                    Rectangle {
                        width: 650
                        height: 140
                        radius: 8
                        color: "#1E1E20"
                        border.color: "#3E4E6F"
                        border.width: 2

                        // Title at Top-Center with 5px Spacing
                        Text {
                            text: "Fan Tests"
                            color: "#BDC3C7"
                            font.pixelSize: 18
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.topMargin: 5  // 5px spacing from the top
                        }

                        // Slider for Fan
                        Column {
                            anchors.top: parent.top
                            anchors.topMargin: 28  // Adjust spacing as needed
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5


                            Rectangle {  // Acts as a spacer
                                height: 10
                                width: 1
                                color: "transparent"
                            }
                            
                            Text {
                                text: "Console Fan: " + (fanSlider.value === 0 ? "OFF" : fanSlider.value.toFixed(0) + "%")
                                color: "#BDC3C7"
                                font.pixelSize: 14
                            }

                            Slider {
                                id: fanSlider
                                width: 600  // Adjust width as needed
                                from: 0
                                to: 100
                                stepSize: 10   // Snap to increments of 10
                                value: 0  // Default value is 0 (OFF)
                                enabled: MOTIONConnector.consoleConnected 

                                property bool userIsSliding: false

                                onPressedChanged: {
                                    if (pressed) {
                                        userIsSliding = true
                                    } else if (!pressed && userIsSliding) {
                                        // User has finished sliding
                                        let snappedValue = Math.round(value / 10) * 10
                                        value = snappedValue
                                        console.log("Slider released at:", snappedValue)
                                        userIsSliding = false
                                        let success = MOTIONConnector.setFanLevel(snappedValue);
                                        if (success) {
                                            console.log("Fan speed set successfully");
                                        } else {
                                            console.log("Failed to set fan speed");
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Large Third Column
                Rectangle {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    color: "#1E1E20"
                    radius: 10
                    border.color: "#3E4E6F"
                    border.width: 2

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 10

                        // Sensor Status Indicator
                        RowLayout {
                            spacing: 8

                            Text { text: "Sensor"; font.pixelSize: 16; color: "#BDC3C7" }
                        
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: MOTIONConnector.consoleConnected ? "green" : "red"
                                border.color: "black"
                                border.width: 1
                            }

                            Text {
                                text: MOTIONConnector.consoleConnected ? "Connected" : "Not Connected"
                                font.pixelSize: 16
                                color: "#BDC3C7"
                            }
                        
                        // Spacer to push the Refresh Button to the right
                            Item {
                                Layout.fillWidth: true
                            }

                            
                            // Refresh Button
                            Rectangle {
                                width: 30
                                height: 30
                                radius: 15
                                color: enabled ? "#2C3E50" : "#7F8C8D"  // Dim when disabled
                                Layout.alignment: Qt.AlignRight  
                                enabled: MOTIONConnector.consoleConnected

                                // Icon Text
                                Text {
                                    text: "\u21BB"  // Unicode for the refresh icon
                                    anchors.centerIn: parent
                                    font.pixelSize: 20
                                    font.family: iconFont.name  // Use the loaded custom font
                                    color: enabled ? "white" : "#BDC3C7"  // Dim icon text when disabled
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: parent.enabled  // MouseArea also disabled when button is disabled
                                    onClicked: {
                                        console.log("Manual Refresh Triggered")
                                        updateStates();
                                    }

                                    onEntered: if (parent.enabled) parent.color = "#34495E"  // Highlight only when enabled
                                    onExited: parent.color = enabled ? "#2C3E50" : "#7F8C8D"
                                }
                            }
                        }
                        // Divider Line
                        Rectangle {
                            Layout.fillWidth: true
                            height: 2
                            color: "#3E4E6F"
                        }

                        // Display Device ID (Smaller Text)
                        RowLayout {
                            spacing: 8
                            Text { text: "Device ID:"; color: "#BDC3C7"; font.pixelSize: 14 }
                            Text { text: deviceId; color: "#3498DB"; font.pixelSize: 14 }
                        }

                        // Display Firmware Version (Smaller Text)
                        RowLayout {
                            spacing: 8
                            Text { text: "Firmware Version:"; color: "#BDC3C7"; font.pixelSize: 14 }
                            Text { text: firmwareVersion; color: "#2ECC71"; font.pixelSize: 14 }
                        }


                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter 
                            spacing: 25  

                        }


                        // Soft Reset Button
                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: 10
                            color: enabled ? "#E74C3C" : "#7F8C8D"  // Red when enabled, gray when disabled
                            enabled: MOTIONConnector.consoleConnected

                            Text {
                                text: "Soft Reset"
                                anchors.centerIn: parent
                                color: parent.enabled ? "white" : "#BDC3C7"  // White when enabled, light gray when disabled
                                font.pixelSize: 18
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: parent.enabled  // Disable MouseArea when the button is disabled
                                onClicked: {
                                    console.log("Soft Reset Triggered")
                                    MOTIONConnector.softResetSensor("CONSOLE")
                                }

                                onEntered: {
                                    if (parent.enabled) {
                                        parent.color = "#C0392B"  // Darker red on hover (only when enabled)
                                    }
                                }
                                onExited: {
                                    if (parent.enabled) {
                                        parent.color = "#E74C3C"  // Restore original color (only when enabled)
                                    }
                                }
                            }

                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                        }
                    }
                }
            }                    
        }
    }

    FontLoader {
        id: iconFont
        source: "../assets/fonts/keenicons-outline.ttf"
    }

}
