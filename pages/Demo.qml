import QtQuick 6.0
import QtQuick.Controls 6.0
import QtQuick.Layouts 6.0
import QtQml 2.15 

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
                            }
                        }
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
                                        spacing: 4

                                        Text {
                                            text: (index * 16).toString(16).toUpperCase().padStart(2, "0")
                                            width: 30
                                            height: 24
                                            color: "white"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
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
                                                    text: "00"
                                                    font.family: "monospace"
                                                    color: "white"
                                                    maximumLength: 2
                                                    inputMask: "HH"
                                                    font.pixelSize: 12
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
    
    Component.onDestruction: {
        console.log("Closing UI, clearing MOTIONConnector...");
        MOTIONConnector.stop_monitoring();
        MOTIONConnector = null;  // Ensure QML does not access it
    }
}
