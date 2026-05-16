import Combine
import CoreBluetooth
@testable import STM32Car

/// BLEManaging 的测试替身，用于 ViewModel 单元测试。
@MainActor
final class MockBLEManager: BLEManaging {

    // MARK: - Published State

    @Published var connectionState: ConnectionState = .idle
    @Published var discoveredPeripherals: [DiscoveredPeripheral] = []

    var connectionStatePublisher: Published<ConnectionState>.Publisher { $connectionState }
    var discoveredPeripheralsPublisher: Published<DiscoveredPeripheral>.Publisher { $discoveredPeripherals }

    // MARK: - Call Tracking

    var startScanCalled = false
    var stopScanCalled = false
    var connectCalledWith: CBPeripheral?
    var disconnectCalled = false
    var sentCommands: [BLECommand] = []
    var shouldSendSucceed = true

    // MARK: - BLEManaging

    func startScan() {
        startScanCalled = true
        connectionState = .scanning
    }

    func stopScan() {
        stopScanCalled = true
        connectionState = .idle
    }

    func connect(to peripheral: CBPeripheral) {
        connectCalledWith = peripheral
        connectionState = .connecting(peripheral: peripheral.name ?? "未知设备")
    }

    func disconnect() {
        disconnectCalled = true
        connectionState = .idle
        sentCommands.removeAll()
    }

    @discardableResult
    func send(_ command: BLECommand) -> Bool {
        sentCommands.append(command)
        return shouldSendSucceed
    }
}
