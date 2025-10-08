from PyQt6.QtCore import QObject, pyqtSignal, pyqtProperty, pyqtSlot, QVariant, QThread, QWaitCondition, QMutex, QMutexLocker
from typing import List
import logging
import base58
import json
import csv
import os
import datetime
import time

from motion_singleton import motion_interface  

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)  # or INFO depending on what you want to see

# Create console handler
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)  # Show all messages on console

# Optional: set a formatter
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
console_handler.setFormatter(formatter)

# Add handler to the logger (only if not already added)
if not logger.hasHandlers():
    logger.addHandler(console_handler)

# Define system states
DISCONNECTED = 0
SENSOR_CONNECTED  = 1
CONSOLE_CONNECTED = 2
READY = 3
RUNNING = 4

class CaptureThread(QThread):
    new_histogram = pyqtSignal(list)  # Signal for histogram data
    update_status = pyqtSignal(str)  # Signal for status updates
    

    def __init__(self, camera_index, fps=5, parent=None):
        super().__init__(parent)
        self.camera_index = camera_index
        self.running = False
        self.frame_delay = 1.0 / fps

    def run(self):
        if self.camera_index == 9:
            CAMERA_MASK = 0xFF  # All cameras
        else:    
            CAMERA_MASK = 1 << (self.camera_index - 1)
        status_map = motion_interface.sensors["left"].get_camera_status(CAMERA_MASK)
        if not status_map:
            logger.error("Failed to get camera status map.")
            return None
        
        for cam_idx in range(8):
            if CAMERA_MASK & (1 << cam_idx):
                status = status_map.get(cam_idx)
                if status is None:
                    logger.error(f"Camera {cam_idx + 1} missing in status map.")
                    return None

                if not status & (1 << 0):  # Not READY
                    logger.error(f"Camera {cam_idx + 1} is not ready.")
                    return None

                if not (status & (1 << 1) and status & (1 << 2)):  # Not programmed
                    self.update_status.emit(f"prog {cam_idx + 1}")
                    logger.debug(f"FPGA configuration started for camera {cam_idx + 1}")
                    start_time = time.time()

                    if not motion_interface.sensors["left"].program_fpga(camera_position=(1 << cam_idx), manual_process=False):
                        logger.error(f"Failed to program FPGA for camera {cam_idx + 1}")
                        return None
                    logger.debug(f"FPGA programmed for camera {cam_idx + 1} | Time: {(time.time() - start_time) * 1000:.2f} ms")

                if not (status & (1 << 1) and status & (1 << 3)):  # Not configured
                    self.update_status.emit(f"conf {cam_idx + 1}")
                    logger.debug(f"Configuring registers for camera {cam_idx + 1}")
                    if not motion_interface.sensors["left"].camera_configure_registers(1 << cam_idx):
                        logger.error(f"Failed to configure registers for camera {cam_idx + 1}")
                        return None
                
        logger.debug("Setting test pattern...")
        self.update_status.emit(f"set live")
        if not motion_interface.sensors["left"].camera_configure_test_pattern(CAMERA_MASK, 0x04):
            logger.error("Failed to set test pattern.")
            return None
        
        # Get status
        status_map = motion_interface.sensors["left"].get_camera_status(CAMERA_MASK)
        if not status_map:
            logger.error("Failed to get camera status.")
            return None

        for cam_idx in range(8):
            if CAMERA_MASK & (1 << cam_idx):
                status = status_map.get(cam_idx)

                if status is None:
                    logger.error(f"Camera {cam_idx + 1} missing in status map.")
                    return None
                logger.debug(f"Camera {self.camera_index} status: 0x{status:02X} → {motion_interface.sensors["left"].decode_camera_status(status)}")

                if not (status & (1 << 0) and status & (1 << 1) and status & (1 << 2)):  # Not ready for histo
                    logger.error("Not configured.")
                    return None

        self.running = True
        while self.running:
            start_time = time.time()
            try:
                logger.debug("Capturing histogram...")
                if not motion_interface.sensors["left"].camera_capture_histogram(CAMERA_MASK):
                    logger.error("Capture failed.")
                else:                    
                    logger.debug("Capture successful, retrieving histogram...")                    
                    time.sleep(0.005)  # Wait for capture to complete
                    histogram = motion_interface.sensors["left"].camera_get_histogram(CAMERA_MASK)
                    if histogram is None:
                        logger.error("Histogram retrieval failed.")
                    else:
                        logger.debug("Histogram frame received successfully.")
                        histogram = histogram[:4096]  # Ensure we only take the first 4096 bins
                        bins, histo =  motion_interface.bytes_to_integers(histogram)
                        if bins:
                            self.new_histogram.emit(bins)
                            continue # Continue to next frame

                self.new_histogram.emit([])  # Emit empty on failure
            except Exception as e:
                logger.error(f"Error in capture thread: {e}")
                self.new_histogram.emit([])

            elapsed = time.time() - start_time
            if elapsed < self.frame_delay:
                time.sleep(self.frame_delay - elapsed)

    def stop(self):
        self.running = False
        self.wait(500)

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
    histogramCaptureCompleted = pyqtSignal(int, float)  # (camera_index, weighted_mean)
    cameraPowerStatusUpdated = pyqtSignal(list)  # (power_status_list)
    csvOutputDirectoryChanged = pyqtSignal(str)  # (directory_path)

    triggerStateChanged = pyqtSignal(str)  # 🔹 New signal for trigger state change

    connectionStatusChanged = pyqtSignal()  # 🔹 New signal for connection updates

    laserStateChanged = pyqtSignal(bool)  # 🔹 New signal for laser state change
    safetyFailureStateChanged = pyqtSignal(bool)  # 🔹 New signal for safety failure state chang
    
    isStreamingChanged = pyqtSignal()

    stateChanged = pyqtSignal()  # Notifies QML when state changes
    rgbStateReceived = pyqtSignal(int, str)  # Emit both integer value and text
    fanSpeedsReceived = pyqtSignal(int)  # Emit both integers
    
    histogramReady = pyqtSignal(list)  # Emit 1024 bins to QML
    updateCapStatus = pyqtSignal(str) 

    tcmChanged = pyqtSignal()
    tclChanged = pyqtSignal()
    pdcChanged = pyqtSignal()

    def __init__(self):
        super().__init__()
        self._interface = motion_interface
        
        # Initialize CSV output directory to user's home directory
        import os
        self._csv_output_directory = os.path.expanduser("~")

        # Check if console and sensor are connected
        console_connected, left_sensor_connected, right_sensor_connected = motion_interface.is_device_connected()

        self._leftSensorConnected = left_sensor_connected
        self._rightSensorConnected = right_sensor_connected
        self._consoleConnected = console_connected
        self._laserOn = False
        self._safetyFailure = False
        self._running = False
        self._trigger_state = "OFF"
        self._state = DISCONNECTED
        self._i2c_mutex = QMutex()
        self._is_streaming = False
        self._capture_thread = None
        self._console_status_thread = None
        self._tcm = 0.0
        self._tcl = 0.0
        self._pdc = 0.0

        self.connect_signals()

    def connect_signals(self):
        """Connect LIFUInterface signals to QML."""
        motion_interface.signal_connect.connect(self.on_connected)
        motion_interface.signal_disconnect.connect(self.on_disconnected)
        motion_interface.signal_data_received.connect(self.on_data_received)

    @pyqtProperty(str, notify=csvOutputDirectoryChanged)
    def csvOutputDirectory(self):
        """Get the current CSV output directory."""
        return self._csv_output_directory

    @csvOutputDirectory.setter
    def csvOutputDirectory(self, directory):
        """Set the CSV output directory."""
        if directory != self._csv_output_directory:
            self._csv_output_directory = directory
            self.csvOutputDirectoryChanged.emit(directory)
            logger.info(f"CSV output directory changed to: {directory}")

    @pyqtSlot()
    def selectCsvOutputDirectory(self):
        """Signal QML to open directory selection dialog."""
        # Emit signal to trigger QML folder dialog
        self.csvOutputDirectoryChanged.emit("SELECT_DIRECTORY")

    @pyqtSlot(str)
    def setCsvOutputDirectory(self, directory):
        """Set the CSV output directory from QML."""
        if directory and directory != "SELECT_DIRECTORY":
            self.csvOutputDirectory = directory

    def update_state(self):
        """Update system state based on connection and configuration."""
        if not self._consoleConnected and ((not self._leftSensorConnected) or (not self._rightSensorConnected)):
            self._state = DISCONNECTED
        elif self._leftSensorConnected and not self._consoleConnected:
            self._state = SENSOR_CONNECTED
        elif self._consoleConnected and not self._leftSensorConnected:
            self._state = CONSOLE_CONNECTED
        elif self._consoleConnected and self._leftSensorConnected:
            self._state = READY
        elif self._consoleConnected and self._leftSensorConnected and self._running:
            self._state = RUNNING
        self.stateChanged.emit()  # Notify QML of state update
        logger.info(f"Updated state: {self._state}")
        


    @property
    def interface(self):
        return motion_interface
    
    @pyqtProperty(bool, notify=connectionStatusChanged)
    def leftSensorConnected(self):
        """Expose Sensor connection status to QML."""
        return self._leftSensorConnected

    @pyqtProperty(bool, notify=connectionStatusChanged)
    def rightSensorConnected(self):
        """Expose Sensor connection status to QML."""
        return self._rightSensorConnected
    
    @pyqtProperty(bool, notify=connectionStatusChanged)
    def consoleConnected(self):
        """Expose Console connection status to QML."""
        return self._consoleConnected

    @pyqtProperty(bool, notify=laserStateChanged)
    def laserOn(self):
        """Expose Console connection status to QML."""
        return self._laserOn
    
    @pyqtProperty(bool, notify=safetyFailureStateChanged)
    def safetyFailure(self):
        """Expose Console connection status to QML."""
        return self._safetyFailure

    @pyqtProperty(int, notify=stateChanged)
    def state(self):
        """Expose state as a QML property."""
        return self._state
            
    @pyqtProperty(float, notify=tcmChanged)
    def tcm(self):
        return self._tcm

    @pyqtProperty(float, notify=tclChanged)
    def tcl(self):
        return self._tcl

    @pyqtProperty(float, notify=pdcChanged)
    def pdc(self):
        return self._pdc

    @pyqtProperty(bool, notify=isStreamingChanged)
    def isStreaming(self):
        return self._is_streaming
    
    @pyqtProperty(str, notify=triggerStateChanged)
    def triggerState(self):
        return self._trigger_state

    @pyqtSlot(result=str)
    def get_sdk_version(self):
        return self._interface.get_sdk_version()
    
    @pyqtSlot(str)
    def powerCamerasOn(self, target: str):
        """Enable power to all cameras on all connected sensors (equivalent to scripts/enable_camera_power.py --mask 0xFF)."""
        try:
            MASK_ALL = 0xFF
            logger.info(f"Enabling camera power mask=0x{MASK_ALL:02X} on {target.capitalize()}")

            ok = motion_interface.sensors[target].enable_camera_power(MASK_ALL)
            if ok:
                logger.info(f"{target.capitalize()}: Power enabled")
            else:
                logger.error(f"{target.capitalize()}: Failed to enable power")
        except Exception as e:
            logger.error(f"Error enabling camera power: {e}")


    @pyqtSlot(str)
    def powerCamerasOff(self, target: str):
        """Disable power to all cameras on all connected sensors (equivalent to scripts/disable_camera_power.py --mask 0xFF)."""
        try:
            MASK_ALL = 0xFF
            logger.info(f"Disabling camera power mask=0x{MASK_ALL:02X} on {target.capitalize()}")

            ok = motion_interface.sensors[target].disable_camera_power(MASK_ALL)
            if ok:
                logger.info(f"{target.capitalize()}: Power disabled")
            else:
                logger.error(f"{target.capitalize()}: Failed to disable power")
        except Exception as e:
            logger.error(f"Error disabling camera power: {e}")


    @pyqtSlot(str, int, str, bool)
    def captureHistogramToCSV(self, sensor_tag: str, camera_index: int, serial_number: str, is_dark: bool = False):
        """Capture histogram from selected camera and save as CSV file named with serial number."""
        try:
            # Convert sensor tag to lowercase for interface
            sensor_side = "left" if sensor_tag == "SENSOR_LEFT" else "right"
            capture_type = "dark histogram" if is_dark else "histogram"
            logger.info(f"Capturing {capture_type} for {sensor_side} camera {camera_index} with SN {serial_number}")
            
            # Single camera
            bins, histo = self._interface.get_camera_histogram(
                sensor_side=sensor_side,
                camera_id=camera_index,
                test_pattern_id=4,
                auto_upload=True
            )
            if bins:
                suffix = "_dark" if is_dark else ""
                filename = f"{serial_number}_histogram{suffix}.csv"
                
                # Get camera temperature
                try:
                    temperature = self._interface.sensors[sensor_side].imu_get_temperature()
                    logger.info(f"Camera temperature: {temperature}°C")
                except Exception as e:
                    logger.error(f"Failed to get camera temperature: {e}")
                    temperature = 0.0  # Fallback to 0 if temperature retrieval fails
                
                # Calculate weighted mean
                weighted_mean = self._calculate_weighted_mean(bins[:1024])
                print(f"Weighted mean of histogram: {weighted_mean:.2f}")
                
                self._save_histogram_csv(bins, filename, temperature)
                logger.info(f"Saved {capture_type} to {filename}")
                
                # Emit signal with weighted mean
                self.histogramCaptureCompleted.emit(camera_index, weighted_mean)
            else:
                logger.error(f"Failed to get {capture_type} for camera {camera_index+1}")
                    
        except Exception as e:
            logger.error(f"Error capturing {capture_type}: {e}")

    @pyqtSlot(str, bool)
    def captureAllCamerasHistogramToCSV(self, sensor_tag: str, is_dark: bool = False):
        """Capture histogram from all cameras and save each with individual serial numbers."""
        try:
            # Convert sensor tag to lowercase for interface
            sensor_side = "left" if sensor_tag == "SENSOR_LEFT" else "right"
            capture_type = "dark histograms" if is_dark else "histograms"
            logger.info(f"Capturing {capture_type} for all cameras on {sensor_side}")
            
            # Map camera indices to their display order (same as in QML)
            camera_mapping = [0, 7, 1, 6, 2, 5, 3, 4]  # Left column: 1,2,3,4; Right column: 8,7,6,5
            
            for display_idx, camera_idx in enumerate(camera_mapping):
                try:
                    bins, histo = self._interface.get_camera_histogram(
                        sensor_side=sensor_side,
                        camera_id=camera_idx,
                        test_pattern_id=4,
                        auto_upload=True
                    )
                    if bins:
                        # Use camera number (1-based) as serial number
                        # Note: We can't access QML properties from Python, so we use camera numbers
                        # The QML should handle getting the actual serial numbers for individual cameras
                        serial_number = str(camera_idx + 1)
                        suffix = "_dark" if is_dark else ""
                        filename = f"{serial_number}_histogram{suffix}.csv"
                        
                        # Get camera temperature
                        try:
                            temperature = self._interface.sensors[sensor_side].imu_get_temperature()
                            logger.info(f"Camera {camera_idx+1} temperature: {temperature}°C")
                        except Exception as e:
                            logger.error(f"Failed to get temperature for camera {camera_idx+1}: {e}")
                            temperature = 0.0  # Fallback to 0 if temperature retrieval fails
                        
                        # Calculate weighted mean
                        weighted_mean = self._calculate_weighted_mean(bins[:1024])
                        print(f"Weighted mean of histogram for camera {camera_idx+1}: {weighted_mean:.2f}")
                        
                        self._save_histogram_csv(bins, filename, temperature)
                        logger.info(f"Saved {capture_type} for camera {camera_idx+1} to {filename}")
                        
                        # Emit signal with weighted mean
                        self.histogramCaptureCompleted.emit(camera_idx, weighted_mean)
                    else:
                        logger.error(f"Failed to get {capture_type} for camera {camera_idx+1}")
                except Exception as e:
                    logger.error(f"Error capturing {capture_type} for camera {camera_idx+1}: {e}")
                    
        except Exception as e:
            logger.error(f"Error capturing all cameras {capture_type}: {e}")

    def _save_histogram_csv(self, bins, filename, temperature=0.0):
        """Helper method to save histogram data to CSV file."""
        try:
            import os
            import csv
            import datetime
            
            # Create filename with timestamp if serial_number is empty
            if not filename or filename.startswith("_histogram"):
                timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"histogram_{timestamp}.csv"
            
            # Ensure filename has .csv extension
            if not filename.endswith('.csv'):
                filename += '.csv'
            
            # Calculate weighted mean of histogram data
            weighted_mean = self._calculate_weighted_mean(bins[:1024])
            print(f"Weighted mean of histogram: {weighted_mean:.2f}")
            
            # Save to configured CSV output directory
            filepath = os.path.join(self._csv_output_directory, filename)
            
            with open(filepath, 'w', newline='') as csvfile:
                writer = csv.writer(csvfile)
                
                # Create header row with column names
                header = ["cam_id", "frame_id"]
                # Add bin numbers (0-1023)
                header.extend([str(i) for i in range(1024)])
                header.extend(["temperature", "sum"])
                writer.writerow(header)
                
                # Create data row
                data_row = ["1", "1"]  # cam_id=1, frame_id=1
                data_row.extend(bins[:1024])  # Ensure we only take first 1024 bins
                # Pad with zeros if bins is shorter than 1024
                while len(data_row) < 1026:  # 2 + 1024
                    data_row.append(0)
                # Add temperature and sum
                data_row.extend([temperature, sum(bins[:1024])])
                writer.writerow(data_row)
            
            logger.info(f"Histogram saved to {filepath}")
            
        except Exception as e:
            logger.error(f"Failed to save histogram CSV: {e}")

    def _calculate_weighted_mean(self, histogram_data):
        """Calculate the weighted mean of histogram data."""
        try:
            if not histogram_data or len(histogram_data) == 0:
                return 0.0
            
            # Calculate weighted mean: sum(bin_value * bin_index) / sum(bin_values)
            weighted_sum = 0.0
            total_count = 0.0
            
            for bin_index, bin_value in enumerate(histogram_data):
                weighted_sum += bin_value * bin_index
                total_count += bin_value
            
            if total_count == 0:
                return 0.0
            
            return weighted_sum / total_count
            
        except Exception as e:
            logger.error(f"Error calculating weighted mean: {e}")
            return 0.0
    
    @pyqtSlot(str, str)
    def on_connected(self, descriptor, port):
        """Handle device connection."""
        print(f"Device connected: {descriptor} on port {port}")
        if descriptor.upper() == "SENSOR_LEFT":
            self._leftSensorConnected = True
        if descriptor.upper() == "SENSOR_RIGHT":
            self._rightSensorConnected = True
        elif descriptor.upper() == "CONSOLE":
            self._consoleConnected = True

        self.signalConnected.emit(descriptor, port)
        self.connectionStatusChanged.emit() 
        self.update_state()

    @pyqtSlot(str, str)
    def on_disconnected(self, descriptor, port):
        """Handle device disconnection."""
        if descriptor.upper() == "SENSOR_LEFT":
            self._leftSensorConnected = False
        elif descriptor.upper() == "SENSOR_RIGHT":
            self._rightSensorConnected = False
        elif descriptor.upper() == "CONSOLE":
            self._consoleConnected = False

            # Stop status thread
            if self._console_status_thread:
                self._console_status_thread.stop()
                self._console_status_thread = None

        self.signalDisconnected.emit(descriptor, port)
        self.connectionStatusChanged.emit() 
        self.update_state()
    
    @pyqtSlot(str, str)
    def on_data_received(self, descriptor, message):
        """Handle incoming data from the LIFU device."""
        logger.info(f"Data received from {descriptor}: {message}")
        self.signalDataReceived.emit(descriptor, message)

    @pyqtSlot(str)
    def querySensorInfo(self, target: str):
        """Fetch and emit device information."""
        try:
            if target == "SENSOR_LEFT" or target == "SENSOR_RIGHT":                
                sensor_tag = "left" if target == "SENSOR_LEFT" else "right"
            else:
                logger.error(f"Invalid target for sensor info query: {target}")
                return
            fw_version = motion_interface.sensors[sensor_tag].get_version()
            logger.info(f"Version: {fw_version}")
            hw_id = motion_interface.sensors[sensor_tag].get_hardware_id()
            device_id = base58.b58encode(bytes.fromhex(hw_id)).decode()
            self.sensorDeviceInfoReceived.emit(fw_version, device_id)
            logger.info(f"Sensor Device Info - Firmware: {fw_version}, Device ID: {device_id}")
        except Exception as e:
            logger.error(f"Error querying device info: {e}")

    @pyqtSlot()
    def queryConsoleInfo(self):
        """Fetch and emit device information."""
        try:
            fw_version = motion_interface.console_module.get_version()
            logger.info(f"Version: {fw_version}")
            hw_id = motion_interface.console_module.get_hardware_id()
            device_id = base58.b58encode(bytes.fromhex(hw_id)).decode()
            self.consoleDeviceInfoReceived.emit(fw_version, device_id)
            logger.info(f"Console Device Info - Firmware: {fw_version}, Device ID: {device_id}")
        except Exception as e:
            logger.error(f"Error querying device info: {e}")

    @pyqtSlot(str)
    def querySensorTemperature(self, target: str):
        """Fetch and emit Temperature data."""
        try:
            if target == "SENSOR_LEFT" or target == "SENSOR_RIGHT":                
                sensor_tag = "left" if target == "SENSOR_LEFT" else "right"
            else:
                logger.error(f"Invalid target for sensor info query: {target}")
                return
            imu_temp = motion_interface.sensors[sensor_tag].imu_get_temperature()  
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

            if motion_interface.console_module.set_rgb_led(state) == state:
                logger.info(f"RGB state set to: {state}")
            else:
                logger.error(f"Failed to set RGB state to: {state}")
        except Exception as e:
            logger.error(f"Error setting RGB state: {e}")

    @pyqtSlot()
    def queryRGBState(self):
        """Fetch and emit RGB state."""
        try:
            state = motion_interface.console_module.get_rgb_led()
            state_text = {0: "Off", 1: "IND1", 2: "IND2", 3: "IND3"}.get(state, "Unknown")

            logger.info(f"RGB State: {state_text}")
            self.rgbStateReceived.emit(state, state_text)  # Emit both values
        except Exception as e:
            logger.error(f"Error querying RGB state: {e}")

    @pyqtSlot()
    def queryFans(self):
        """Fetch and emit Fan Speed."""
        try:
            fan_speed = motion_interface.console_module.get_fan_speed()

            logger.info(f"Fan Speed: {fan_speed}")
            self.fanSpeedsReceived.emit(fan_speed)  # Emit both values
        except Exception as e:
            logger.error(f"Error querying Fan Speeds: {e}")

    @pyqtSlot(result=QVariant)
    def queryTriggerConfig(self):
        trigger_setting = motion_interface.console_module.get_trigger_json()
        if trigger_setting:
            if isinstance(trigger_setting, str):
                updateTrigger = json.loads(trigger_setting)
            else:
                updateTrigger = trigger_setting
            if updateTrigger["TriggerStatus"] == 2:               
                self._trigger_state = "ON"
                self.triggerStateChanged.emit("ON")            
                return trigger_setting or {}
       
        self._trigger_state = "OFF"
        self.triggerStateChanged.emit("OFF")
                
        return trigger_setting or {}
    
    @pyqtSlot(str, result=bool)
    def setTrigger(self, triggerjson):
        try:
            json_trigger_data = json.loads(triggerjson)
            
            trigger_setting = motion_interface.console_module.set_trigger_json(data=json_trigger_data)
            if trigger_setting:
                logger.info(f"Trigger Setting: {trigger_setting}")
                return True
            else:
                logger.error("Failed to set trigger setting.")
                return False

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse JSON data: {e}")
            return False

        except AttributeError as e:
            logger.error(f"Invalid interface or method: {e}")
            return False

        except Exception as e:
            logger.error(f"Unexpected error while setting trigger: {e}")
            return False
            
    @pyqtSlot(result=bool)
    def startTrigger(self):
        success = motion_interface.console_module.start_trigger()
        if success:

            # Start status thread
            if self._console_status_thread is None:
                self._console_status_thread = ConsoleStatusThread(self)
                self._console_status_thread.statusUpdate.connect(self.handleUpdateCapStatus)  # Or define a dedicated signal
                self._console_status_thread.start()

            self._trigger_state = "ON"
            self.triggerStateChanged.emit("ON")
        return success
        
    @pyqtSlot()
    def stopTrigger(self):
        motion_interface.console_module.stop_trigger()
        self._trigger_state = "OFF"
        self.triggerStateChanged.emit("OFF")        
        
        if self._console_status_thread:
            self._console_status_thread.stop()
            self._console_status_thread = None
    
    @pyqtSlot(str)
    def querySensorAccelerometer (self, target: str):
        """Fetch and emit Accelerometer data."""
        try:
            if target == "SENSOR_LEFT" or target == "SENSOR_RIGHT":                
                sensor_tag = "left" if target == "SENSOR_LEFT" else "right"
            else:
                logger.error(f"Invalid target for sensor info query: {target}")
                return
            accel = motion_interface.sensors[sensor_tag].imu_get_accelerometer()
            logger.info(f"Accel (raw): X={accel[0]}, Y={accel[1]}, Z={accel[2]}")
            self.accelerometerSensorUpdated.emit(accel[0], accel[1], accel[2])
        except Exception as e:
            logger.error(f"Error querying Accelerometer data: {e}")

    @pyqtSlot()
    def querySensorGyroscope (self):
        """Fetch and emit Gyroscope data."""
        try:
            gyro  = motion_interface.sensors["left"].imu_get_gyroscope()
            logger.info(f"Gyro  (raw): X={gyro[0]}, Y={gyro[1]}, Z={gyro[2]}")
            self.gyroscopeSensorUpdated.emit(gyro[0], gyro[1], gyro[2])
        except Exception as e:
            logger.error(f"Error querying Gyroscope data: {e}")

    @pyqtSlot(str, int)
    def configureCamera(self, target:str, cam_mask: int):
        try:
            if target == "SENSOR_LEFT" or target == "SENSOR_RIGHT":
                sensor_tag = "left" if target == "SENSOR_LEFT" else "right"
            else:
                logger.erro
            passed = motion_interface.sensors[sensor_tag].program_fpga(camera_position=cam_mask, manual_process=False)
            gain = 16
            exposure = 600
            print(f"Switching camera to {cam_mask}")
            passed_sw = motion_interface.sensors[sensor_tag].switch_camera(cam_mask)
            print(f"Setting gain to {gain}")
            passed_gain= motion_interface.sensors[sensor_tag].camera_set_gain(gain)
            print(f"Setting exposure to {exposure}")
            passed_exposure = motion_interface.sensors[sensor_tag].camera_set_exposure(0,us=exposure)
            print(f"Camera {sensor_tag} with mask {cam_mask} configured with gain {gain} and exposure {exposure}")
            self.cameraConfigUpdated.emit(cam_mask, passed)
        except Exception as e:
            logger.error(f"Error configuring Camera {cam_mask}: {e}")
            self.cameraConfigUpdated.emit(cam_mask, False)
        
    @pyqtSlot(str)
    def configureAllCameras(self, target: str):
        for i in range(8):
            bitmask = 1 << i  # 0x01, 0x02, 0x04, ..., 0x80
            try:
                if target == "SENSOR_LEFT" or target == "SENSOR_RIGHT":
                    sensor_tag = "left" if target == "SENSOR_LEFT" else "right"
                else:
                    logger.error(f"Invalid target for camera configuration: {target}")
                    return
                passed = motion_interface.sensors[sensor_tag].program_fpga(camera_position=bitmask, manual_process=False)
                self.cameraConfigUpdated.emit(bitmask, passed)
            except Exception as e:
                logger.error(f"Camera {bitmask} failed: {e}")
                self.cameraConfigUpdated.emit(bitmask, False)

    @pyqtSlot(str, result=bool)
    def sendPingCommand(self, target: str):
        """Send a ping command to HV device."""
        try:
            if target == "CONSOLE":
                if motion_interface.console_module.ping():
                    logger.info(f"Ping command sent successfully")
                    return True
                else:
                    logger.error(f"Failed to send ping command")
                    return False
            elif target == "SENSOR_LEFT" or target == "SENSOR_RIGHT":                
                sensor_tag = "left" if target == "SENSOR_LEFT" else "right"
                if motion_interface.sensors[sensor_tag].ping():
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
                if motion_interface.console_module.toggle_led():
                    logger.info(f"Toggle command sent successfully")
                    return True
                else:
                    logger.error(f"Failed to Toggle command")
                    return False
            elif target == "SENSOR_LEFT" or target == "SENSOR_RIGHT":
                sensor_tag = "left" if target == "SENSOR_LEFT" else "right"
                if motion_interface.sensors[sensor_tag].toggle_led():
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
                echoed_data, data_len = motion_interface.console_module.echo(echo_data=expected_data)
            elif target == "SENSOR_LEFT" or target == "SENSOR_RIGHT":
                sensor_tag = "left" if target == "SENSOR_LEFT" else "right"
                echoed_data, data_len = motion_interface.sensors[sensor_tag].echo(echo_data=expected_data)
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
        
    @pyqtSlot(result=int)
    def getFsyncCount(self):
        """Get the Fsync count from the console."""
        try:
            fsync_count = motion_interface.console_module.get_fsync_pulsecount()
            logger.info(f"Fsync Count: {fsync_count}")
            return fsync_count
        except Exception as e:
            logger.error(f"Error getting Fsync count: {e}")
            return -1
        
    @pyqtSlot(result=int)
    def getLsyncCount(self):
        """Get the Fsync count from the console."""
        try:
            lsync_count = motion_interface.console_module.get_lsync_pulsecount()
            logger.info(f"Lsync Count: {lsync_count}")
            return lsync_count
        except Exception as e:
            logger.error(f"Error getting Lsync count: {e}")
            return -1
        
    @pyqtSlot(str, int, int, int, int, int, result=QVariant)
    def i2cReadBytes(self, target: str, mux_idx: int, channel: int, i2c_addr: int, offset: int, data_len: int):
        """Send i2c read to device"""
        locker = QMutexLocker(self._i2c_mutex)  # Lock auto-released at function exit
        try:
            logger.info(f"I2C Read Request -> target={target}, mux_idx={mux_idx}, channel={channel}, "
                f"i2c_addr=0x{int(i2c_addr):02X}, offset=0x{int(offset):02X}, read_len={int(data_len)}"
            )            

            if target == "CONSOLE":                
                fpga_data, fpga_data_len = motion_interface.console_module.read_i2c_packet(mux_index=mux_idx, channel=channel, device_addr=i2c_addr, reg_addr=offset, read_len=data_len)
                if fpga_data is None or fpga_data_len == 0:
                    logger.error(f"Read I2C Failed")
                    return []
                else:
                    logger.info(f"Read I2C Success")
                    logger.info(f"Raw bytes: {fpga_data.hex(' ')}")  # Print as hex bytes separated by spaces
                    return list(fpga_data[:fpga_data_len]) 
                
            elif target == "SENSOR_LEFT" or target == "SENSOR_RIGHT":
                logger.error(f"I2C Read Not Implemented")
                return []
        except Exception as e:
            logger.error(f"Error sending i2c read command: {e}")
            return []
        
    @pyqtSlot(str, int, int, int, int, list, result=bool)
    def i2cWriteBytes(self, target: str, mux_idx: int, channel: int, i2c_addr: int, offset: int, data: list[int]) -> bool:
        """Send i2c write to device"""
        locker = QMutexLocker(self._i2c_mutex)  # Lock auto-released at function exit
        try:
            logger.info(
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
                if motion_interface.console_module.write_i2c_packet(mux_index=mux_idx, channel=channel, device_addr=i2c_addr, reg_addr=offset, data=byte_data):
                    logger.info(f"Write I2C Success")
                    return True
                else:
                    logger.error(f"Write I2C Failed")
                    return False
            elif target == "SENSOR_LEFT" or target == "SENSOR_RIGHT":
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
                if motion_interface.console_module.soft_reset():
                    logger.info(f"Software Reset Sent")
                else:
                    logger.error(f"Failed to send Software Reset")
            elif target == "SENSOR_LEFT" or target == "SENSOR_RIGHT":
                sensor_tag = "left" if target == "SENSOR_LEFT" else "right"                    
                if motion_interface.sensors[sensor_tag].soft_reset():
                    logger.info(f"Software Reset Sent")
                else:
                    logger.error(f"Failed to send Software Reset")
        except Exception as e:
            logger.error(f"Error Sending Software Reset: {e}")
    
    @pyqtSlot(int, int, result='QStringList')
    def scanI2C(self, mux: int, chan: int) -> list[str]:
        addresses = motion_interface.console_module.scan_i2c_mux_channel(mux, chan)
        hex_addresses = [hex(addr) for addr in addresses]
        logger.info(f"Devices found on MUX {mux} channel {chan}: {hex_addresses}")
        return hex_addresses

    @pyqtSlot(result=bool)
    def getTecEnabled(self) -> bool:
        tec_enabled = motion_interface.console_module.get_tec_enabled()
        logger.info(f"TEC Enabled: {tec_enabled}")
        return tec_enabled

    @pyqtSlot(int, result=bool)
    def setFanLevel(self, speed: int):
        """Set Fan Level to device."""
        try:
            
            if motion_interface.console_module.set_fan_speed(fan_speed=speed) == speed:
                logger.info(f"Fan set successfully")
                return True
            else:   
                logger.error(f"Failed to set Fan Speed")
                return False    
                        
        except Exception as e:
            logger.error(f"Error setting Fan Speed: {e}")
            return False
    
    @pyqtSlot("QVariantList")
    def saveHistogramToCSV(self, data):
        try:
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            path = os.path.expanduser(f"~/histogram_{timestamp}.csv")
            with open(path, 'w', newline='') as csvfile:
                writer = csv.writer(csvfile)
                writer.writerow(["Bin", "Value"])
                for i, value in enumerate(data):
                    writer.writerow([i, value])
            logger.info(f"Histogram saved to {path}")
        except Exception as e:
            logger.error(f"Failed to save histogram: {e}")

    @pyqtSlot(list)
    def on_new_histogram(self, bins):
        if bins:
            self.histogramReady.emit(bins)
        else:
            logger.error("Capture thread failed to retrieve histogram.")
            self.histogramReady.emit([])  # Emit empty to clear

    @pyqtSlot(str)
    def handleUpdateCapStatus(self, status: str):
        """Update the capture status."""
        logger.info(f"Capture Status: {status}")
        self.updateCapStatus.emit(status)

    @pyqtSlot(int)
    def startCameraStream(self, camera_index: int):
        logger.info(f"Starting camera stream for camera {camera_index + 1}")
        logger.error("Camera streaming is not implemented yet.")
        # if self._capture_thread is None or not self._capture_thread.isRunning():
        #     self._capture_thread = CaptureThread(camera_index)
        #     self._capture_thread.new_histogram.connect(self.on_new_histogram)
        #     self._capture_thread.update_status.connect(self.handleUpdateCapStatus)
        #     self._capture_thread.start()
        #     self._is_streaming = True
        #     self.isStreamingChanged.emit()
        
    @pyqtSlot(int)
    def stopCameraStream(self, cam_num):
        logger.error("Camera streaming is not implemented yet.")
        # if self._is_streaming and self._capture_thread:
        #     logger.info(f"Stopping camera stream for cam {cam_num}")
        #     self._capture_thread.stop()
        #     self._capture_thread = None
        #     self._is_streaming = False
        #     self.isStreamingChanged.emit()

    @pyqtSlot(str, int, int)
    def getCameraHistogram(self, target:str, camera_index: int, test_pattern_id: int = 4):
        logger.info(f"Getting histogram for camera {camera_index + 1}")
        bins, histo = motion_interface.get_camera_histogram(
            sensor_side = target,
            camera_id=camera_index,
            test_pattern_id=test_pattern_id,
            auto_upload=True
        )

        if bins:
            self.histogramReady.emit(bins)
        else:
            logger.error("Failed to retrieve histogram.")
            self.histogramReady.emit([])  # Emit empty to clear

    @pyqtSlot()
    def readSafetyStatus(self):
        # Replace this with your actual console status check
        try:
            muxIdx = 1
            i2cAddr = 0x41
            offset = 0x24  
            data_len = 1  # Number of bytes to read

            channels = {
                "SE": 6,
                "SO": 7
            }
            statuses = {}

            for label, channel in channels.items():
                status = self.i2cReadBytes("CONSOLE", muxIdx, channel, i2cAddr, offset, data_len)
                if status:
                    statuses[label] = status[0]                
                else:
                    raise Exception("I2C read error")
                
            status_text = f"SE: 0x{statuses['SE']:02X}, SO: 0x{statuses['SO']:02X}"
            
            if (statuses["SE"] & 0x0F) == 0 and (statuses["SO"] & 0x0F) == 0:
                if self._safetyFailure:
                    self._safetyFailure = False
                    self.safetyFailureStateChanged.emit(False)
            else:
                if not self._safetyFailure:
                    self._safetyFailure = True
                    self.stopTrigger()
                    self.laserStateChanged.emit(False)
                    self.safetyFailureStateChanged.emit(True)  
                    logging.error(f"Failure Detected: {status_text}")

            # Emit combined status if needed
            
            logging.info(f"Status QUERY: {status_text}")

        except Exception as e:
            logging.error(f"Console status query failed: {e}")

    @pyqtSlot(str)
    def queryCameraPowerStatus(self, target: str):
        """Query camera power status for all cameras on the specified sensor."""
        try:
            if target == "SENSOR_LEFT" or target == "SENSOR_RIGHT":
                sensor_tag = "left" if target == "SENSOR_LEFT" else "right"
            else:
                logger.error(f"Invalid target for camera power status query: {target}")
                self.cameraPowerStatusUpdated.emit([False] * 8)
                return
                
            logger.info(f"Querying camera power status for {sensor_tag} sensor")
            
            # Query power status for all cameras
            sensor = motion_interface.sensors[sensor_tag]
            power_status = sensor.get_camera_power_status()
            
            if power_status is not None:
                # Convert to list of booleans for QML
                power_status_list = list(power_status)
                logger.info(f"Camera power status: {power_status_list}")
                logger.info(f"Power status list type: {type(power_status_list)}, length: {len(power_status_list)}")
                
                # Emit signal to update UI
                self.cameraPowerStatusUpdated.emit(power_status_list)
            else:
                logger.error("Failed to retrieve camera power status")
                # Emit empty status (all False)
                self.cameraPowerStatusUpdated.emit([False] * 8)
                
        except Exception as e:
            logger.error(f"Error querying camera power status: {e}")
            # Emit empty status (all False) on error
            self.cameraPowerStatusUpdated.emit([False] * 8)
                
    @pyqtSlot()
    def shutdown(self):
        logger.info("Shutting down MOTIONConnector...")

        if self._capture_thread:
            self._capture_thread.stop()
            self._capture_thread = None
        
        if self._console_status_thread:
            self._console_status_thread.stop()
            self._console_status_thread = None

class ConsoleStatusThread(QThread):
    statusUpdate = pyqtSignal(str)

    def __init__(self, connector: MOTIONConnector, parent=None):
        super().__init__(parent)
        self.connector = connector  # Reference to MOTIONConnector
        self._running = True
        self._mutex = QMutex()
        self._wait_condition = QWaitCondition()
        # self._count = 0  # Initialize count for status updates

    def run(self):
        
        while self._running:
            try:
                # Replace this with your actual console status check
                muxIdx = 1
                i2cAddr = 0x41
                offset = 0x24  
                data_len = 1  # Number of bytes to read

                channels = {
                    "SE": 6,
                    "SO": 7
                }
                statuses = {}

                for label, channel in channels.items():
                    status = self.connector.i2cReadBytes("CONSOLE", muxIdx, channel, i2cAddr, offset, data_len)
                    if status:
                        statuses[label] = status[0]                
                    else:
                        self.statusUpdate.emit(f"{label} Disconnected")
                        raise Exception("I2C read error")

                # if self._count>4 :    
                #     statuses["SE"] = 0x0F  # Trip safety error

                status_text = f"SE: 0x{statuses['SE']:02X}, SO: 0x{statuses['SO']:02X}"
                
                if (statuses["SE"] & 0x0F) == 0 and (statuses["SO"] & 0x0F) == 0:
                    if self.connector._safetyFailure:
                        self.connector._safetyFailure = False
                        self.connector.safetyFailureStateChanged.emit(False)
                else:
                    if not self.connector._safetyFailure:
                        self.connector._safetyFailure = True
                        self.connector.stopTrigger()
                        self.connector.laserStateChanged.emit(False)
                        self.connector.safetyFailureStateChanged.emit(True)
                        logging.error(f"Failure Detected: {status_text}")

                # Emit combined status if needed
                
                logging.info(f"Console Status QUERY: {status_text}")

                # Read TCM (ADC VD) and TCL (ADC CD) from Seed (channel 5)
                tcm_raw = self.connector.getLsyncCount()
                tcl_raw = self.connector.i2cReadBytes("CONSOLE", muxIdx, 4, i2cAddr, 0x10, 4)
                # Read PDC from Safety OPT (channel 7)
                pdc_raw = self.connector.i2cReadBytes("CONSOLE", muxIdx, 7, i2cAddr, 0x1C, 2)
                
                logging.info(f"tcm_raw: {tcm_raw} tcl_raw: {tcl_raw} pdc_raw: {pdc_raw}")

                if tcl_raw and pdc_raw:
                    tcm = int(tcm_raw) 
                    tcl = int.from_bytes(tcl_raw, byteorder='little') 
                    pdc = int.from_bytes(pdc_raw, byteorder='little') * 2.7 # Convert to mA

                    logging.info(f"tcl: {tcl} pdc: {pdc}")

                    if (tcl != self.connector._tcl or 
                        tcm != self.connector._tcm or 
                        pdc != self.connector._pdc):
                        self.connector._tcl = tcl
                        self.connector._tcm = tcm
                        self.connector._pdc = pdc

                        logging.info(f"Analog Values → TCM: {tcm}, TCL: {tcl}, PDC: {pdc:.3f} mA")

                        self.connector.tclChanged.emit()
                        self.connector.tcmChanged.emit()
                        self.connector.pdcChanged.emit()

                # Sleep for up to 1000ms, but can be woken early
                self._mutex.lock()
                self._wait_condition.wait(self._mutex, 1000)
                self._mutex.unlock()

                # self._count += 1  # Increment count for status updates

            except Exception as e:
                logging.error(f"Console status query failed: {e}")

                # Sleep for up to 1000ms, but can be woken early
                self._mutex.lock()
                self._wait_condition.wait(self._mutex, 1000)
                self._mutex.unlock()

    def stop(self):
        self._running = False
        self._wait_condition.wakeAll()
        self.quit()
        self.wait()