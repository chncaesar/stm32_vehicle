# 蓝牙遥控模块设计文档

## 1. 概述

本文档描述 STM32F103RC 智能小车蓝牙遥控功能的硬件选型、接线、通信协议及固件设计方案。小车删除循迹和避障功能，仅保留蓝牙遥控驱动模式。

---

## 2. 硬件选型

### 蓝牙模块

| 项目 | 说明 |
|------|------|
| 推荐模块 | HM-10 |
| 核心芯片 | TI CC2541 |
| 蓝牙版本 | BLE 4.0 |
| 工作电压 | 3.3V |
| 通信接口 | UART 透传 |
| iOS 兼容 | 支持（BLE，非 SPP） |

**选型原因**：用户使用 iPhone，iOS 系统仅开放 BLE 4.0+ 接口，不支持经典蓝牙 SPP 协议（HC-06/HC-08 不可用）。CC2541 内置固件实现 BLE↔UART 透传，MCU 侧无需关心蓝牙协议栈。

### 调试 App（第一阶段）

- **LightBlue**（iOS App Store 免费）
- 支持 BLE UART 透传，可手动发送 ASCII 指令，用于验证通信和电机控制

### 正式 App（第二阶段）

自行开发 iOS App，实现方向控制 + 速度调节界面。

---

## 3. 硬件接线

### 电压说明

| 节点 | 电压 | 来源 |
|------|------|------|
| 扩展板 P16 VCC | **+3.3V** | 主控板板载 LDO（U2）输出，原理图确认 |
| STM32 TX（PA9）输出电平 | 3.3V | MCU IO 标准电平 |
| HM-10 工作电压 | 3.3V | CC2541 规格 |
| HM-10 RX 耐压 | 3.3V | CC2541 规格 |

结论：供电和信号电平完全匹配，**无需任何电平转换或降压电路**。

### 扩展板蓝牙接口（P16）与 HM-10 接线

| P16 引脚 | 信号 | HM-10 引脚 |
|---------|------|-----------|
| 1 | VCC（+3.3V） | VCC |
| 3 | RXD（PA10，USART1 RX） | TXD |
| 4 | TXD（PA9，USART1 TX） | RXD |
| 5 | GND | GND |

HM-10 的 STATE 和 BRK 引脚悬空不接。

### MCU 侧 USART1 配置

| 项目 | 值 |
|------|----|
| 外设 | USART1 |
| TX 引脚 | PA9（AF_PP，50MHz） |
| RX 引脚 | PA10（浮空输入） |
| 波特率 | 9600 |
| 中断 | USART1_IRQn，抢占优先级 3，子优先级 3 |
| 接收缓冲区 | `USART_RX_BUF[200]`，以 `\r\n` 为帧尾 |

**注意**：
- HM-10 天线朝外，远离 L298N 和电机，避免电磁干扰
- JTAG 在启动时已禁用（`GPIO_Remap_SWJ_JTAGDisable`），SWD 调试正常可用

---

## 4. 通信协议

### 基本参数

| 项目 | 值 |
|------|----|
| 波特率 | 9600 |
| 数据位 | 8 |
| 停止位 | 1 |
| 校验位 | 无 |
| 指令格式 | ASCII 字符串，3 字节定长 |

### 方向控制指令

| 动作 | 按下发送 | 松开发送 |
|------|---------|---------|
| 前进 | `ONA`   | `ONF`   |
| 后退 | `ONB`   | `ONF`   |
| 左转 | `ONC`   | `ONF`   |
| 右转 | `OND`   | `ONF`   |
| 停止 | `ONE`   | `ONF`   |

### 速度控制指令（9 档）

| 速度档 | 按下发送 | 松开发送 |
|--------|---------|---------|
| 速度 1（最慢） | `ON1` | `ONa` |
| 速度 2 | `ON2` | `ONb` |
| 速度 3 | `ON3` | `ONc` |
| 速度 4 | `ON4` | `ONd` |
| 速度 5 | `ON5` | `ONe` |
| 速度 6 | `ON6` | `ONf` |
| 速度 7 | `ON7` | `ONg` |
| 速度 8 | `ON8` | `ONh` |
| 速度 9（最快） | `ON9` | `ONi` |

**设计说明**：
- 按下方向键发送运动指令，松开发送 `ONF` 停车
- 速度档独立设置，不影响当前运动状态，下次运动时生效
- 速度 1~9 映射到电机速度 20~100（避免速度过低失速）

---

## 5. 固件设计

### 5.1 主要改动

相比原始代码，需要做以下改动：

1. **删除**循迹模块（`tracking.c/h`）
2. **删除**避障模块（`obstacle_avoidance.c/h`）
3. **删除**模式切换逻辑（`key_value` 状态机、`Driving_mode()`）
4. **修改** `uart_init(115200)` → `uart_init(9600)`
5. **重构**运动函数，去掉阻塞 `delay_ms`，改为立即执行
6. **新增**蓝牙指令解析逻辑
7. **新增**断连超时检测，超时自动停车

### 5.2 运动函数重构

原运动函数末尾带 `delay_ms(time)` 阻塞，遥控场景下会导致指令丢失。

改为立即设置电机状态，不阻塞：

```c
// 重构后：只设置方向和速度，不阻塞
void driving_state_run(signed char speed)
{
    L298N_IN1 = 0; L298N_IN2 = 1;
    L298N_IN3 = 1; L298N_IN4 = 0;
    Left_motor_speed_control(speed);
    Right_motor_speed_control(speed);
}
```

### 5.3 指令解析逻辑

在主循环中检测 `USART_RX_STA`，收到完整帧后解析：

```c
void bluetooth_cmd_parse(void)
{
    if (USART_RX_STA & 0x8000) {           // 收到完整帧
        last_rx_tick = get_tick();          // 更新最后接收时间
        u8 len = USART_RX_STA & 0x3FFF;
        if (len == 3) {
            if      (strncmp(USART_RX_BUF, "ONA", 3) == 0) driving_state_run(current_speed);
            else if (strncmp(USART_RX_BUF, "ONB", 3) == 0) driving_state_back(current_speed);
            else if (strncmp(USART_RX_BUF, "ONC", 3) == 0) driving_state_left(current_speed);
            else if (strncmp(USART_RX_BUF, "OND", 3) == 0) driving_state_right(current_speed);
            else if (strncmp(USART_RX_BUF, "ONE", 3) == 0) driving_state_stop();
            else if (strncmp(USART_RX_BUF, "ONF", 3) == 0) driving_state_stop();
            else if (USART_RX_BUF[0] == 'O' && USART_RX_BUF[1] == 'N') {
                char c = USART_RX_BUF[2];
                if (c >= '1' && c <= '9')
                    current_speed = 20 + (c - '1') * 10; // 20~100
            }
        }
        USART_RX_STA = 0;                   // 清空缓冲区
    }
}
```

### 5.4 断连超时检测

HM-10 断开连接时不会主动通知 MCU，需要用超时机制：

- 正常遥控时 App 持续发送心跳或指令
- 超过 500ms 未收到任何数据，判定为断连，立即停车

计时使用全局毫秒计数器 `bt_tick`，在 SysTick 中断（1ms）里自增：

```c
#define BT_TIMEOUT_MS  500

volatile u32 bt_tick = 0;       // SysTick 中断每 1ms 自增
u32 last_rx_tick = 0;           // 最后一次收到数据的时间

void bluetooth_timeout_check(void)
{
    if (bt_tick - last_rx_tick > BT_TIMEOUT_MS) {
        driving_state_stop();
    }
}
```

**注意**：现有 `delay_init()` 使用 HCLK/8 作为 SysTick 时钟源，需确认 SysTick 中断已启用并每 1ms 触发一次，或单独用一个全局变量在主循环里累计延时计数。

### 5.5 主循环结构

```c
int main(void)
{
    delay_init();
    uart_init(9600);
    TIM4_PWM_Init(7199, 0);
    LED_Init();
    BEEP_Init();
    BEEP = 1;
    KEY_Init();

    driving_state_stop();
    led_beep_switch(3);

    while (1) {
        bluetooth_cmd_parse();
        bluetooth_timeout_check();
    }
}
```

---

## 6. iOS 遥控 App 实现

iOS App 已完整实现，位置：`ios_app/STM32Car/`

### 功能清单

- ✅ BLE 设备扫描与连接（HM-10）
- ✅ 四方向方向盘控制（前进、后退、左转、右转）
- ✅ 紧急停车按钮
- ✅ 速度 1–9 档滑块调节
- ✅ 连接状态显示与信号强度（RSSI）
- ✅ 后台自动停车保护
- ✅ 自动重连机制
- ✅ 蓝牙权限检查与错误提示
- ✅ 单元测试（BLECommand 编码、ViewModel 逻辑）

### 架构

| 模块 | 职责 |
|------|------|
| `BLE/BLEManager.swift` | CoreBluetooth 封装，扫描/连接/服务发现 |
| `BLE/BLECommand.swift` | 指令编码（3 字节 ASCII + `\r\n`） |
| `ViewModels/CarControlViewModel.swift` | 业务逻辑，桥接 BLE 与 UI |
| `Views/ControlView.swift` | 主遥控页面 |
| `Views/DirectionPad.swift` | 方向盘组件 |
| `Views/SpeedSlider.swift` | 速度滑块组件 |
| `Views/ConnectionView.swift` | 设备扫描与连接页面 |

---

## 7. 待办事项

- [ ] 收到 HM-10 模块后按接线表连接扩展板 P16
- [ ] 用 LightBlue 验证 BLE 连接和指令收发
- [ ] 完成固件改造并验证电机响应
- [x] 开发 iOS 遥控 App（第二阶段）
