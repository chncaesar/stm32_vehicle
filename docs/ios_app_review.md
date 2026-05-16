# iOS 遥控 App Code Review 检查点

## 1. 项目配置

- [ ] 项目类型为 Xcode Project（非 Swift Package），因需要 Info.plist 修改
- [ ] `NSBluetoothAlwaysUsageDescription` 已配置，文案为"需要蓝牙权限以连接小车"
- [ ] `UIBackgroundModes` 包含 `bluetooth-central`
- [ ] Deployment Target >= iOS 16.0
- [ ] 仅竖屏方向（`UISupportedInterfaceOrientations` 只保留 `UIInterfaceOrientationPortrait`）
- [ ] Swift Language Version 匹配项目（Swift 6）

## 2. BLE 层 — 常量与 UUID

- [ ] Service UUID 为 `FFE0`（HM-10 / CC2541 固定值）
- [ ] Characteristic UUID 为 `FFE1`（HM-10 数据发送特征）
- [ ] `scanTimeout` 设置为 10 秒，避免无限扫描
- [ ] `maxReconnectAttempts` 设置为 3，有限重连防止死循环
- [ ] `reconnectDelay` 设置为 2 秒，间隔合理不过于频繁

## 3. BLE 层 — CentralManager

- [ ] `CBCentralManager` 在主队列初始化（`queue: nil`），配合 `@MainActor` 使用
- [ ] 配置了 `CBCentralManagerOptionRestoreIdentifierKey`，启用 State Restoration
- [ ] `centralManagerDidUpdateState` 处理了所有状态：
  - [ ] `.poweredOn` → 开始扫描
  - [ ] `.unauthorized` → `connectionState = .error`，提示用户开启蓝牙权限
  - [ ] `.unsupported` / `.poweredOff` → `connectionState = .error`
- [ ] `startScan()` 调用时检查 `centralManager.state == .poweredOn`
- [ ] `stopScan()` 后清理已发现设备列表

## 4. BLE 层 — 连接与设备发现

- [ ] `didDiscover` 回调中过滤/去重 `discoveredPeripherals`，避免列表重复
- [ ] `connect()` 调用后状态转为 `.connecting`
- [ ] `didConnect` 回调后调 `discoverServices([BLEConstants.serviceUUID])`，只搜索 FFE0
- [ ] `didDiscoverServices` 中验证 service.UUID 为 FFE0，然后调 `discoverCharacteristics([BLEConstants.characteristicUUID])`
- [ ] `didDiscoverCharacteristicsFor` 中验证 characteristic.UUID 为 FFE1，保存 `txCharacteristic`
- [ ] 特征准备就绪后 `connectionState` 转为 `.ready`
- [ ] 任何连接失败（`didFailToConnect`、`didDisconnect`）正确更新 `.disconnected` 状态
- [ ] 重连计数器在成功连接后重置为 0
- [ ] 重连仅在非用户主动断开时触发（需区分用户主动 `disconnect()` 和意外断开）

## 5. 指令编码

- [ ] `BLECommand.directionPress(.forward)` → `Data("ONA\r\n".utf8)`
- [ ] `BLECommand.directionPress(.backward)` → `Data("ONB\r\n".utf8)`
- [ ] `BLECommand.directionPress(.left)` → `Data("ONC\r\n".utf8)`
- [ ] `BLECommand.directionPress(.right)` → `Data("OND\r\n".utf8)`
- [ ] `BLECommand.directionRelease` → `Data("ONF\r\n".utf8)`
- [ ] `BLECommand.emergencyStop` → `Data("ONE\r\n".utf8)`
- [ ] `BLECommand.speedPress(1~9)` → `Data("ON1\r\n".utf8)` 到 `Data("ON9\r\n".utf8)`
- [ ] `BLECommand.speedRelease(1~9)` → `Data("ONa\r\n".utf8)` 到 `Data("ONi\r\n".utf8)`（`96 + n` 映射正确）
- [ ] 所有指令末尾追加 `\r\n`，STM32 固件以此识别帧结束
- [ ] `speedPress` / `speedRelease` 的 `Int` 参数边界处理：小于 1 或大于 9 时不应 crash

## 6. 发送逻辑

- [ ] `send()` 方法前置检查 `connectionState == .ready`
- [ ] `send()` 方法检查 `txCharacteristic` 不为 nil
- [ ] 写入类型优先使用 `.withoutResponse`，延迟更低
- [ ] 运行时检查 `characteristic.properties.contains(.writeWithoutResponse)`，不满足时回退到 `.withResponse`
- [ ] `send()` 返回 `Bool`，调用方根据返回值判断是否发送成功
- [ ] 发送不阻塞，不等待确认（Write Without Response 语义）
- [ ] 快速连续发送时不会产生指令堆积（CoreBluetooth 内部队列处理）

## 7. ViewModel 状态管理

- [ ] `CarControlViewModel` 标注 `@MainActor`
- [ ] `BLEManager` 通过依赖注入传入（构造函数默认参数），便于测试
- [ ] Combine 订阅 `bleManager.$connectionState`，更新到本地 `@Published`
- [ ] Combine 订阅 `bleManager.$discoveredPeripherals`，更新到本地 `@Published`
- [ ] 方向按下时设置 `currentDirection`，松开时置 nil
- [ ] `currentSpeed` 默认值 5（中速），范围限制 1~9
- [ ] `setSpeed()` 连续发送按下+松开指令，顺序正确
- [ ] 收到 `.disconnected` 状态时清理 `currentDirection`
- [ ] 收到 `.error` 状态时方向控制按钮禁用
- [ ] `sendEmergencyStop()` 在断开连接前调用，确保停车指令发出

## 8. 后台与安全

- [ ] 监听了 `UIApplication.didEnterBackgroundNotification`，触发时发送 `emergencyStop`
- [ ] App 进入后台后 BLE 连接保持（已配置 `bluetooth-central` Background Mode）
- [ ] App 从后台返回时，`connectionState` 需能正确反映当前连接状态
- [ ] 方向按钮 `DragGesture.onEnded` 发送 `ONF`，确保手指离开屏幕立即停车
- [ ] 方向按钮的 `DragGesture` 不会被 ScrollView 或其他手势拦截（`.simultaneousGesture` 或 `.highPriorityGesture`）
- [ ] 速度滑块快速拖动不会产生大量重复 BLE 指令（协议层面幂等，但应考虑合理性）

## 9. UI 组件 — DirectionPad

- [ ] 采用 `DragGesture(minimumDistance: 0)` 区分按下和松开
- [ ] `onChanged` 触发时检查 `isPressing` 标志，防止重复触发（每按一次只发一条）
- [ ] `onEnded` 触发时重置 `isPressing` 标志
- [ ] 中心停止按钮逻辑独立，不触发方向按下/松开流程
- [ ] 按钮有 pressed 状态视觉反馈（颜色/缩放变化）
- [ ] 中心停止按钮视觉区分明显（红色，非方向颜色）
- [ ] 所有按钮最小触摸区域 >= 44x44pt（Apple HIG）
- [ ] 断连状态下方向按钮显示为禁用态（降低不透明度或灰色）

## 10. UI 组件 — SpeedSlider

- [ ] `Slider` 范围 1...9，`step: 1`，确保只输出整数值
- [ ] `onChange(of: speed)` 发送指令时机正确，无遗漏无重复
- [ ] 速度值文本使用 `.monospacedDigit()`，避免数字宽度变化导致文本跳动

## 11. UI 组件 — ConnectionView

- [ ] 扫描到的设备列表每行显示设备名和信号强度（RSSI）
- [ ] 点击设备行触发连接
- [ ] 扫描中显示 loading indicator
- [ ] 连接失败后仍可重新扫描
- [ ] 蓝牙权限被拒时显示引导文案，指向系统设置
- [ ] 无可用设备时显示空态提示

## 12. UI — 状态切换

- [ ] `ContentView` 根据 `connectionState` 切换显示连接页面或控制页面
- [ ] 连接页面 → 控制页面：连接成功后平滑过渡（如淡入淡出）
- [ ] 控制页面 → 连接页面：断开后立即切换
- [ ] `.idle` → `.scanning` → `.connecting` → `.ready` 流程完整覆盖
- [ ] `.ready` → `.disconnected` → `.idle` 流程完整覆盖

## 13. Swift 6 并发安全

- [ ] `BLEManager` 标注 `@MainActor`，所有 `@Published` 在主线程更新
- [ ] `CBCentralManager` 使用 `queue: nil`（主队列），代理回调在主线程执行
- [ ] 不存在 `Sendable` 警告（`CBPeripheral` 和 `CBCharacteristic` 仅在 `@MainActor` 域内访问）
- [ ] Combine `sink` 中的 `[weak self]` 无循环引用风险
- [ ] 不使用 `Task.detached` 或全局 Actor 访问 BLE 相关对象

## 14. 单元测试

- [ ] `BLECommandTests` 覆盖所有指令编码，包含边界值（速度 1 和 9）
- [ ] `BLECommandTests` 验证指令数据包含 `\r\n` 帧尾
- [ ] `BLECommandTests` 验证 `directionPress` / `directionRelease` 每个方向
- [ ] 测试用例在 iPhone Simulator 下可运行（不依赖 CoreBluetooth 硬件）
- [ ] ViewModel 单元测试可通过 mock `BLEManager` 验证状态流转

## 15. 真机验证（需 iPhone + HM-10 + STM32）

- [ ] 扫描显示 HM-10（设备名 "HMSoft"）
- [ ] 连接后状态栏变绿，显示"已连接"
- [ ] 按住前进 → 小车前进，松开 → 小车停止
- [ ] 四方向均正确响应
- [ ] 调整速度滑块 → 下次运动以新速度执行
- [ ] App 切换后台 → 小车立即停止，回到前台连接仍在
- [ ] 手动断开 HM-10 电源 → 状态栏变红，显示断开原因
- [ ] 重新上电 HM-10 → 自动重连成功（最多 3 次尝试）
- [ ] 设置中关闭蓝牙权限 → App 显示引导提示
