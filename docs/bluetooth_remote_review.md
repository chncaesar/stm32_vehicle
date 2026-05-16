# 蓝牙遥控模块 Code Review 检查点

## 1. 串口配置

- [x] `uart_init(9600)` 波特率与 HM-10 默认波特率一致
- [x] USART1 RX 中断已启用（`USART_IT_RXNE`）
- [x] 中断优先级配置正确，不与其他中断冲突
- [x] `USART_RX_BUF` 和 `USART_RX_STA` 在中断和主循环间共享，访问前需确认不会被中断打断导致数据撕裂

## 2. 指令解析

- [x] 收到完整帧标志位 `USART_RX_STA & 0x8000` 判断正确
- [x] 解析前检查帧长度为 3 字节，防止短帧误匹配
- [x] 所有指令分支覆盖完整：ONA / ONB / ONC / OND / ONE / ONF / ON1~ON9
- [x] 解析完成后 `USART_RX_STA = 0` 清空缓冲区，防止重复处理
- [x] 速度映射范围正确：ON1~ON9 → 20~100，不超出电机速度上限 100

## 3. 运动函数

- [x] 所有运动函数已去掉 `delay_ms(time)` 阻塞，改为立即返回
- [x] `driving_state_stop()` 同时将 PWM 占空比置 0，电机完全停转
- [x] 左右电机方向 GPIO（IN1~IN4）在每次运动函数调用时都重新设置，不依赖上次状态
- [x] `Left_motor_speed_control` / `Right_motor_speed_control` 速度参数边界处理正确（speed >= 100 截断）

## 4. 断连超时

- [ ] `bt_tick` 毫秒计数器在 SysTick 中断中正确自增
- [ ] `last_rx_tick` 在每次成功解析到完整帧后更新
- [ ] 超时阈值 500ms 合理，不会因正常指令间隔触发误停车
- [ ] 上电初始状态：`last_rx_tick` 初始值设置合理，避免上电瞬间误判超时

## 5. 主循环

- [x] 主循环只调用 `bluetooth_cmd_parse()` 和 `bluetooth_timeout_check()`，无多余阻塞
- [x] 删除了 `Driving_mode()`、`tracking_mode()`、`obstacle_avoidance_mode()` 的调用
- [x] 删除了 `key_value` 状态机相关代码
- [x] `uart_init` 在 `TIM4_PWM_Init` 之前调用，初始化顺序正确

## 6. 删除的模块

- [x] `tracking.c / tracking.h` 已从 Keil 工程中移除
- [x] `obstacle_avoidance.c / obstacle_avoidance.h` 已从 Keil 工程中移除
- [x] `main.c` 中对应的 `#include` 已删除
- [ ] Keil 工程编译无 warning（未使用的变量/函数）

## 7. 安全行为

- [x] 上电后小车默认停止状态，不会自动运动
- [x] 蓝牙未连接时（超时）小车保持停止
- [x] 收到 `ONF`（松开）指令立即停车，响应及时
- [x] 异常指令（非 ON 开头、长度不为 3）不触发任何运动，静默丢弃

---

## Review 结论（2026-05-16）

### Bug 1 — `USART_RX_STA` 缺少 `volatile`（严重）

**文件**：`SYSTEM/usart/usart.c:44`、`SYSTEM/usart/usart.h:21`

`USART_RX_STA` 由 ISR 写入、主循环读取，但未声明 `volatile`。编译器可将其缓存在寄存器中，导致主循环永远看不到 ISR 的更新，蓝牙指令完全失效。

**修复**：
```c
// usart.c:44
volatile u16 USART_RX_STA = 0;

// usart.h:21
extern volatile u16 USART_RX_STA;
```

### Bug 2 — 超时阈值 50000 次循环 ≈ 5ms，不是 500ms（严重）

**文件**：`USER/main.c:66`

主循环体极轻，72MHz 下约 100ns/次，50000 次 ≈ 5ms。App 按下方向键后 5ms 内若无下一条指令，小车立即停止，遥控无法正常工作。

**修复**：按设计文档实现 SysTick 毫秒计时。`delay.c` 在无 OS 模式下 SysTick 为查询模式，不开中断，需单独添加 `SysTick_Handler`。

```c
// usart.c 或 main.c 顶部
volatile u32 bt_tick = 0;

// 在 SysTick_Handler 中自增（需在 delay_init 后开启 SysTick 中断）
void SysTick_Handler(void) { bt_tick++; }

// main.c 超时检查
#define BT_TIMEOUT_MS 500
static u32 last_rx_tick = 0;

// 收到完整帧时：last_rx_tick = bt_tick;
// 超时检查：if (bt_tick - last_rx_tick > BT_TIMEOUT_MS) driving_state_stop();
```

**注意**：`delay_init()` 使用 HCLK/8 作为 SysTick 时钟源，开启 SysTick 中断后 `delay_us/delay_ms` 的查询逻辑不受影响，但需确认 `SysTick->LOAD` 设置为 9000（72MHz/8=9MHz，9MHz/1000=9000 计数/ms）。
