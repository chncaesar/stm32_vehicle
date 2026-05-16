import CoreBluetooth
import Combine
import UIKit

/// CoreBluetooth 封装层。
///
/// 职责：
/// - 扫描、连接、断开 HM-10 外设
/// - 发现 Service FFE0 / Characteristic FFE1
/// - 通过 Write Without Response 发送指令
/// - 意外断开时自动重连（有限次数）
///
/// 使用 `@MainActor` 确保所有 `@Published` 属性在主线程更新。
/// `CBCentralManager(queue: nil)` 在主队列回调，与 `@MainActor` 兼容。
@MainActor
class BLEManager: NSObject, ObservableObject {

    // MARK: - Published State

    /// 当前连接状态
    @Published var connectionState: ConnectionState = .idle
    /// 扫描到的可用外设列表
    @Published var discoveredPeripherals: [DiscoveredPeripheral] = []

    // MARK: - Private Properties

    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?

    private var reconnectAttempts = 0
    private var isUserDisconnecting = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    override init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: "STM32CarCentral",
            ]
        )
    }

    // MARK: - Public API

    /// 开始扫描外设。
    func startScan() {
        guard centralManager.state == .poweredOn else { return }
        connectionState = .scanning
        discoveredPeripherals.removeAll()
        centralManager.scanForPeripherals(withServices: [BLEConstants.serviceUUID], options: nil)

        // 扫描超时自动停止
        DispatchQueue.main.asyncAfter(deadline: .now() + BLEConstants.scanTimeout) { [weak self] in
            guard let self, self.connectionState == .scanning else { return }
            self.stopScan()
            if self.discoveredPeripherals.isEmpty {
                self.connectionState = .idle
            }
        }
    }

    /// 停止扫描。
    func stopScan() {
        centralManager.stopScan()
        if connectionState == .scanning {
            connectionState = .idle
        }
    }

    /// 连接指定外设。
    func connect(to peripheral: CBPeripheral) {
        stopScan()
        isUserDisconnecting = false
        targetPeripheral = peripheral
        reconnectAttempts = 0
        connectionState = .connecting(peripheral: peripheral.name ?? "未知设备")
        centralManager.connect(peripheral, options: nil)
    }

    /// 主动断开当前连接。
    func disconnect() {
        isUserDisconnecting = true
        guard let peripheral = targetPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }

    /// 发送指令。
    /// - Returns: `true` 表示已写入，`false` 表示未就绪（未连接或特征未找到）。
    @discardableResult
    func send(_ command: BLECommand) -> Bool {
        guard connectionState == .ready,
              let peripheral = targetPeripheral,
              let characteristic = txCharacteristic,
              peripheral.state == .connected
        else { return false }

        let type: CBCharacteristicWriteType =
            characteristic.properties.contains(.writeWithoutResponse)
            ? .withoutResponse
            : .withResponse

        peripheral.writeValue(command.data, for: characteristic, type: type)
        return true
    }

    /// 重连上次连接的外设（内部使用）。
    private func attemptReconnect() {
        guard let peripheral = targetPeripheral,
              reconnectAttempts < BLEConstants.maxReconnectAttempts,
              !isUserDisconnecting
        else { return }

        reconnectAttempts += 1
        connectionState = .connecting(peripheral: peripheral.name ?? "未知设备")
        centralManager.connect(peripheral, options: nil)
    }
}

// MARK: - BLEManaging

extension BLEManager: BLEManaging {
    var connectionStatePublisher: Published<ConnectionState>.Publisher { $connectionState }
    var discoveredPeripheralsPublisher: Published<DiscoveredPeripheral>.Publisher { $discoveredPeripherals }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.run { [weak self] in
            switch central.state {
            case .poweredOn:
                // 如果之前是因权限等问题断开，回到 idle 等待用户操作
                if case .error = self?.connectionState {
                    self?.connectionState = .idle
                }
            case .unauthorized:
                self?.connectionState = .error("蓝牙权限被拒绝，请前往设置开启")
            case .unsupported:
                self?.connectionState = .error("此设备不支持蓝牙")
            case .poweredOff:
                self?.connectionState = .error("蓝牙已关闭")
            default:
                self?.connectionState = .error("蓝牙不可用")
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    willRestoreState dict: [String: Any]) {
        MainActor.run { [weak self] in
            let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]
            guard let peripheral = peripherals?.first else { return }
            self?.targetPeripheral = peripheral
            self?.reconnectAttempts = 0
            if peripheral.state == .connected {
                // 系统已恢复连接，直接开始服务发现
                self?.connectionState = .discoveringServices
                peripheral.delegate = self
                peripheral.discoverServices([BLEConstants.serviceUUID])
            } else {
                self?.connectionState = .connecting(peripheral: peripheral.name ?? "未知设备")
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any],
                                    rssi RSSI: NSNumber) {
        MainActor.run { [weak self] in
            let discovered = DiscoveredPeripheral(peripheral: peripheral, rssi: RSSI)
            // 去重：替换同名或同 identifier 的设备
            if let idx = self?.discoveredPeripherals.firstIndex(where: {
                $0.peripheral.identifier == peripheral.identifier || $0.peripheral.name == peripheral.name
            }) {
                self?.discoveredPeripherals[idx] = discovered
            } else {
                self?.discoveredPeripherals.append(discovered)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didConnect peripheral: CBPeripheral) {
        MainActor.run { [weak self] in
            self?.connectionState = .discoveringServices
            peripheral.delegate = self
            peripheral.discoverServices([BLEConstants.serviceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didFailToConnect peripheral: CBPeripheral,
                                    error: Error?) {
        MainActor.run { [weak self] in
            let reason = error?.localizedDescription ?? "连接失败"
            self?.connectionState = .disconnected(reason: reason)
            // 尝试重连
            DispatchQueue.main.asyncAfter(deadline: .now() + BLEConstants.reconnectDelay) {
                self?.attemptReconnect()
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDisconnectPeripheral peripheral: CBPeripheral,
                                    error: Error?) {
        MainActor.run { [weak self] in
            guard let self else { return }
            if self.isUserDisconnecting {
                self.connectionState = .idle
                self.targetPeripheral = nil
                self.txCharacteristic = nil
                self.reconnectAttempts = 0
                return
            }

            let reason = error?.localizedDescription ?? "连接断开"
            self.connectionState = .disconnected(reason: reason)

            // 自动重连
            DispatchQueue.main.asyncAfter(deadline: .now() + BLEConstants.reconnectDelay) {
                self.attemptReconnect()
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didDiscoverServices error: Error?) {
        MainActor.run { [weak self] in
            guard let service = peripheral.services?.first(where: { $0.uuid == BLEConstants.serviceUUID }) else {
                self?.connectionState = .disconnected(reason: "未发现 BLE 服务")
                return
            }
            peripheral.discoverCharacteristics([BLEConstants.characteristicUUID], for: service)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didDiscoverCharacteristicsFor service: CBService,
                                error: Error?) {
        MainActor.run { [weak self] in
            guard let characteristic = service.characteristics?.first(where: {
                $0.uuid == BLEConstants.characteristicUUID
            }) else {
                self?.connectionState = .disconnected(reason: "未发现数据特征")
                return
            }
            self?.txCharacteristic = characteristic
            self?.reconnectAttempts = 0
            self?.connectionState = .ready
        }
    }
}
