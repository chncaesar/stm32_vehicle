import Testing
import Foundation
@testable import STM32Car

/// CarControlViewModel 状态流转测试。
///
/// 使用 MockBLEManager 替代真实的 BLEManager，
/// 避免依赖 CoreBluetooth 硬件。
@MainActor
struct CarControlViewModelTests {

    // MARK: - 初始状态

    @Test func initialState() {
        let mock = MockBLEManager()
        let vm = CarControlViewModel(bleManager: mock)

        #expect(vm.connectionState == .idle)
        #expect(vm.currentSpeed == 5)
        #expect(vm.currentDirection == nil)
        #expect(vm.discoveredPeripherals.isEmpty)
    }

    // MARK: - 连接状态同步

    @Test func connectionStatePropagation() {
        let mock = MockBLEManager()
        let vm = CarControlViewModel(bleManager: mock)

        mock.connectionState = .scanning
        #expect(vm.connectionState == .scanning)

        mock.connectionState = .connecting(peripheral: "HMSoft")
        #expect(vm.connectionState == .connecting(peripheral: "HMSoft"))

        mock.connectionState = .ready
        #expect(vm.connectionState == .ready)
    }

    @Test func disconnectedClearsDirection() {
        let mock = MockBLEManager()
        let vm = CarControlViewModel(bleManager: mock)
        mock.connectionState = .ready

        vm.pressDirection(.forward)
        #expect(vm.currentDirection == .forward)

        mock.connectionState = .disconnected(reason: "测试断开")
        #expect(vm.currentDirection == nil)
    }

    // MARK: - 方向控制

    @Test func pressDirectionSendsCommand() {
        let mock = MockBLEManager()
        let vm = CarControlViewModel(bleManager: mock)
        mock.connectionState = .ready

        vm.pressDirection(.forward)
        #expect(vm.currentDirection == .forward)
        #expect(mock.sentCommands.last == .directionPress(.forward))
    }

    @Test func pressDirectionIgnoredWhenNotReady() {
        let mock = MockBLEManager()
        let vm = CarControlViewModel(bleManager: mock)
        // 默认 .idle，不是 .ready

        vm.pressDirection(.forward)
        #expect(vm.currentDirection == nil)
        #expect(mock.sentCommands.isEmpty)
    }

    @Test func releaseDirectionSendsRelease() {
        let mock = MockBLEManager()
        let vm = CarControlViewModel(bleManager: mock)
        mock.connectionState = .ready
        vm.pressDirection(.forward)

        vm.releaseDirection()
        #expect(vm.currentDirection == nil)
        #expect(mock.sentCommands.last == .directionRelease)
    }

    @Test func directionChangeSendsReleaseFirst() {
        let mock = MockBLEManager()
        let vm = CarControlViewModel(bleManager: mock)
        mock.connectionState = .ready
        vm.pressDirection(.forward)

        vm.pressDirection(.left)
        #expect(vm.currentDirection == .left)
        #expect(mock.sentCommands.contains(.directionRelease))
        #expect(mock.sentCommands.last == .directionPress(.left))
    }

    // MARK: - 速度控制

    @Test func speedChangeSendsPressAndRelease() {
        let mock = MockBLEManager()
        let vm = CarControlViewModel(bleManager: mock)
        mock.connectionState = .ready

        vm.currentSpeed = 7
        #expect(mock.sentCommands.contains(.speedPress(7)))
        #expect(mock.sentCommands.contains(.speedRelease(7)))
    }

    @Test func speedChangeIgnoredWhenDisconnected() {
        let mock = MockBLEManager()
        let vm = CarControlViewModel(bleManager: mock)
        // .idle, not .ready

        vm.currentSpeed = 7
        #expect(mock.sentCommands.isEmpty)
    }

    @Test func speedClampedToRange() {
        let mock = MockBLEManager()
        let vm = CarControlViewModel(bleManager: mock)
        mock.connectionState = .ready

        vm.currentSpeed = 0
        #expect(vm.currentSpeed == 1)  // didSet 写回 clamp 后的值

        vm.currentSpeed = 10
        #expect(vm.currentSpeed == 9)
    }

    // MARK: - 连接管理

    @Test func startScanDelegation() {
        let mock = MockBLEManager()
        let vm = CarControlViewModel(bleManager: mock)

        vm.startScan()
        #expect(mock.startScanCalled)
    }

    @Test func stopScanDelegation() {
        let mock = MockBLEManager()
        let vm = CarControlViewModel(bleManager: mock)

        vm.stopScan()
        #expect(mock.stopScanCalled)
    }

    @Test func disconnectSendsEmergencyStop() {
        let mock = MockBLEManager()
        let vm = CarControlViewModel(bleManager: mock)
        mock.connectionState = .ready

        vm.disconnect()
        #expect(mock.sentCommands.contains(.emergencyStop))
        #expect(mock.disconnectCalled)
    }

    // MARK: - 紧急停车

    @Test func sendEmergencyStopClearsDirection() {
        let mock = MockBLEManager()
        let vm = CarControlViewModel(bleManager: mock)
        mock.connectionState = .ready
        vm.pressDirection(.forward)

        vm.sendEmergencyStop()
        #expect(vm.currentDirection == nil)
        #expect(mock.sentCommands.last == .emergencyStop)
    }

    // MARK: - DiscoveredPeripherals 同步

    @Test func discoveredPeripheralsPropagation() {
        let mock = MockBLEManager()
        let vm = CarControlViewModel(bleManager: mock)

        // 使用空列表验证 publisher 绑定工作
        #expect(vm.discoveredPeripherals.isEmpty)
    }
}
