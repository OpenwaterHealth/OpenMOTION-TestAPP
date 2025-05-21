from PyQt6.QtCore import QObject, pyqtSignal, pyqtProperty, pyqtSlot, QVariant
from typing import List
import logging
import base58

from omotion.Interface import MOTIONInterface

logger = logging.getLogger(__name__)

# Define system states
DISCONNECTED = 0
SENSOR_CONNECTED = 1
CONSOLE_CONNECTED = 2
READY = 3
RUNNING = 4

class MOTIONConnector(QObject):
    # Ensure signals are correctly defined
    signalConnected = pyqtSignal(str, str)  # (descriptor, port)
    signalDisconnected = pyqtSignal(str, str)  # (descriptor, port)
    signalDataReceived = pyqtSignal(str, str)  # (descriptor, data)

    consoleDeviceInfoReceived = pyqtSignal(str, str)  
    sensorDeviceInfoReceived = pyqtSignal(str, str)
    temperatureSensorUpdated = pyqtSignal(float)  # (imu_temp)
    accelerometerSensorUpdated = pyqtSignal(int, int, int) # (imu_accel)
    gyroscopeSensorUpdated = pyqtSignal(int, int, int)  # (imu_accel)

    cameraConfigUpdated = pyqtSignal(int, bool)  # camera_mask, passed=True/False

    triggerStateChanged = pyqtSignal(bool)  # 🔹 New signal for trigger state change

    connectionStatusChanged = pyqtSignal()  # 🔹 New signal for connection updates

    stateChanged = pyqtSignal()  # Notifies QML when state changes
    rgbStateReceived = pyqtSignal(int, str)  # Emit both integer value and text
    fanSpeedsReceived = pyqtSignal(int)  # Emit both integers
    
    def __init__(self):
        super().__init__()
        self.interface = MOTIONInterface(run_async=True)

        self._sensorConnected = False
        self._consoleConnected = False
        self._running = False
        self._state = DISCONNECTED

        self.connect_signals()

    def connect_signals(self):
        """Connect LIFUInterface signals to QML."""
        self.interface.signal_connect.connect(self.on_connected)
        self.interface.signal_disconnect.connect(self.on_disconnected)
        self.interface.signal_data_received.connect(self.on_data_received)


    def update_state(self):
        """Update system state based on connection and configuration."""
        if not self._consoleConnected and not self._sensorConnected:
            self._state = DISCONNECTED
        elif self._sensorConnected and not self._consoleConnected:
            self._state = SENSOR_CONNECTED
        elif self._consoleConnected and not self._sensorConnected:
            self._state = CONSOLE_CONNECTED
        elif self._consoleConnected and self._sensorConnected:
            self._state = READY
        elif self._consoleConnected and self._sensorConnected and self._running:
            self._state = RUNNING
        self.stateChanged.emit()  # Notify QML of state update
        logger.info(f"Updated state: {self._state}")
        
    @pyqtSlot()
    async def start_monitoring(self):
        """Start monitoring for device connection asynchronously."""
        try:
            logger.info("Starting device monitoring...")
            await self.interface.start_monitoring()
        except Exception as e:
            logger.error(f"Error in start_monitoring: {e}", exc_info=True)

    @pyqtSlot()
    def stop_monitoring(self):
        """Stop monitoring device connection."""
        try:
            logger.info("Stopping device monitoring...")
            self.interface.stop_monitoring()
        except Exception as e:
            logger.error(f"Error while stopping monitoring: {e}", exc_info=True)

    @pyqtSlot(str, str)
    def on_connected(self, descriptor, port):
        """Handle device connection."""
        if descriptor.upper() == "SENSOR":
            self._sensorConnected = True
        elif descriptor.upper() == "CONSOLE":
            self._consoleConnected = True
        self.signalConnected.emit(descriptor, port)
        self.connectionStatusChanged.emit() 
        self.update_state()

    @pyqtSlot(str, str)
    def on_disconnected(self, descriptor, port):
        """Handle device disconnection."""
        if descriptor.upper() == "SENSOR":
            self._sensorConnected = False
        elif descriptor.upper() == "CONSOLE":
            self._consoleConnected = False
        self.signalDisconnected.emit(descriptor, port)
        self.connectionStatusChanged.emit() 
        self.update_state()
    
    @pyqtSlot(str, str)
    def on_data_received(self, descriptor, message):
        """Handle incoming data from the LIFU device."""
        logger.info(f"Data received from {descriptor}: {message}")
        self.signalDataReceived.emit(descriptor, message)

    @pyqtSlot()
    def querySensorInfo(self):
        """Fetch and emit device information."""
        try:
            fw_version = self.interface.sensor_module.get_version()
            logger.info(f"Version: {fw_version}")
            hw_id = self.interface.sensor_module.get_hardware_id()
            device_id = base58.b58encode(bytes.fromhex(hw_id)).decode()
            self.sensorDeviceInfoReceived.emit(fw_version, device_id)
            logger.info(f"Sensor Device Info - Firmware: {fw_version}, Device ID: {device_id}")
        except Exception as e:
            logger.error(f"Error querying device info: {e}")

    @pyqtSlot()
    def queryConsoleInfo(self):
        """Fetch and emit device information."""
        try:
            fw_version = self.interface.console_module.get_version()
            logger.info(f"Version: {fw_version}")
            hw_id = self.interface.console_module.get_hardware_id()
            device_id = base58.b58encode(bytes.fromhex(hw_id)).decode()
            self.consoleDeviceInfoReceived.emit(fw_version, device_id)
            logger.info(f"Console Device Info - Firmware: {fw_version}, Device ID: {device_id}")
        except Exception as e:
            logger.error(f"Error querying device info: {e}")

    @pyqtSlot()
    def querySensorTemperature(self):
        """Fetch and emit Temperature data."""
        try:
            imu_temp = self.interface.sensor_module.imu_get_temperature()  
            logger.info(f"Temperature Data - IMU Temp: {imu_temp}")
            self.temperatureSensorUpdated.emit(imu_temp)
        except Exception as e:
            logger.error(f"Error querying Temperature data: {e}")

    @pyqtSlot(int)
    def setRGBState(self, state):
        """Set the RGB state using integer values."""
        try:
            valid_states = [0, 1, 2, 3]
            if state not in valid_states:
                logger.error(f"Invalid RGB state value: {state}")
                return

            if self.interface.console_module.set_rgb_led(state) == state:
                logger.info(f"RGB state set to: {state}")
            else:
                logger.error(f"Failed to set RGB state to: {state}")
        except Exception as e:
            logger.error(f"Error setting RGB state: {e}")

    @pyqtSlot()
    def queryRGBState(self):
        """Fetch and emit RGB state."""
        try:
            state = self.interface.console_module.get_rgb_led()
            state_text = {0: "Off", 1: "IND1", 2: "IND2", 3: "IND3"}.get(state, "Unknown")

            logger.info(f"RGB State: {state_text}")
            self.rgbStateReceived.emit(state, state_text)  # Emit both values
        except Exception as e:
            logger.error(f"Error querying RGB state: {e}")

    @pyqtSlot()
    def queryFans(self):
        """Fetch and emit Fan Speed."""
        try:
            fan_speed = self.interface.console_module.get_fan_speed()

            logger.info(f"Fan Speed: {fan_speed}")
            self.fanSpeedsReceived.emit(fan_speed)  # Emit both values
        except Exception as e:
            logger.error(f"Error querying Fan Speeds: {e}")

    @pyqtSlot()
    def querySensorAccelerometer (self):
        """Fetch and emit Accelerometer data."""
        try:
            accel = self.interface.sensor_module.imu_get_accelerometer()
            logger.info(f"Accel (raw): X={accel[0]}, Y={accel[1]}, Z={accel[2]}")
            self.accelerometerSensorUpdated.emit(accel[0], accel[1], accel[2])
        except Exception as e:
            logger.error(f"Error querying Accelerometer data: {e}")

    @pyqtSlot()
    def querySensorGyroscope (self):
        """Fetch and emit Gyroscope data."""
        try:
            gyro  = self.interface.sensor_module.imu_get_gyroscope()
            logger.info(f"Gyro  (raw): X={gyro[0]}, Y={gyro[1]}, Z={gyro[2]}")
            self.gyroscopeSensorUpdated.emit(gyro[0], gyro[1], gyro[2])
        except Exception as e:
            logger.error(f"Error querying Gyroscope data: {e}")

    @pyqtSlot(int)
    def configureCamera(self, cam_mask: int):
        try:
            passed = self.interface.sensor_module.program_fpga(camera_position=cam_mask, manual_process=False)
            self.cameraConfigUpdated.emit(cam_mask, passed)
        except Exception as e:
            logger.error(f"Error configuring Camera {cam_mask}: {e}")
            self.cameraConfigUpdated.emit(cam_mask, False)
        
    @pyqtSlot()
    def configureAllCameras(self):
        for i in range(8):
            bitmask = 1 << i  # 0x01, 0x02, 0x04, ..., 0x80
            try:
                passed = self.interface.sensor_module.program_fpga(camera_position=bitmask, manual_process=False)
                self.cameraConfigUpdated.emit(bitmask, passed)
            except Exception as e:
                logger.error(f"Camera {bitmask} failed: {e}")
                self.cameraConfigUpdated.emit(bitmask, False)

    @pyqtSlot(str, result=bool)
    def sendPingCommand(self, target: str):
        """Send a ping command to HV device."""
        try:
            if target == "CONSOLE":
                if self.interface.console_module.ping():
                    logger.info(f"Ping command sent successfully")
                    return True
                else:
                    logger.error(f"Failed to send ping command")
                    return False
            elif target == "SENSOR":
                if self.interface.sensor_module.ping():
                    logger.info(f"Ping command sent successfully")
                    return True
                else:
                    logger.error(f"Failed to send ping command")
                    return False
            else:
                logger.error(f"Invalid target for ping command")
                return False
        except Exception as e:
            logger.error(f"Error sending ping command: {e}")
            return False
        
    @pyqtSlot(str, result=bool)
    def sendLedToggleCommand(self, target: str):
        """Send a LED Toggle command to device."""
        try:
            if target == "CONSOLE":
                if self.interface.console_module.toggle_led():
                    logger.info(f"Toggle command sent successfully")
                    return True
                else:
                    logger.error(f"Failed to Toggle command")
                    return False
            elif target == "SENSOR":
                if self.interface.sensor_module.toggle_led():
                    logger.info(f"Toggle command sent successfully")
                    return True
                else:
                    logger.error(f"Failed to send Toggle command")
                    return False
            else:
                logger.error(f"Invalid target for Toggle command")
                return False
        except Exception as e:
            logger.error(f"Error sending Toggle command: {e}")
            return False
        
    @pyqtSlot(str, result=bool)
    def sendEchoCommand(self, target: str):
        """Send Echo command to device."""
        try:
            expected_data = b"Hello FROM Test Application!"
            if target == "CONSOLE":
                echoed_data, data_len = self.interface.console_module.echo(echo_data=expected_data)
            elif target == "SENSOR":
                echoed_data, data_len = self.interface.sensor_module.echo(echo_data=expected_data)
            else:
                logger.error(f"Invalid target for Echo command")
                return False

            if echoed_data == expected_data and data_len == len(expected_data):
                logger.info(f"Echo command successful - Data matched")
                return True
            else:
                logger.error(f"Echo command failed - Data mismatch")
                return False
            
        except Exception as e:
            logger.error(f"Error sending Echo command: {e}")
            return False
        
    @pyqtSlot(str, int, int, int, int, int, result=QVariant)
    def i2cReadBytes(self, target: str, mux_idx: int, channel: int, i2c_addr: int, offset: int, data_len: int):
        """Send i2c read to device"""
        try:
            print(
                f"I2C Read Request -> target={target}, mux_idx={mux_idx}, channel={channel}, "
                f"i2c_addr=0x{int(i2c_addr):02X}, offset=0x{int(offset):02X}, read_len={int(data_len)}"
            )            

            if target == "CONSOLE":                
                fpga_data, fpga_data_len = self.interface.console_module.read_i2c_packet(mux_index=mux_idx, channel=channel, device_addr=i2c_addr, reg_addr=offset, read_len=data_len)
                if fpga_data is None or fpga_data_len == 0:
                    logger.error(f"Read I2C Failed")
                    return []
                else:
                    logger.info(f"Read I2C Success")
                    logger.info(f"Raw bytes: {fpga_data.hex(' ')}")  # Print as hex bytes separated by spaces
                    return list(fpga_data[:fpga_data_len]) 
                
            elif target == "SENSOR":
                logger.info(f"I2C Read Not Implemented")
                return []
        except Exception as e:
            logger.error(f"Error sending i2c read command: {e}")
            return []
        
    @pyqtSlot(str, int, int, int, int, list, result=bool)
    def i2cWriteBytes(self, target: str, mux_idx: int, channel: int, i2c_addr: int, offset: int, data: list[int]) -> bool:
        """Send i2c write to device"""
        try:
            print(
                f"I2C Write Request -> target={target}, mux_idx={mux_idx}, channel={channel}, "
                f"i2c_addr=0x{int(i2c_addr):02X}, offset=0x{int(offset):02X}, data={[f'0x{int(b):02X}' for b in data]}"
            )            

            sanitized_data = []
            for b in data:
                try:
                    value = int(b) & 0xFF  # convert to int and clip to byte
                    sanitized_data.append(value)
                except Exception as e:
                    logger.error(f"Invalid byte value: {b} ({e})")
                    return False

            byte_data = bytes(sanitized_data)

            if target == "CONSOLE":
                if self.interface.console_module.write_i2c_packet(mux_index=mux_idx, channel=channel, device_addr=i2c_addr, reg_addr=offset, data=byte_data):
                    logger.info(f"Write I2C Success")
                    return True
                else:
                    logger.error(f"Write I2C Failed")
                    return False
            elif target == "SENSOR":
                logger.info(f"I2C Write Not Implemented")
                return True
        except Exception as e:
            logger.error(f"Error sending i2c write command: {e}")
            return False
        
    @pyqtSlot(str)
    def softResetSensor(self, target: str):
        """reset hardware Sensor device."""
        try:
            
            if target == "CONSOLE":
                if self.interface.console_module.soft_reset():
                    logger.info(f"Software Reset Sent")
                else:
                    logger.error(f"Failed to send Software Reset")
            elif target == "SENSOR":                    
                if self.interface.sensor_module.soft_reset():
                    logger.info(f"Software Reset Sent")
                else:
                    logger.error(f"Failed to send Software Reset")
        except Exception as e:
            logger.error(f"Error Sending Software Reset: {e}")
    
    @pyqtSlot(int, int, result='QStringList')
    def scanI2C(self, mux: int, chan: int) -> list[str]:
        addresses = self.interface.console_module.scan_i2c_mux_channel(mux, chan)
        hex_addresses = [hex(addr) for addr in addresses]
        print(f"Devices found on MUX {mux} channel {chan}: {hex_addresses}")
        return hex_addresses

    @pyqtSlot(int, result=bool)
    def setFanLevel(self, speed: int):
        """Set Fan Level to device."""
        try:
            
            if self.interface.console_module.set_fan_speed(fan_speed=speed) == speed:
                logger.info(f"Fan set successfully")
                return True
            else:   
                logger.error(f"Failed to set Fan Speed")
                return False    
                        
        except Exception as e:
            logger.error(f"Error setting Fan Speed: {e}")
            return False
        
    @pyqtProperty(bool, notify=connectionStatusChanged)
    def sensorConnected(self):
        """Expose Sensor connection status to QML."""
        return self._sensorConnected

    @pyqtProperty(bool, notify=connectionStatusChanged)
    def consoleConnected(self):
        """Expose Console connection status to QML."""
        return self._consoleConnected

    @pyqtProperty(int, notify=stateChanged)
    def state(self):
        """Expose state as a QML property."""
        return self._state
        
    @pyqtProperty(str, constant=True)
    def sdkVersion(self) -> str:
        """Expose SDK version as a constant QML property."""
        return MOTIONInterface.get_sdk_version()