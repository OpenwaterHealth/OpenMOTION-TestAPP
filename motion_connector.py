from PyQt6.QtCore import QObject, pyqtSignal, pyqtProperty, pyqtSlot
import logging

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

    connectionStatusChanged = pyqtSignal()  # 🔹 New signal for connection updates

    stateChanged = pyqtSignal()  # Notifies QML when state changes
    
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