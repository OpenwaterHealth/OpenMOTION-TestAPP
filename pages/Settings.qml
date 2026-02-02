import QtQuick 6.0
import QtQuick.Controls 6.0
import QtQuick.Layouts 6.0
import OpenMotion 1.0

Rectangle {
    id: page1
    width: parent.width
    height: parent.height
    color: "#29292B" // Background color for Page 1
    radius: 20
    opacity: 0.95 // Slight transparency for the content area

    // Minimal device/app info for the Settings overview page
    property string consoleFirmwareVersion: "N/A"
    property string consoleDeviceId: "N/A"
    property string consoleBoardRevId: "N/A"

    // Latest firmware info from remote
    property string consoleLatestFirmware: "N/A"
    property string consoleLatestFirmwareDate: ""
    property var consoleReleasesModel: []
    property int consoleLatestIndex: 0

    property string leftSensorFirmwareVersion: "N/A"
    property string leftSensorDeviceId: "N/A"
    property string rightSensorFirmwareVersion: "N/A"
    property string rightSensorDeviceId: "N/A"

    function refreshConsoleInfo() {
        if (MOTIONInterface.consoleConnected)
            MOTIONInterface.queryConsoleInfo()
            MOTIONInterface.queryConsoleLatestVersionInfo()
    }

    function refreshSensorInfo(target) {
        if (target === "SENSOR_LEFT" && MOTIONInterface.leftSensorConnected)
            MOTIONInterface.querySensorInfo(target)
        if (target === "SENSOR_RIGHT" && MOTIONInterface.rightSensorConnected)
            MOTIONInterface.querySensorInfo(target)
    }

    Connections {
        target: MOTIONInterface

        function _clearConsoleInfo() {
            consoleFirmwareVersion = "N/A"
            consoleDeviceId = "N/A"
            consoleBoardRevId = "N/A"
        }

        function _clearLeftSensorInfo() {
            leftSensorFirmwareVersion = "N/A"
            leftSensorDeviceId = "N/A"
        }

        function _clearRightSensorInfo() {
            rightSensorFirmwareVersion = "N/A"
            rightSensorDeviceId = "N/A"
        }

        // Mirrors Sensor.qml/Console.qml behavior: on any connection change, clear disconnected
        // fields immediately and query device info for connected modules.
        function onConnectionStatusChanged() {
            if (!MOTIONInterface.consoleConnected)
                _clearConsoleInfo()
            if (!MOTIONInterface.leftSensorConnected)
                _clearLeftSensorInfo()
            if (!MOTIONInterface.rightSensorConnected)
                _clearRightSensorInfo()

            if (MOTIONInterface.consoleConnected || MOTIONInterface.leftSensorConnected || MOTIONInterface.rightSensorConnected) {
                settingsInfoTimer.restart()
                if (MOTIONInterface.consoleConnected)
                    MOTIONInterface.queryConsoleLatestVersionInfo()
            } else {
                settingsInfoTimer.stop()
            }
        }

        function onConsoleDeviceInfoReceived(fwVersion, devId, boardId) {
            consoleFirmwareVersion = fwVersion
            consoleDeviceId = devId
            consoleBoardRevId = boardId
        }

        function onLatestVersionInfoReceived(info) {
            if (!info) return
            // Expecting structure: { latest: { tag_name, published_at }, releases: { tag: { published_at, prerelease } }}
            try {
                if (info.latest && info.latest.tag_name) {
                    consoleLatestFirmware = info.latest.tag_name
                    consoleLatestFirmwareDate = info.latest.published_at || ""
                } else {
                    consoleLatestFirmware = "N/A"
                    consoleLatestFirmwareDate = ""
                }

                var names = []
                for (var k in info.releases) {
                    names.push(k)
                }
                // Sort by published_at descending
                names.sort(function(a,b){
                    var da = new Date(info.releases[a].published_at).getTime()
                    var db = new Date(info.releases[b].published_at).getTime()
                    return db - da
                })
                consoleReleasesModel = names
                var idx = consoleReleasesModel.indexOf(consoleLatestFirmware)
                consoleLatestIndex = idx >= 0 ? idx : 0
            } catch (e) {
                console.log('Error parsing latest version info', e)
            }
        }

        // Newer signal (preferred): includes target so Settings can show both L/R.
        function onSensorDeviceInfoReceivedEx(target, fwVersion, devId) {
            if (target === "SENSOR_LEFT") {
                leftSensorFirmwareVersion = fwVersion
                leftSensorDeviceId = devId
            } else if (target === "SENSOR_RIGHT") {
                rightSensorFirmwareVersion = fwVersion
                rightSensorDeviceId = devId
            }
        }
    }

    // Small delay after connect to let the device stabilize (matches pattern in other pages)
    Timer {
        id: settingsInfoTimer
        interval: 1500
        repeat: false
        onTriggered: {
            refreshConsoleInfo()
            refreshSensorInfo("SENSOR_LEFT")
            refreshSensorInfo("SENSOR_RIGHT")
        }
    }

    Component.onCompleted: {
        // Populate immediately if user navigates here while already connected
        if (MOTIONInterface.consoleConnected || MOTIONInterface.leftSensorConnected || MOTIONInterface.rightSensorConnected)
            settingsInfoTimer.start()
    }

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

        // Remaining content area (split into App Info top, Modules bottom)
        Item {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: appInfoContainer
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * 0.33
                color: "#1E1E20"
                radius: 10
                border.color: "#3E4E6F"
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    Text {
                        text: "Application"
                        color: "#BDC3C7"
                        font.pixelSize: 16
                        font.bold: true
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 6

                        Text { text: "App Version:"; color: "#BDC3C7"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 120 }
                        Text { text: "v" + appVersion; color: "#3498DB"; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }

                        Text { text: "SDK Version:"; color: "#BDC3C7"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 120 }
                        Text { text: "v" + MOTIONInterface.get_sdk_version(); color: "#3498DB"; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }

                        Text { text: "System State:"; color: "#BDC3C7"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 120 }
                        Text {
                            text: {
                                const c = MOTIONInterface.consoleConnected
                                const l = MOTIONInterface.leftSensorConnected
                                const r = MOTIONInterface.rightSensorConnected
                                if (c && l && r) return "Connected"
                                if (!c && !l && !r) return "Disconnected"
                                return "Partially Connected"
                            }
                            color: "#BDC3C7"
                            font.pixelSize: 14
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            Item {
                id: modulesArea
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.top: appInfoContainer.bottom
                anchors.topMargin: 15

                RowLayout {
                    id: modulesRow
                    anchors.fill: parent
                    spacing: 20

                    // Console
                    Rectangle {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.preferredWidth: modulesRow.width / 3
                        color: "#1E1E20"
                        radius: 10
                        border.color: "#3E4E6F"
                        border.width: 2

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            RowLayout {
                                spacing: 8
                                Layout.fillWidth: true

                                Text { text: "Console"; font.pixelSize: 16; color: "#BDC3C7" }
                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: MOTIONInterface.consoleConnected ? "green" : "red"
                                    border.color: "black"
                                    border.width: 1
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: enabled ? "#2C3E50" : "#7F8C8D"
                                    enabled: MOTIONInterface.consoleConnected

                                    Text {
                                        text: "\u21BB"
                                        anchors.centerIn: parent
                                        font.pixelSize: 20
                                        font.family: iconFont.name
                                        color: enabled ? "white" : "#BDC3C7"
                                    }

                                    MouseArea {
                                        id: refreshConsoleMouseArea
                                        anchors.fill: parent
                                        enabled: parent.enabled
                                        hoverEnabled: true
                                        onClicked: refreshConsoleInfo()
                                        onEntered: if (parent.enabled) parent.color = "#34495E"
                                        onExited: parent.color = parent.enabled ? "#2C3E50" : "#7F8C8D"
                                    }

                                    ToolTip.visible: refreshConsoleMouseArea.containsMouse
                                    ToolTip.text: "Refresh"
                                    ToolTip.delay: 400
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 2; color: "#3E4E6F" }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 10
                                rowSpacing: 6

                                Text { text: "Device ID:"; color: "#BDC3C7"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 120 }
                                Text { text: consoleDeviceId; color: "#3498DB"; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }

                                Text { text: "Board Rev ID:"; color: "#BDC3C7"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 120 }
                                Text { text: consoleBoardRevId; color: "#3498DB"; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }

                                Text { text: "Firmware:"; color: "#BDC3C7"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 120 }
                                Text { text: consoleFirmwareVersion; color: "#2ECC71"; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }

                                Text { text: "Latest Release:"; color: "#BDC3C7"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 120 }
                                Text { text: consoleLatestFirmware; color: "#3498DB"; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }

                                Text { text: "Published:"; color: "#BDC3C7"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 120 }
                                Text { text: consoleLatestFirmwareDate; color: "#3498DB"; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }

                                Text { text: "Select Release:"; color: "#BDC3C7"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 120 }
                                ComboBox {
                                    id: consoleLatestCombo
                                    model: consoleReleasesModel
                                    currentIndex: consoleLatestIndex
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    enabled: MOTIONInterface.consoleConnected && consoleReleasesModel.length > 0
                                    onCurrentIndexChanged: consoleLatestIndex = currentIndex
                                }
                            }

                            Item { Layout.fillHeight: true }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 40
                                radius: 10
                                color: enabled ? "#E74C3C" : "#7F8C8D"
                                enabled: MOTIONInterface.consoleConnected
                                    && consoleFirmwareVersion !== "N/A"
                                    && consoleDeviceId !== "N/A"
                                    && consoleBoardRevId !== "N/A"

                                Text {
                                    text: "Update Firmware"
                                    anchors.centerIn: parent
                                    color: parent.enabled ? "white" : "#BDC3C7"
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: parent.enabled
                                    onClicked: MOTIONInterface.softResetSensor("CONSOLE")
                                    onEntered: if (parent.enabled) parent.color = "#C0392B"
                                    onExited: if (parent.enabled) parent.color = "#E74C3C"
                                }

                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }
                    }

                    // Sensor Left
                    Rectangle {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.preferredWidth: modulesRow.width / 3
                        color: "#1E1E20"
                        radius: 10
                        border.color: "#3E4E6F"
                        border.width: 2

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            RowLayout {
                                spacing: 8
                                Layout.fillWidth: true

                                Text { text: "Sensor (L)"; font.pixelSize: 16; color: "#BDC3C7" }
                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: MOTIONInterface.leftSensorConnected ? "green" : "red"
                                    border.color: "black"
                                    border.width: 1
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: enabled ? "#2C3E50" : "#7F8C8D"
                                    enabled: MOTIONInterface.leftSensorConnected

                                    Text {
                                        text: "\u21BB"
                                        anchors.centerIn: parent
                                        font.pixelSize: 20
                                        font.family: iconFont.name
                                        color: enabled ? "white" : "#BDC3C7"
                                    }

                                    MouseArea {
                                        id: refreshSensorLeftMouseArea
                                        anchors.fill: parent
                                        enabled: parent.enabled
                                        hoverEnabled: true
                                        onClicked: refreshSensorInfo("SENSOR_LEFT")
                                        onEntered: if (parent.enabled) parent.color = "#34495E"
                                        onExited: parent.color = parent.enabled ? "#2C3E50" : "#7F8C8D"
                                    }

                                    ToolTip.visible: refreshSensorLeftMouseArea.containsMouse
                                    ToolTip.text: "Refresh"
                                    ToolTip.delay: 400
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 2; color: "#3E4E6F" }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 10
                                rowSpacing: 6

                                Text { text: "Device ID:"; color: "#BDC3C7"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 120 }
                                Text { text: leftSensorDeviceId; color: "#3498DB"; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }

                                Text { text: "Firmware:"; color: "#BDC3C7"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 120 }
                                Text { text: leftSensorFirmwareVersion; color: "#2ECC71"; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                            }

                            Item { Layout.fillHeight: true }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 40
                                radius: 10
                                color: enabled ? "#E74C3C" : "#7F8C8D"
                                enabled: MOTIONInterface.leftSensorConnected
                                    && leftSensorFirmwareVersion !== "N/A"
                                    && leftSensorDeviceId !== "N/A"

                                Text {
                                    text: "Update Firmware"
                                    anchors.centerIn: parent
                                    color: parent.enabled ? "white" : "#BDC3C7"
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: parent.enabled
                                    onClicked: MOTIONInterface.softResetSensor("SENSOR_LEFT")
                                    onEntered: if (parent.enabled) parent.color = "#C0392B"
                                    onExited: if (parent.enabled) parent.color = "#E74C3C"
                                }

                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }
                    }

                    // Sensor Right
                    Rectangle {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.preferredWidth: modulesRow.width / 3
                        color: "#1E1E20"
                        radius: 10
                        border.color: "#3E4E6F"
                        border.width: 2

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            RowLayout {
                                spacing: 8
                                Layout.fillWidth: true

                                Text { text: "Sensor (R)"; font.pixelSize: 16; color: "#BDC3C7" }
                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: MOTIONInterface.rightSensorConnected ? "green" : "red"
                                    border.color: "black"
                                    border.width: 1
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: enabled ? "#2C3E50" : "#7F8C8D"
                                    enabled: MOTIONInterface.rightSensorConnected

                                    Text {
                                        text: "\u21BB"
                                        anchors.centerIn: parent
                                        font.pixelSize: 20
                                        font.family: iconFont.name
                                        color: enabled ? "white" : "#BDC3C7"
                                    }

                                    MouseArea {
                                        id: refreshSensorRightMouseArea
                                        anchors.fill: parent
                                        enabled: parent.enabled
                                        hoverEnabled: true
                                        onClicked: refreshSensorInfo("SENSOR_RIGHT")
                                        onEntered: if (parent.enabled) parent.color = "#34495E"
                                        onExited: parent.color = parent.enabled ? "#2C3E50" : "#7F8C8D"
                                    }

                                    ToolTip.visible: refreshSensorRightMouseArea.containsMouse
                                    ToolTip.text: "Refresh"
                                    ToolTip.delay: 400
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 2; color: "#3E4E6F" }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 10
                                rowSpacing: 6

                                Text { text: "Device ID:"; color: "#BDC3C7"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 120 }
                                Text { text: rightSensorDeviceId; color: "#3498DB"; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }

                                Text { text: "Firmware:"; color: "#BDC3C7"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 120 }
                                Text { text: rightSensorFirmwareVersion; color: "#2ECC71"; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                            }

                            Item { Layout.fillHeight: true }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 40
                                radius: 10
                                color: enabled ? "#E74C3C" : "#7F8C8D"
                                enabled: MOTIONInterface.rightSensorConnected
                                    && rightSensorFirmwareVersion !== "N/A"
                                    && rightSensorDeviceId !== "N/A"

                                Text {
                                    text: "Update Firmware"
                                    anchors.centerIn: parent
                                    color: parent.enabled ? "white" : "#BDC3C7"
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: parent.enabled
                                    onClicked: MOTIONInterface.softResetSensor("SENSOR_RIGHT")
                                    onEntered: if (parent.enabled) parent.color = "#C0392B"
                                    onExited: if (parent.enabled) parent.color = "#E74C3C"
                                }

                                Behavior on color { ColorAnimation { duration: 200 } }
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
