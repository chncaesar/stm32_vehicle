import Combine
import CoreBluetooth

/// BLE 管理层的抽象接口，用于依赖注入和单元测试。
@MainActor
protocol BLEManaging: AnyObject {
    var connectionState: ConnectionState { get set }
    var discoveredPeripherals: [DiscoveredPeripheral] { get set }

    var connectionStatePublisher: Published<ConnectionState>.Publisher { get }
    var discoveredPeripheralsPublisher: Published<[DiscoveredPeripheral]>.Publisher { get }

    func startScan()
    func stopScan()
    func connect(to peripheral: CBPeripheral)
    func disconnect()
    @discardableResult func send(_ command: BLECommand) -> Bool
}
