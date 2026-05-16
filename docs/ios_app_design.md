# iOS 蓝牙遥控 App 技术方案

## Context

硬件：STM32F103RC 智能小车，HM-10 BLE 4.0（TI CC2541），USART1（PA9/PA10），波特率 9600，UART 透传。
协议：3 字节定长 ASCII 指令，帧尾 \r\n，不可更改。
开发环境：macOS 26.2，Xcode 26.5，Swift 6.3.2，Apple Silicon，目标 iOS 16+。
BLE UUID：Service FFE0，Characteristic FFE1（CC2541 固定值）。

---

## 项目结构

### 位置

```
stm32_vehicle/
└── ios_app/
    └── STM32Car/                  ← Xcode 项目根目录
        ├── STM32Car.xcodeproj/
        ├── STM32Car/              ← 源码目录
        │   ├── App/
        │   │   ├── STM32CarApp.swift
        │   │   └── AppDelegate.swift
        │   ├── BLE/
        │   │   ├── BLEManager.swift
        │   │   ├── BLECommand.swift
        │   │   └── BLEConstants.swift
        │   ├── ViewModels/
        │   │   └── CarControlViewModel.swift
        │   ├── Views/
        │   │   ├── ContentView.swift
        │   │   ├── ConnectionView.swift
        │   │   ├── ControlView.swift
        │   │   ├── DirectionPad.swift
        │   │   └── SpeedSlider.swift
        │   ├── Models/
        │   │   ├── ConnectionState.swift
        │   │   └── CarState.swift
        │   └── Resources/
        │       └── Assets.xcassets
        └── STM32CarTests/
```

### 项目类型

Xcode 项目（非 Swift Package），原因：
- CoreBluetooth 需要 Info.plist 中的 `NSBluetoothAlwaysUsageDescription`
- 需要 Background Modes（bluetooth-central）
- SwiftUI App lifecycle，无 UIKit

---

## BLE 层

### HM-10 / CC2541 UUID 常量

```swift
// BLEConstants.swift
enum BLEConstants {
    static let serviceUUID        = CBUUID(string: "FFE0")
    static let characteristicUUID = CBUUID(string: "FFE1")
    static let scanTimeout: TimeInterval = 10.0
    static let reconnectDelay: TimeInterval = 2.0
    static let maxReconnectAttempts = 3
}
```

### 连接状态机

```swift
// Models/ConnectionState.swift
enum ConnectionState: Equatable {
    case idle                           // 初始，未扫描
    case scanning                       // CBCentralManager 扫描中
    case connecting(peripheral: String) // 正在连接，携带设备名
    case discoveringServices            // 已连接，发现服务中
    case ready                          // 特征已找到，可发送指令
    case disconnected(reason: String)   // 断开，携带原因
    case error(String)                  // 不可恢复错误（如权限拒绝）
}
```

### BLEManager 设计

```swift
// BLE/BLEManager.swift
import CoreBluetooth
import Combine

@MainActor
final class BLEManager: NSObject, ObservableObject {

    // MARK: - Published State
    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var discoveredPeripherals: [CBPeripheral] = []

    // MARK: - Private
    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?
    private var reconnectAttempts = 0
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    override init() {
        super.init()
        // queue: nil 表示主队列，配合 @MainActor 使用
        centralManager = CBCentralManager(delegate: self, queue: nil,
            options: [CBCentralManagerOptionRestoreIdentifierKey: "STM32CarCentral"])
    }

    // MARK: - Public API
    func startScan()
    func stopScan()
    func connect(to peripheral: CBPeripheral)
    func disconnect()
    func send(_ command: BLECommand) -> Bool   // 返回是否发送成功
}
```

### 指令编码

```swift
// BLE/BLECommand.swift
enum BLECommand {
    // 方向（按下 / 松开）
    case directionPress(Direction)
    case directionRelease           // 统一发 ONF

    // 速度（按下 / 松开）
    case speedPress(Int)            // 1~9
    case speedRelease(Int)          // 1~9 → a~i

    // 紧急停车
    case emergencyStop              // ONE

    enum Direction { case forward, backward, left, right }

    // 编码为 ASCII + \r\n
    var data: Data {
        let str: String
        switch self {
        case .directionPress(let d):
            switch d {
            case .forward:  str = "ONA"
            case .backward: str = "ONB"
            case .left:     str = "ONC"
            case .right:    str = "OND"
            }
        case .directionRelease:     str = "ONF"
        case .speedPress(let n):    str = "ON\(n)"
        case .speedRelease(let n):  str = "ON\(Character(UnicodeScalar(96 + n)!))" // ONa~ONi
        case .emergencyStop:        str = "ONE"
        }
        return Data((str + "\r\n").utf8)
    }
}
```

### 发送逻辑

```swift
func send(_ command: BLECommand) -> Bool {
    guard connectionState == .ready,
          let peripheral = targetPeripheral,
          let characteristic = txCharacteristic else { return false }
    // HM-10 FFE1 支持 Write Without Response，延迟更低
    peripheral.writeValue(command.data, for: characteristic,
                          type: .withoutResponse)
    return true
}
```

### 重连逻辑

```swift
// CBCentralManagerDelegate - didDisconnectPeripheral
func centralManager(_ central: CBCentralManager,
                    didDisconnectPeripheral peripheral: CBPeripheral,
                    error: Error?) {
    connectionState = .disconnected(reason: error?.localizedDescription ?? "用户断开")
    guard reconnectAttempts < BLEConstants.maxReconnectAttempts,
          let p = targetPeripheral else { return }
    reconnectAttempts += 1
    DispatchQueue.main.asyncAfter(deadline: .now() + BLEConstants.reconnectDelay) {
        self.centralManager.connect(p, options: nil)
        self.connectionState = .connecting(peripheral: p.name ?? "未知设备")
    }
}
```

### Info.plist 必要键

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要蓝牙权限以连接小车</string>
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

---

## UI 设计

### 整体布局（竖屏）

```
┌─────────────────────────────┐
│  STM32 小车遥控              │  NavigationTitle
│  ● 已连接 HMSoft            │  ConnectionStatusBar
├─────────────────────────────┤
│                             │
│         ▲                   │
│      ◀  ■  ▶               │  DirectionPad（四方向 + 中心停止）
│         ▼                   │
│                             │
├─────────────────────────────┤
│  速度  ━━━━━━●━━━━  5       │  SpeedSlider（1~9 档，步进）
├─────────────────────────────┤
│  [  扫描设备  ]             │  ConnectionView（未连接时显示）
└─────────────────────────────┘
```

### 方向控制：四方向按钮（非摇杆）

选择四方向按钮而非虚拟摇杆的原因：
- 协议是离散指令（按下/松开），不是连续坐标
- 摇杆需要额外的死区和方向映射逻辑，增加误操作概率
- 四方向按钮与协议语义完全对应，实现更简单可靠

```swift
// Views/DirectionPad.swift
struct DirectionPad: View {
    let onPress: (BLECommand.Direction) -> Void
    let onRelease: () -> Void

    var body: some View {
        // Grid 布局，3x3，中心为停止按钮
        // 每个方向按钮使用 .simultaneousGesture(DragGesture(minimumDistance: 0))
        // onChanged（按下）和 onEnded（松开）
    }
}
```

按钮按下/松开手势实现：

```swift
DirectionButton(symbol: "arrow.up")
    .simultaneousGesture(
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if !isPressing {
                    isPressing = true
                    onPress(.forward)
                }
            }
            .onEnded { _ in
                isPressing = false
                onRelease()
            }
    )
```

### 速度控制

```swift
// Views/SpeedSlider.swift
struct SpeedSlider: View {
    @Binding var speed: Int   // 1~9

    var body: some View {
        HStack {
            Text("速度")
            Slider(value: Binding(
                get: { Double(speed) },
                set: { speed = Int($0.rounded()) }
            ), in: 1...9, step: 1)
            Text("\(speed)")
                .monospacedDigit()
                .frame(width: 20)
        }
        .onChange(of: speed) { _, newValue in
            // 速度变化时发送速度指令
        }
    }
}
```

### 连接状态栏

```swift
extension ConnectionState {
    var indicatorColor: Color {
        switch self {
        case .ready:       return .green
        case .scanning, .connecting, .discoveringServices: return .yellow
        default:           return .red
        }
    }

    var displayText: String {
        switch self {
        case .idle:                    return "未连接"
        case .scanning:                return "扫描中..."
        case .connecting(let name):    return "连接 \(name)..."
        case .discoveringServices:     return "初始化..."
        case .ready:                   return "已连接"
        case .disconnected(let r):     return "断开：\(r)"
        case .error(let msg):          return "错误：\(msg)"
        }
    }
}
```

---

## 状态管理

### ViewModel

```swift
// ViewModels/CarControlViewModel.swift
@MainActor
final class CarControlViewModel: ObservableObject {

    @Published private(set) var connectionState: ConnectionState = .idle
    @Published var currentSpeed: Int = 5          // 1~9，默认中速
    @Published private(set) var currentDirection: BLECommand.Direction? = nil
    @Published var discoveredPeripherals: [CBPeripheral] = []

    private let bleManager: BLEManager
    private var cancellables = Set<AnyCancellable>()

    init(bleManager: BLEManager = BLEManager()) {
        self.bleManager = bleManager
        bindBLEManager()
        setupBackgroundObserver()
    }

    func pressDirection(_ direction: BLECommand.Direction) {
        guard connectionState == .ready else { return }
        currentDirection = direction
        bleManager.send(.directionPress(direction))
    }

    func releaseDirection() {
        currentDirection = nil
        bleManager.send(.directionRelease)
    }

    func setSpeed(_ speed: Int) {
        let clamped = max(1, min(9, speed))
        currentSpeed = clamped
        bleManager.send(.speedPress(clamped))
        bleManager.send(.speedRelease(clamped))
    }

    func startScan() { bleManager.startScan() }
    func connect(to peripheral: CBPeripheral) { bleManager.connect(to: peripheral) }
    func disconnect() {
        bleManager.send(.emergencyStop)
        bleManager.disconnect()
    }

    private func bindBLEManager() {
        bleManager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
                if case .disconnected = state { self?.currentDirection = nil }
            }
            .store(in: &cancellables)
        bleManager.$discoveredPeripherals
            .assign(to: &$discoveredPeripherals)
    }

    private func setupBackgroundObserver() {
        NotificationCenter.default.publisher(
            for: UIApplication.didEnterBackgroundNotification
        )
        .sink { [weak self] _ in
            self?.bleManager.send(.emergencyStop)
            self?.currentDirection = nil
        }
        .store(in: &cancellables)
    }
}
```

---

## 安全机制

| 场景 | 处理方式 |
|------|---------|
| App 进入后台 | 发送 `ONE`（emergencyStop），BLE 连接保持（bluetooth-central Background Mode） |
| BLE 连接断开 | 本地状态清理；固件侧 500ms 超时自动停车作为兜底 |
| 松开方向按钮 | `DragGesture.onEnded` 发送 `ONF`，立即停车 |
| 蓝牙权限拒绝 | `connectionState` 变为 `.error`，UI 引导前往设置 |
| 速度指令 | 幂等，只更新固件 `current_speed` 变量，不影响当前运动 |

---

## 文件清单

| 文件 | 职责 |
|------|------|
| `App/STM32CarApp.swift` | App 入口，注入 `CarControlViewModel` 到环境 |
| `App/AppDelegate.swift` | State Restoration（CBCentralManager restore identifier） |
| `BLE/BLEConstants.swift` | UUID 常量、超时时间、重连次数配置 |
| `BLE/BLECommand.swift` | 指令枚举，编码为 `Data`（含 \r\n） |
| `BLE/BLEManager.swift` | CoreBluetooth 封装，扫描/连接/重连/发送 |
| `Models/ConnectionState.swift` | 连接状态枚举，含 UI 辅助属性 |
| `Models/CarState.swift` | 小车当前状态（速度档、运动方向） |
| `ViewModels/CarControlViewModel.swift` | 业务逻辑层，桥接 BLEManager 和 View |
| `Views/ContentView.swift` | 根视图，根据连接状态切换页面 |
| `Views/ConnectionView.swift` | 扫描设备列表，点击连接 |
| `Views/ControlView.swift` | 主控制界面，组合方向盘 + 速度滑块 + 状态栏 |
| `Views/DirectionPad.swift` | 四方向按钮，处理按下/松开手势 |
| `Views/SpeedSlider.swift` | 速度滑块（1~9 步进） |

共 13 个 Swift 文件，零第三方依赖。

---

## 关键实现注意事项

1. **Swift 6 并发**：`BLEManager` 标注 `@MainActor`，`CBCentralManager(delegate:queue:nil)` 确保回调在主队列，避免跨 Actor 数据竞争。

2. **Write Without Response**：HM-10 FFE1 支持 `writeWithoutResponse`，延迟更低。运行时检查 `characteristic.properties.contains(.writeWithoutResponse)`，不满足时回退到 `.write`。

3. **State Restoration**：配置 `CBCentralManagerOptionRestoreIdentifierKey`，App 被系统终止后重启可恢复已连接外设。

4. **帧尾 \r\n**：STM32 固件以 `\r\n` 作为帧结束标志，`BLECommand.data` 必须追加 `\r\n`，否则固件不触发解析。

5. **速度指令时序**：ON1~ON9（按下）和 ONa~ONi（松开）连续发送，固件收到后只更新 `current_speed`，不影响当前运动状态。

---

## 验证方案

### 阶段 1：BLE 通信验证（无需 App）

1. LightBlue 连接 HM-10，确认 Service FFE0 / Characteristic FFE1 可见
2. 手动写入 `4F4E410D0A`（`ONA\r\n` 的 hex），确认 STM32 响应
3. BLE 测试需要真机（iPhone），Simulator 不支持 CoreBluetooth

### 阶段 2：单元测试

```swift
// STM32CarTests/BLECommandTests.swift
func testCommandEncoding() {
    XCTAssertEqual(BLECommand.directionPress(.forward).data, Data("ONA\r\n".utf8))
    XCTAssertEqual(BLECommand.directionRelease.data,         Data("ONF\r\n".utf8))
    XCTAssertEqual(BLECommand.speedPress(5).data,            Data("ON5\r\n".utf8))
    XCTAssertEqual(BLECommand.speedRelease(5).data,          Data("ONe\r\n".utf8))
    XCTAssertEqual(BLECommand.emergencyStop.data,            Data("ONE\r\n".utf8))
}
```

### 阶段 3：集成测试（真机 + 小车）

| 测试项 | 预期结果 |
|--------|---------|
| 扫描到 HM-10（名称 HMSoft） | 设备列表显示 |
| 点击连接 | 状态变绿，显示"已连接" |
| 按住前进 | 小车前进 |
| 松开前进 | 小车停止 |
| 速度滑块拖到 9 | 下次运动以最高速执行 |
| App 切换到后台 | 小车立即停止 |
| 断开 HM-10 电源 | 约 500ms 后小车停止（固件超时兜底） |
| App 重新进入前台 | 自动重连（最多 3 次） |
