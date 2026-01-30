import QtQuick 6.0
import QtQuick.Controls 6.0
import QtQuick.Layouts 6.0

Rectangle {
    id: page1
    width: parent.width
    height: parent.height
    color: "#29292B" // Background color for Page 1
    radius: 20
    opacity: 0.95 // Slight transparency for the content area

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Title
        Text {
            text: "Settings"
            font.pixelSize: 20
            font.weight: Font.Bold
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 20
            
            // Console 
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

                    // Console Status Indicator
                    RowLayout {
                        spacing: 8

                        Text { text: "Console"; font.pixelSize: 16; color: "#BDC3C7" }
                    
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: MOTIONInterface.consoleConnected ? "green" : "red"
                            border.color: "black"
                            border.width: 1
                        }

                        Text {
                            text: MOTIONInterface.consoleConnected ? "Connected" : "Not Connected"
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
                            enabled: MOTIONInterface.consoleConnected

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
                                    // console.log("Manual Refresh Triggered")
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

                    // Board Rev ID (Smaller Text)
                    RowLayout {
                        spacing: 8
                        Text { text: "Board Rev ID:"; color: "#BDC3C7"; font.pixelSize: 14 }
                        Text { text: boardRevId; color: "#3498DB"; font.pixelSize: 14 }
                    }

                    // Display Firmware Version (Smaller Text)
                    RowLayout {
                        spacing: 8
                        Text { text: "Firmware Version:"; color: "#BDC3C7"; font.pixelSize: 14 }
                        Text { text: firmwareVersion; color: "#2ECC71"; font.pixelSize: 14 }
                    }

                    // Soft Reset Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: 10
                        color: enabled ? "#E74C3C" : "#7F8C8D"  // Red when enabled, gray when disabled
                        enabled: MOTIONInterface.consoleConnected

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
                                // console.log("Soft Reset Triggered")
                                MOTIONInterface.softResetSensor("CONSOLE")
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

            // Sensor Left
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

                        Text { text: "Sensor (L)"; font.pixelSize: 16; color: "#BDC3C7" }

                        // Connection LED (changes based on selection)
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: {
                                if (sensorSelector.currentIndex === 0) {
                                    return MOTIONInterface.leftSensorConnected ? "green" : "red"
                                } else {
                                    return MOTIONInterface.rightSensorConnected ? "green" : "red"
                                }
                            }
                            border.color: "black"
                            border.width: 1
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
                            enabled: {
                                if (sensorSelector.currentIndex === 0) {
                                    return MOTIONInterface.leftSensorConnected
                                } else {
                                    return MOTIONInterface.rightSensorConnected
                                }
                            }

                            // Icon Text
                            Text {
                                text: "\u21BB"  // Unicode for the refresh icon
                                anchors.centerIn: parent
                                font.pixelSize: 20
                                font.family: iconFont.name  // Use the loaded custom font
                                color: enabled ? "white" : "#BDC3C7"  // Dim icon text when disabled
                            }

                            MouseArea {
                                id: refreshSensorLeftMouseArea
                                anchors.fill: parent
                                enabled: parent.enabled  // MouseArea also disabled when button is disabled
                                hoverEnabled: true

                                onClicked: {
                                    // console.log("Manual Refresh Triggered")
                                    updateStates();
                                }

                                onEntered: if (parent.enabled) parent.color = "#34495E"  // Highlight only when enabled
                                onExited: parent.color = enabled ? "#2C3E50" : "#7F8C8D"
                            }

                            // Tooltip
                            ToolTip.visible: refreshSensorLeftMouseArea.containsMouse
                            ToolTip.text: "Refresh"
                            ToolTip.delay: 400  // Optional: delay before tooltip shows
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

                    // Soft Reset Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: 10
                        color: enabled ? "#E74C3C" : "#7F8C8D"  // Red when enabled, gray when disabled
                        enabled: {
                                if (sensorSelector.currentIndex === 0) {
                                    return MOTIONInterface.leftSensorConnected
                                } else {
                                    return MOTIONInterface.rightSensorConnected
                                }
                        }
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
                                let sensor_tag = "SENSOR_LEFT";
                                (sensorSelector.currentIndex === 0) ? sensor_tag = "SENSOR_LEFT": sensor_tag = "SENSOR_RIGHT";
                                // console.log("Soft Reset Triggered")
                                MOTIONInterface.softResetSensor(sensor_tag)
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

            // Sensor Right
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

                        Text { text: "Sensor (R)"; font.pixelSize: 16; color: "#BDC3C7" }

                        // Connection LED (changes based on selection)
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: {
                                if (sensorSelector.currentIndex === 0) {
                                    return MOTIONInterface.leftSensorConnected ? "green" : "red"
                                } else {
                                    return MOTIONInterface.rightSensorConnected ? "green" : "red"
                                }
                            }
                            border.color: "black"
                            border.width: 1
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
                            enabled: {
                                if (sensorSelector.currentIndex === 0) {
                                    return MOTIONInterface.leftSensorConnected
                                } else {
                                    return MOTIONInterface.rightSensorConnected
                                }
                            }

                            // Icon Text
                            Text {
                                text: "\u21BB"  // Unicode for the refresh icon
                                anchors.centerIn: parent
                                font.pixelSize: 20
                                font.family: iconFont.name  // Use the loaded custom font
                                color: enabled ? "white" : "#BDC3C7"  // Dim icon text when disabled
                            }

                            MouseArea {
                                id: refreshSensorRightMouseArea
                                anchors.fill: parent
                                enabled: parent.enabled  // MouseArea also disabled when button is disabled
                                hoverEnabled: true

                                onClicked: {
                                    // console.log("Manual Refresh Triggered")
                                    updateStates();
                                }

                                onEntered: if (parent.enabled) parent.color = "#34495E"  // Highlight only when enabled
                                onExited: parent.color = enabled ? "#2C3E50" : "#7F8C8D"
                            }

                            // Tooltip
                            ToolTip.visible: refreshSensorRightMouseArea.containsMouse
                            ToolTip.text: "Refresh"
                            ToolTip.delay: 400  // Optional: delay before tooltip shows
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

                    // Soft Reset Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: 10
                        color: enabled ? "#E74C3C" : "#7F8C8D"  // Red when enabled, gray when disabled
                        enabled: {
                                if (sensorSelector.currentIndex === 0) {
                                    return MOTIONInterface.leftSensorConnected
                                } else {
                                    return MOTIONInterface.rightSensorConnected
                                }
                        }
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
                                let sensor_tag = "SENSOR_LEFT";
                                (sensorSelector.currentIndex === 0) ? sensor_tag = "SENSOR_LEFT": sensor_tag = "SENSOR_RIGHT";
                                // console.log("Soft Reset Triggered")
                                MOTIONInterface.softResetSensor(sensor_tag)
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
