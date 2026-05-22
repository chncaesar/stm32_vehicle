# iOS 遥控 App 开发指南

## 项目概览

**项目名**：STM32Car  
**位置**：`ios_app/STM32Car/`  
**语言**：Swift 6.0+  
**最低 iOS 版本**：iOS 15.0  
**开发工具**：Xcode 16+

---

## 快速开始

### 1. 打开项目

```bash
open ios_app/STM32Car/STM32Car.xcodeproj
```

### 2. 构建与运行

- 选择 iPhone 模拟器或真机
- 按 `Cmd + R` 构建并运行
- 或在 Xcode 中点击 Play 按钮

### 3. 运行单元测试

```bash
Cmd + U
```

或在终端：

```bash
xcodebuild test -scheme STM32Car
```

---

## 项目结构

```
ios_app/STM32Car/
├── STM32Car/                          # 主应用
│   ├── App/
│   │   └── STM32CarApp.swift          # 应用入口
│   ├── BLE/
│   │   ├── BLEManager.swift           # CoreBluetooth 封装
│   │   ├── BLEManaging.swift          # BLE 协议定义
│   │   ├── BLECommand.swift           # 指令编码
│   │   └── BLEConstants.swift         # 常量定义
│   ├── Models/
│   │   ├── ConnectionState.swift      # 连接状态枚举
│   │   └── DiscoveredPeripheral.swift # 扫描到的设备
│   ├── ViewModels/
│   │   └── CarControlViewModel.swift  # 业务逻辑
│   └── Views/
│       ├── ContentView.swift          # 主容器
│       ├── ConnectionView.swift       # 扫描与连接
│       ├── ControlView.swift          # 遥控页面
│       ├── DirectionPad.swift         # 方向盘
│       └── SpeedSlider.swift          # 速度滑块
├── STM32CarTests/                     # 单元测试
│   ├── BLECommandTests.swift
│   ├── CarControlViewModelTests.swift
│   └── MockBLEManager.swift
└── STM32Car.xcodeproj                 # Xcode 项目文件
```

---

## 核心模块说明

### BLEManager（蓝牙管理）

**文件**：`BLE/BLEManager.swift`

职责：
- 扫描 HM-10 设备（Service UUID: `FFE0`）
- 连接/断开外设
- 发现 Service 和 Characteristic（`FFE1`）
- 通过 Write Without Response 发送指令
- 自动重连机制（最多 3 次）

关键方法：
- `startScan()` — 开始扫描，30 秒超时自动停止
- `connect(to:)` — 连接指定外设
- `disconnect()` — 主动断开
- `send(_:)` — 发送 BLECommand

### BLECommand（指令编码）

**文件**：`BLE/BLECommand.swift`

定义所有蓝牙指令，自动编码为 3 字节 ASCII + `\r\n`：

```swift
// 方向控制
.directionPress(.forward)  // → "ONA\r\n"
.directionRelease          // → "ONF\r\n"

// 速度控制
.speedPress(5)             // → "ON5\r\n"
.speedRelease(5)           // → "ONe\r\n"

// 紧急停车
.emergencyStop             // → "ONE\r\n"
```

### CarControlViewModel（业务逻辑）

**文件**：`ViewModels/CarControlViewModel.swift`

职责：
- 桥接 BLEManager 与 SwiftUI View
- 管理方向、速度、连接状态
- 处理方向按钮的按下/松开逻辑
- App 进入后台时自动停车
- 连接断开时清理本地状态

关键方法：
- `pressDirection(_:)` — 按住方向按钮
- `releaseDirection()` — 松开方向按钮
- `startScan()` / `stopScan()` — 扫描控制
- `connect(to:)` — 连接设备
- `disconnect()` — 断开连接
- `sendEmergencyStop()` — 紧急停车

### DirectionPad（方向盘）

**文件**：`Views/DirectionPad.swift`

3×3 Grid 布局：
- 四个方向按钮（上下左右）
- 中心停车按钮（红色）
- 使用 `DragGesture(minimumDistance: 0)` 区分按下和松开

### SpeedSlider（速度滑块）

**文件**：`Views/SpeedSlider.swift`

- 1–9 档步进滑块
- 实时显示当前速度
- 与 ViewModel 双向绑定

---

## 通信协议

### 指令格式

所有指令为 **3 字节 ASCII + `\r\n`**（共 5 字节）

### 方向指令

| 动作 | 按下 | 松开 |
|------|------|------|
| 前进 | `ONA` | `ONF` |
| 后退 | `ONB` | `ONF` |
| 左转 | `ONC` | `ONF` |
| 右转 | `OND` | `ONF` |
| 停止 | `ONE` | `ONF` |

### 速度指令

| 档位 | 按下 | 松开 |
|------|------|------|
| 1 | `ON1` | `ONa` |
| 2 | `ON2` | `ONb` |
| ... | ... | ... |
| 9 | `ON9` | `ONi` |

---

## 单元测试

### BLECommandTests

验证指令编码正确性：

```swift
@Test func forwardPress() {
    let cmd = BLECommand.directionPress(.forward)
    #expect(cmd.data == Data("ONA\r\n".utf8))
}
```

运行：`Cmd + U`

### CarControlViewModelTests

验证业务逻辑（使用 MockBLEManager）

### MockBLEManager

用于测试隔离，模拟 BLE 行为

---

## 常见问题

### Q: 如何修改 HM-10 的 Service/Characteristic UUID？

**A**: 编辑 `BLE/BLEConstants.swift`：

```swift
struct BLEConstants {
    static let serviceUUID = CBUUID(string: "FFE0")
    static let characteristicUUID = CBUUID(string: "FFE1")
}
```

### Q: 如何改变方向盘的大小？

**A**: 编辑 `Views/DirectionPad.swift`，修改 `.frame(width: 216, height: 216)`

### Q: 如何调整自动重连次数？

**A**: 编辑 `BLE/BLEConstants.swift`，修改 `maxReconnectAttempts`

### Q: 如何禁用后台自动停车？

**A**: 在 `CarControlViewModel.swift` 中注释掉 `setupBackgroundObserver()`

---

## 调试技巧

### 1. 启用日志

在 `BLEManager.swift` 中添加 `print` 语句：

```swift
print("📡 Sending: \(command.description)")
```

### 2. 使用 Xcode 调试器

- 在关键方法设置断点
- 按 `Cmd + Y` 启用/禁用断点
- 使用 LLDB 检查变量

### 3. 模拟器测试

- 模拟器无法真实模拟 BLE，但可以测试 UI 和逻辑
- 使用 MockBLEManager 进行单元测试
- 真机测试需要实际的 HM-10 模块

---

## 部署检查清单

- [ ] 所有单元测试通过
- [ ] 无编译警告
- [ ] 蓝牙权限已在 Info.plist 中声明
- [ ] 最低 iOS 版本设置正确（15.0+）
- [ ] 在真机上测试过连接和控制
- [ ] 后台停车功能已验证
- [ ] 自动重连功能已验证

---

## 相关文档

- [蓝牙遥控设计文档](bluetooth_remote_design.md)
- [项目上下文](project_context.md)
- [STM32 固件](../CLAUDE.md)
