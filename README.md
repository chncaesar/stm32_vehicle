# STM32 蓝牙遥控小车

用 iPhone 通过 BLE 蓝牙遥控的 STM32 智能小车。固件运行在 STM32F103RC，蓝牙模块使用 HM-10（BLE 4.0），iOS App 用 SwiftUI 编写。

---

## 硬件准备

- STM32F103RC 扩展板
- HM-10 蓝牙模块（BLE 4.0，**不能用 HC-06/HC-08**，iOS 不支持经典蓝牙）
- J-Link 调试器（烧录固件用）
- iPhone（运行 iOS App）

### HM-10 接线

将 HM-10 插到扩展板 **P16** 接口：

| P16 引脚 | HM-10 |
|---------|-------|
| 1（VCC 3.3V） | VCC |
| 3（RXD） | TXD |
| 4（TXD） | RXD |
| 5（GND） | GND |

天线朝外，远离电机和 L298N。

---

## 烧录固件

用 Keil MDK 打开 `USER/STM32智能小车.uvprojx`，编译后通过 J-Link 烧录到扩展板 P14（SWD 接口）。

也可以命令行编译：

```
"C:\Keil_v5\UV4\UV4.exe" -b "USER\STM32智能小车.uvprojx" -o build_log.txt
```

编译产物在 `OBJ/STM32智能小车.hex`。

---

## 安装 iOS App

用 Xcode 打开 `ios_app/STM32Car/STM32Car.xcodeproj`，连接 iPhone，编译安装。需要 Apple Developer 账号（免费账号即可）。

---

## 使用

1. 小车上电，听到三声蜂鸣表示启动正常
2. 打开 iPhone 上的 STM32Car App
3. 点击「扫描设备」，找到 HM-10（默认名称 `HMSoft`）并连接
4. 连接成功后进入控制界面：
   - 方向盘：按住前进/后退/左转/右转，松开停车
   - 速度滑块：1–9 档，默认 5 档
   - 中间红色按钮：紧急停车
5. App 进入后台或 500ms 内无指令，小车自动停车

---

## 调试串口

如需用串口助手直接发指令测试，将 USB 转 TTL（3.3V）接到扩展板 **P15**：

| USB 转 TTL | P15 |
|-----------|-----|
| TXD | 1（RXD） |
| RXD | 2（TXD） |
| GND | 3（GND） |

波特率 9600，8N1。发送 `ONA\r\n` 测试前进，`ONF\r\n` 停车。

---

## 指令协议

所有指令 3 字节 ASCII + `\r\n`，由 iOS App 自动发送，无需手动操作。

| 动作 | 按下 | 松开 |
|------|------|------|
| 前进 | `ONA` | `ONF` |
| 后退 | `ONB` | `ONF` |
| 左转 | `ONC` | `ONF` |
| 右转 | `OND` | `ONF` |
| 停止 | `ONE` | — |
| 速度 1–9 | `ON1`–`ON9` | `ONa`–`ONi` |
