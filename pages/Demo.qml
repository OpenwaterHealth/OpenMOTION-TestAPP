import QtQuick 6.0
import QtQuick.Controls 6.0
import QtQuick.Layouts 6.0
import QtQml 2.15 
import QtQuick 2.15

Rectangle {
    id: page1
    width: parent.width
    height: parent.height
    color: "#29292B" // Background color for Page 1
    radius: 20
    opacity: 0.95 // Slight transparency for the content area

    ListModel {
        id: fpgaAddressModel
        ListElement { label: "TA"; mux_idx: 1; channel: 4; i2c_addr: 0x41 }
        ListElement { label: "Seed"; mux_idx: 1; channel: 5; i2c_addr: 0x41 }
        ListElement { label: "Safety EE"; mux_idx: 1; channel: 6; i2c_addr: 0x41 }
        ListElement { label: "Safety OPT"; mux_idx: 1; channel: 7; i2c_addr: 0x41 }
    }

    ListModel {
        id: byteModel
        // Will be populated by the read function
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
                id: inputContainer
                width: 500
                height: 200
                color: "#1E1E20"
                radius: 10
                border.color: "#3E4E6F"
                border.width: 2
            }

            Rectangle {
                id: inputContainer2
                width: 500
                height: 400
                color: "#1E1E20"
                radius: 10
                border.color: "#3E4E6F"
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    // Title
                    Text {
                        text: "FPGA I2C Utility"
                        color: "#BDC3C7"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Layout.fillWidth: true
                    }

                    // Spacer between title and dropdowns
                    Rectangle {
                        color: "transparent"
                        height: 6
                        Layout.fillWidth: true
                    }

                    // Row: Dropdown + Offset + Byte Count
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.preferredHeight: 36

                        ComboBox {
                            id: fpgaSelector
                            model: fpgaAddressModel
                            textRole: "label"
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 32
                            enabled: MOTIONConnector.consoleConnected
                        }

                        Item {
                            Layout.preferredWidth: 5
                        }

                        TextField {
                            id: offsetField
                            placeholderText: "Offset"
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 32
                            validator: RegularExpressionValidator { regularExpression: /[0-9A-Fa-f]{1,2}/ }
                        }

                        Item {
                            Layout.preferredWidth: 5
                        }

                        TextField {
                            id: byteCountField
                            placeholderText: "Bytes"
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 32
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: IntValidator { bottom: 1; top: 256 }
                        }
                    }

                    // Row: Read + Write Buttons
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20


                        Button {
                            id: readButton
                            text: "Read"
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 50
                            hoverEnabled: true  // Enable hover detection
                            enabled: MOTIONConnector.consoleConnected 

                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? "#BDC3C7" : "#7F8C8D"  // Gray out text when disabled
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                id: readButtonBackground
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
                                console.log("Read " + byteCountField.text + " bytes from offset " + offsetField.text);          
                                let addr = fpgaAddressModel.get(fpgaSelector.currentIndex)
                                let offset = parseInt(offsetField.text, 16)
                                let length = parseInt(byteCountField.text)
                      
                                // Call read function
                                let result = MOTIONConnector.i2cReadBytes("CONSOLE", addr.mux_idx, addr.channel, addr.i2c_addr, offset, length)

                                if (result.length === 0) {
                                    console.log("Read failed or returned empty array.")
                                    i2cStatus.text = "Read failed"
                                    i2cStatus.color = "red"                                    
                                }else{
                                    i2cStatus.text = "Read successful"
                                    i2cStatus.color = "lightgreen"
                                    for (let i = 0; i < byteModel.count; i++) {
                                        byteModel.setProperty(i, "value", "00")
                                    }
                                                                        
                                    // Update byteModel
                                    for (let i = 0; i < result.length; i++) {
                                        let hexByte = result[i].toString(16).toUpperCase().padStart(2, "0")
                                        if (i < byteModel.count) {
                                            byteModel.setProperty(i, "value", hexByte)
                                        }
                                    }
                                }
                                                                    
                                cleari2cStatusTimer.start()
                            }
                        }

                        Item {
                            Layout.preferredWidth: 140
                        }

                        Button {
                            id: writeButton
                            text: "Write"
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 50
                            hoverEnabled: true  // Enable hover detection
                            enabled: MOTIONConnector.consoleConnected 

                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? "#BDC3C7" : "#7F8C8D"  // Gray out text when disabled
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                id: writeButtonBackground
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
                                console.log("Write " + byteCountField.text + " bytes to offset " + offsetField.text);    
                                let addr = fpgaAddressModel.get(fpgaSelector.currentIndex)
                                let offset = parseInt(offsetField.text, 16)
                                let length = parseInt(byteCountField.text)

                                let dataToSend = []
                                for (let i = 0; i < length; i++) {
                                    if (i < byteModel.count) {
                                        let byteStr = byteModel.get(i).value
                                        dataToSend.push(parseInt(byteStr, 16))
                                    }
                                }
                                let success = MOTIONConnector.i2cWriteBytes("CONSOLE", addr.mux_idx, addr.channel, addr.i2c_addr, offset, dataToSend)                         
                                
                                if (success) {
                                    i2cStatus.text = "Write successful"
                                    i2cStatus.color = "lightgreen"
                                } else {
                                    i2cStatus.text = "Write failed"
                                    i2cStatus.color = "red"
                                }
                                cleari2cStatusTimer.start()
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

                    // Spacer
                    Rectangle {
                        color: "transparent"
                        height: 3
                        Layout.fillWidth: true
                    }

                    // Hex Grid
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.leftMargin: 10
                        Rectangle {
                            id: hexGrid
                            color: "transparent"
                            Layout.alignment: Qt.AlignHCenter
                            width: 16 * 28 + 40
                            height: 8 * 24 + 30

                            Column {
                                id: contentRepeater
                                spacing: 2
                                Repeater {
                                    model: 8
                                    delegate: Row {
                                        property int rowIndex: index
                                        spacing: 4

                                        Text {
                                            text: (rowIndex * 16).toString(16).toUpperCase().padStart(2, "0")
                                            width: 30
                                            height: 24
                                            color: "white"
                                            font.family: "monospace"
                                            font.pixelSize: 14
                                        }

                                        Repeater {
                                            model: 16
                                            delegate: Rectangle {
                                                width: 22
                                                height: 22
                                                radius: 3
                                                color: "#2C2C2E"
                                                border.color: "#5D5D60"
                                                border.width: 1

                                                TextInput {
                                                    anchors.centerIn: parent
                                                    width: parent.width
                                                    height: parent.height
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    font.family: "monospace"
                                                    color: "white"
                                                    maximumLength: 2
                                                    inputMask: "HH"
                                                    font.pixelSize: 12

                                                    property int indexInModel: rowIndex * 16 + index

                                                    // NEW: Ensure correct initial value with modelData binding
                                                    text: (indexInModel < byteModel.count && byteModel.get(indexInModel)) ? byteModel.get(indexInModel).value : "00"

                                                    // Ensure model stays updated
                                                    onTextChanged: {
                                                        if (indexInModel < byteModel.count) {
                                                            byteModel.setProperty(indexInModel, "value", text.toUpperCase())
                                                        }
                                                    }

                                                }
                                            }
                                        }

                                    }
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
                id: graphContainer
                width: 500
                height: 470
                color: "#1E1E20"
                radius: 10
                border.color: "#3E4E6F"
                border.width: 2
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
        byteModel.clear()
        for (let i = 0; i < 128; i++) {
            byteModel.append({ "value": "00" })
        }
    }

    Component.onDestruction: {
        console.log("Closing UI, clearing MOTIONConnector...");
        MOTIONConnector.stop_monitoring();
        MOTIONConnector = null;  // Ensure QML does not access it
    }
}
