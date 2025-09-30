import QtQuick 6.0
import QtQuick.Controls 6.0
import QtQuick.Layouts 6.0
import OpenMotion 1.0 

import "../components"

Rectangle {
    id: page1
    width: parent.width
    height: parent.height
    color: "#29292B"
    radius: 20
    opacity: 0.95

    // Properties for dynamic data
    property string firmwareVersion: "N/A"
    property string deviceId: "N/A"
    property real sensor_temperature: 0.0
    property real amb_temperature: 0.0
    property int accel_x: 0.0
    property int accel_y: 0.0
    property int accel_z: 0.0
    property int gyro_x: 0.0
    property int gyro_y: 0.0
    property int gyro_z: 0.0

    ListModel {
        id: cameraStatusModel
        ListElement { label: "Camera 1"; status: "Not Tested"; color: "gray" }
        ListElement { label: "Camera 2"; status: "Not Tested"; color: "gray" }
        ListElement { label: "Camera 3"; status: "Not Tested"; color: "gray" }
        ListElement { label: "Camera 4"; status: "Not Tested"; color: "gray" }
        ListElement { label: "Camera 5"; status: "Not Tested"; color: "gray" }
        ListElement { label: "Camera 6"; status: "Not Tested"; color: "gray" }
        ListElement { label: "Camera 7"; status: "Not Tested"; color: "gray" }
        ListElement { label: "Camera 8"; status: "Not Tested"; color: "gray" }
    }

    function updateStates() {
        console.log("Sensor Updating all states...")
        
        let isConnected = (sensorSelector.currentIndex === 0)
            ? MOTIONInterface.leftSensorConnected
            : MOTIONInterface.rightSensorConnected

        if (!isConnected) {
            console.log("Selected sensor is not connected. Skipping update.")
            return
        }

        let sensor_tag = (sensorSelector.currentIndex === 0) ? "SENSOR_LEFT" : "SENSOR_RIGHT";
        console.log("Sensor Updating all states for", sensor_tag);
        
        MOTIONInterface.querySensorInfo(sensor_tag)
        MOTIONInterface.querySensorTemperature(sensor_tag)
        MOTIONInterface.querySensorAccelerometer(sensor_tag)
        //MOTIONInterface.queryTriggerInfo()
    }

    // Run refresh logic immediately on page load if Sensor is already connected
    Component.onCompleted: {
        sensorSelector.currentIndex = 0 // default
        if (MOTIONInterface.leftSensorConnected || MOTIONInterface.rightSensorConnected) {
            console.log("Page Loaded - Sensor Already Connected. Fetching Info...");
            updateStates();
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
        target: MOTIONInterface

        // Handle Sensor Connected state
        function onSensorConnectedChanged() {
            if (MOTIONInterface.leftSensorConnected) {
                infoTimer.start()          // One-time info fetch
            } else {
                console.log("Sensor Disconnected - Clearing Data...")
                firmwareVersion = "N/A"
                deviceId = "N/A"
                sensor_temperature = 0.0
                amb_temperature = 0.0
                
                pingResult.text = ""
                echoResult.text = ""
                toggleLedResult.text = ""
            }
        }

        // Handle device info response
        function onSensorDeviceInfoReceived(fwVersion, devId) {
            firmwareVersion = fwVersion
            deviceId = devId
        }

        // Handle temperature updates
        function onTemperatureSensorUpdated(imu_temp) {
            sensor_temperature = imu_temp
            amb_temperature = 0
        }
 
        function onAccelerometerSensorUpdated(x, y, z) {
            accel_x = x
            accel_y = y
            accel_z = z
        }
 
        function onGyroscopeSensorUpdated(x, y, z) {
            gyro_x = x
            gyro_y = y
            gyro_z = z
        }

        function onCameraConfigUpdated(bitmask, passed) {
            for (let i = 0; i < 8; i++) {
                if ((bitmask & (1 << i)) !== 0) {
                    cameraStatusModel.set(i, {
                        label: "Camera " + (i + 1),
                        status: passed ? "Pass" : "Fail",
                        color: passed ? "green" : "red"
                    });
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Title
        Text {
            text: "Sensor Module Unit Tests"
            font.pixelSize: 20
            font.weight: Font.Bold
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }

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
                        height: 195
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
                            anchors.topMargin: 60    
                            columns: 5
                            rowSpacing: 10
                            columnSpacing: 10

                            // Row 1
                            // Ping Button and Result
                            Button {
                                id: pingButton
                                text: "Ping"
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 50
                                hoverEnabled: true  // Enable hover detection
                                enabled: {
                                    if (sensorSelector.currentIndex === 0) {
                                        return MOTIONInterface.leftSensorConnected
                                    } else {
                                        return MOTIONInterface.rightSensorConnected
                                    }
                                }

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
                                    let sensor_tag = "SENSOR_LEFT";
                                    (sensorSelector.currentIndex === 0) ? sensor_tag = "SENSOR_LEFT": sensor_tag = "SENSOR_RIGHT";
                                    if(MOTIONInterface.sendPingCommand(sensor_tag)){                                        
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
                                Layout.preferredHeight: 50
                                hoverEnabled: true  // Enable hover detection
                                enabled: {
                                    if (sensorSelector.currentIndex === 0) {
                                        return MOTIONInterface.leftSensorConnected
                                    } else {
                                        return MOTIONInterface.rightSensorConnected
                                    }
                                }

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
                                    let sensor_tag = "SENSOR_LEFT";
                                    (sensorSelector.currentIndex === 0) ? sensor_tag = "SENSOR_LEFT": sensor_tag = "SENSOR_RIGHT";
                                    if(MOTIONInterface.sendLedToggleCommand(sensor_tag))
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
                                Layout.preferredHeight: 50
                                hoverEnabled: true  // Enable hover detection
                                enabled: {
                                    if (sensorSelector.currentIndex === 0) {
                                        return MOTIONInterface.leftSensorConnected
                                    } else {
                                        return MOTIONInterface.rightSensorConnected
                                    }
                                }

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
                                    let sensor_tag = "SENSOR_LEFT";
                                    (sensorSelector.currentIndex === 0) ? sensor_tag = "SENSOR_LEFT": sensor_tag = "SENSOR_RIGHT";

                                    if(MOTIONInterface.sendEchoCommand(sensor_tag))
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

                            Item {
                                
                            }
                            

                            Item {
                                
                            }
                        }
                    }
                    
                    // Camera Tests
                    Rectangle {
                        width: 650
                        height: 390
                        radius: 6
                        color: "#1E1E20"
                        border.color: "#3E4E6F"
                        border.width: 2

                        // Title at Top-Center with 5px Spacing
                        Text {
                            text: "Camera Output Tests"
                            color: "#BDC3C7"
                            font.pixelSize: 18
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.topMargin: 5  // 5px spacing from the top
                        }
                        
                        // Content for Camera Tests
                        GridLayout {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.leftMargin: 20
                            anchors.topMargin: 60
                            columns: 5
                            rowSpacing: 10
                            columnSpacing: 10

                            Text {
                                Layout.preferredWidth: 100
                                font.pixelSize: 16
                                text: "Camera Select"
                                color: "#BDC3C7"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ComboBox {
                                id: cameraDropdown
                                Layout.preferredWidth: 200
                                Layout.preferredHeight: 40
                                model: ["Camera 1", "Camera 2", "Camera 3", "Camera 4", "Camera 5", "Camera 6", "Camera 7", "Camera 8", "All Cameras"]
                                currentIndex: 8  // Default to "All Cameras"
                                enabled: {
                                    if (sensorSelector.currentIndex === 0) {
                                        return MOTIONInterface.leftSensorConnected
                                    } else {
                                        return MOTIONInterface.rightSensorConnected
                                    }
                                }

                                onActivated: {
                                    var selectedIndex = cameraDropdown.currentIndex;

                                    // Update frequency and pulse width based on the selected index
                                    switch (selectedIndex) {
                                        case 0: 
                                        case 1: 
                                        case 2: 
                                        case 3: 
                                        case 4: 
                                        case 5: 
                                        case 6: 
                                        case 7:
                                            break; 
                                        default:
                                            console.log("All Cameras");
                                            break;
                                    }

                                }
                            }

                            Item {
                                Layout.preferredWidth: 100
                            }


                            Button {
                                id: testCameraButton
                                text: "Test"
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 50
                                hoverEnabled: true  // Enable hover detection
                                enabled: {
                                    if (sensorSelector.currentIndex === 0) {
                                        return MOTIONInterface.leftSensorConnected
                                    } else {
                                        return MOTIONInterface.rightSensorConnected
                                    }
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "#BDC3C7" : "#7F8C8D"  // Gray out text when disabled
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    id: triggerButtonBackground
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
                                    let selectedIndex = cameraDropdown.currentIndex;
                                    let cameraMask = 0x01 << selectedIndex;

                                    if (selectedIndex === 8) {
                                        cameraMask = 0xFF;  // All Cameras
                                    }
    
                                    let sensor_tag = "SENSOR_LEFT";
                                    (sensorSelector.currentIndex === 0) ? sensor_tag = "SENSOR_LEFT": sensor_tag = "SENSOR_RIGHT";

                                    console.log("Test Camera Mask: " + cameraMask.toString(16));
                                    if(cameraMask == 0xFF){
                                        MOTIONInterface.configureAllCameras(sensor_tag);
                                    }else{
                                        MOTIONInterface.configureCamera(sensor_tag, cameraMask);
                                    }

                                }

                            }

                            

                            // Spacer Row
                            Item {
                                Layout.columnSpan: 5
                                height: 10
                            }

                            // Camera Test Status Table
                            GridLayout {
                                columns: 2
                                columnSpacing: 10
                                rowSpacing: 6
                                Layout.columnSpan: 5

                                // Custom order: row-wise produces [0,7,1,6,2,5,3,4]
                                Repeater {
                                    model: 8
                                    delegate: RowLayout {
                                        spacing: 10
                                        // Map visual position to camera index per desired layout
                                        property int mappedIndex: (
                                            index === 0 ? 0 :
                                            index === 1 ? 7 :
                                            index === 2 ? 1 :
                                            index === 3 ? 6 :
                                            index === 4 ? 2 :
                                            index === 5 ? 5 :
                                            index === 6 ? 3 : 4)

                                        Text {
                                            text: cameraStatusModel.get(mappedIndex).label
                                            font.pixelSize: 14
                                            color: "#BDC3C7"
                                            Layout.preferredWidth: 100
                                        }

                                        Text {
                                            text: cameraStatusModel.get(mappedIndex).status
                                            color: cameraStatusModel.get(mappedIndex).color
                                            font.pixelSize: 14
                                            Layout.preferredWidth: 120
                                        }
                                    }
                                }
                            }

                            // Spacer below table
                            Item {
                                Layout.columnSpan: 5
                                height: 10
                            }

                            // Camera Power Buttons (stacked left, below the list)
                            ColumnLayout {
                                Layout.columnSpan: 5
                                spacing: 8
                                Layout.alignment: Qt.AlignLeft

                                Button {
                                    id: camPowerOnBtn
                                    text: "Power Cameras On"
                                    Layout.preferredWidth: 160
                                    Layout.preferredHeight: 40
                                    hoverEnabled: true
                                    enabled: {
                                        if (sensorSelector.currentIndex === 0) {
                                            return MOTIONInterface.leftSensorConnected
                                        } else {
                                            return MOTIONInterface.rightSensorConnected
                                        }
                                    }
                                    contentItem: Text {
                                        text: parent.text
                                        color: parent.enabled ? "#BDC3C7" : "#7F8C8D"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: {
                                            if (!parent.enabled) {
                                                return "#3A3F4B"
                                            }
                                            return parent.hovered ? "#4A90E2" : "#3A3F4B"
                                        }
                                        radius: 4
                                        border.color: {
                                            if (!parent.enabled) {
                                                return "#7F8C8D"
                                            }
                                            return parent.hovered ? "#FFFFFF" : "#BDC3C7"
                                        }
                                    }
                                    onClicked: {
                                        MOTIONInterface.powerCamerasOn()
                                    }
                                }

                                Button {
                                    id: camPowerOffBtn
                                    text: "Power Cameras Off"
                                    Layout.preferredWidth: 160
                                    Layout.preferredHeight: 40
                                    hoverEnabled: true
                                    enabled: {
                                        if (sensorSelector.currentIndex === 0) {
                                            return MOTIONInterface.leftSensorConnected
                                        } else {
                                            return MOTIONInterface.rightSensorConnected
                                        }
                                    }
                                    contentItem: Text {
                                        text: parent.text
                                        color: parent.enabled ? "#BDC3C7" : "#7F8C8D"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: {
                                            if (!parent.enabled) {
                                                return "#3A3F4B"
                                            }
                                            return parent.hovered ? "#4A90E2" : "#3A3F4B"
                                        }
                                        radius: 4
                                        border.color: {
                                            if (!parent.enabled) {
                                                return "#7F8C8D"
                                            }
                                            return parent.hovered ? "#FFFFFF" : "#BDC3C7"
                                        }
                                    }
                                    onClicked: {
                                        MOTIONInterface.powerCamerasOff()
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

                            // Sensor selection dropdown
                            ComboBox {
                                id: sensorSelector
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 28
                                model: ["Left", "Right"]
                                currentIndex: 0 // Default to Left

                                // Smaller font for the selected text
                                contentItem: Text {
                                    text: sensorSelector.displayText
                                    font.pixelSize: 12     // Change this for smaller text
                                    color: "#BDC3C7"
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }

                                onCurrentIndexChanged: {
                                    console.log("Sensor selection changed to:", currentText)

                                    // Clear status texts
                                    pingResult.text = ""
                                    echoResult.text = ""
                                    toggleLedResult.text = ""

                                    // Clear sensor data
                                    firmwareVersion = "N/A"
                                    deviceId = "N/A"
                                    sensor_temperature = 0.0
                                    amb_temperature = 0.0
                                    accel_x = accel_y = accel_z = 0
                                    gyro_x = gyro_y = gyro_z = 0

                                    // Reset camera test table
                                    for (let i = 0; i < cameraStatusModel.count; i++) {
                                        cameraStatusModel.set(i, {
                                            label: "Camera " + (i + 1),
                                            status: "Not Tested",
                                            color: "gray"
                                        });
                                    }

                                    // Fetch new sensor states
                                    updateStates()
                                }
                            }

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
                                    id: refreshMouseArea
                                    anchors.fill: parent
                                    enabled: parent.enabled  // MouseArea also disabled when button is disabled
                                    hoverEnabled: true

                                    onClicked: {
                                        console.log("Manual Refresh Triggered")
                                        updateStates();
                                    }

                                    onEntered: if (parent.enabled) parent.color = "#34495E"  // Highlight only when enabled
                                    onExited: parent.color = enabled ? "#2C3E50" : "#7F8C8D"
                                }

                                // Tooltip
                                ToolTip.visible: refreshMouseArea.containsMouse
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


                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter 
                            spacing: 25  

                            // TEMP Widget
                            TemperatureWidget {
                                id: tempWidget1
                                temperature: sensor_temperature
                                tempName: "Sensor Temperature"
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // IMU Widget
                            IMUWidget {
                                mode: "Accel"
                                imuLabel: "IMU Data"
                                xVal: accel_x
                                yVal: accel_y
                                zVal: accel_z
                            }
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
                                    console.log("Soft Reset Triggered")
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

    FontLoader {
        id: iconFont
        source: "../assets/fonts/keenicons-outline.ttf"
    }
}
