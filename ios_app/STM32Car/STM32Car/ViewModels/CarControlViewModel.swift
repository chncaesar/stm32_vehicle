import Combine
import UIKit
import CoreBluetooth

/// 遥控业务逻辑层，桥接 `BLEManager` 与 SwiftUI View。
///
/// 职责：
/// - 将 BLEManager 的 `@Published` 属性转发为 ViewModel 属性
/// - 提供方向、速度、连接的接口方法
/// - App 进入后台时自动发送紧急停车
/// - 连接断开时清理本地方向状态
@MainActor
final class CarControlViewModel: ObservableObject {

    // MARK: - Published State

    /// 当前 BLE 连接状态
    @Published private(set) var connectionState: ConnectionState = .idle
    /// 当前速度档位，范围 1–9
    @Published var currentSpeed: Int = 5 {
        didSet {
            let clamped = clampSpeed(currentSpeed)
            if clamped != currentSpeed {
                currentSpeed = clamped
                return
            }
            onSpeedChange(from: oldValue, to: currentSpeed)
        }
    }
    /// 当前运动方向，`nil` 表示停止
    @Published private(set) var currentDirection: Direction?
    /// 扫描到的外设列表
    @Published var discoveredPeripherals: [DiscoveredPeripheral] = []

    // MARK: - Private

    private let bleManager: any BLEManaging
    private var cancellables = Set<AnyCancellable>()
    private var heartbeatCancellable: AnyCancellable?

    // MARK: - Init

    /// - Parameter bleManager: 可注入的 BLEManager，便于单元测试。
    init(bleManager: any BLEManaging = BLEManager()) {
        self.bleManager = bleManager
        bindBLEManager()
        setupBackgroundObserver()
    }

    // MARK: - 方向控制

    /// 按住方向按钮。
    func pressDirection(_ direction: Direction) {
        guard connectionState == .ready else { return }
        // 如果之前按着另一个方向，先松开
        if currentDirection != nil, currentDirection != direction {
            bleManager.send(.directionRelease)
        }
        currentDirection = direction
        bleManager.send(.directionPress(direction))
        startHeartbeat(direction)
    }

    /// 松开方向按钮。
    func releaseDirection() {
        stopHeartbeat()
        currentDirection = nil
        bleManager.send(.directionRelease)
    }

    // MARK: - 速度控制

    private func onSpeedChange(from old: Int, to new: Int) {
        guard new != old, connectionState == .ready else { return }
        bleManager.send(.speedPress(new))
        bleManager.send(.speedRelease(new))
    }

    // MARK: - 连接管理

    /// 开始扫描。
    func startScan() {
        bleManager.startScan()
    }

    /// 停止扫描。
    func stopScan() {
        bleManager.stopScan()
    }

    /// 连接到指定外设。
    func connect(to peripheral: CBPeripheral) {
        bleManager.connect(to: peripheral)
    }

    /// 断开当前连接。
    func disconnect() {
        sendEmergencyStop()
        bleManager.disconnect()
    }

    // MARK: - 安全停车

    /// 发送紧急停车指令并清理本地状态。
    func sendEmergencyStop() {
        stopHeartbeat()
        bleManager.send(.emergencyStop)
        currentDirection = nil
    }

    // MARK: - Private: 心跳

    /// 开始每 100 ms 重发一次方向指令，防止固件超时停车。
    private func startHeartbeat(_ direction: Direction) {
        stopHeartbeat()
        heartbeatCancellable = Timer.publish(
            every: BLEConstants.heartbeatInterval,
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            guard let self, self.connectionState == .ready else { return }
            self.bleManager.send(.directionPress(direction))
        }
    }

    private func stopHeartbeat() {
        heartbeatCancellable?.cancel()
        heartbeatCancellable = nil
    }

    // MARK: - Private: Combine 绑定

    private func bindBLEManager() {
        bleManager.connectionStatePublisher
            .sink { [weak self] state in
                self?.connectionState = state
                if case .disconnected = state {
                    self?.stopHeartbeat()
                    self?.currentDirection = nil
                }
            }
            .store(in: &cancellables)

        bleManager.discoveredPeripheralsPublisher
            .assign(to: &$discoveredPeripherals)
    }

    // MARK: - Private: 后台通知

    private func setupBackgroundObserver() {
        NotificationCenter.default.publisher(
            for: UIApplication.didEnterBackgroundNotification
        )
        .sink { [weak self] _ in
            self?.sendEmergencyStop()
        }
        .store(in: &cancellables)
    }
}

// MARK: - Type Aliases

extension CarControlViewModel {
    typealias Direction = BLECommand.Direction
}

// MARK: - Helpers

private func clampSpeed(_ n: Int) -> Int {
    max(1, min(9, n))
}
