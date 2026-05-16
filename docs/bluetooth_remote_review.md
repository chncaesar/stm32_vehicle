# 蓝牙遥控模块 Code Review 检查点

## 1. 串口配置

- [ ] `uart_init(9600)` 波特率与 HM-10 默认波特率一致
- [ ] USART1 RX 中断已启用（`USART_IT_RXNE`）
- [ ] 中断优先级配置正确，不与其他中断冲突
- [ ] `USART_RX_BUF` 和 `USART_RX_STA` 在中断和主循环间共享，访问前需确认不会被中断打断导致数据撕裂

## 2. 指令解析

- [ ] 收到完整帧标志位 `USART_RX_STA & 0x8000` 判断正确
- [ ] 解析前检查帧长度为 3 字节，防止短帧误匹配
- [ ] 所有指令分支覆盖完整：ONA / ONB / ONC / OND / ONE / ONF / ON1~ON9
- [ ] 解析完成后 `USART_RX_STA = 0` 清空缓冲区，防止重复处理
- [ ] 速度映射范围正确：ON1~ON9 → 20~100，不超出电机速度上限 100

## 3. 运动函数

- [ ] 所有运动函数已去掉 `delay_ms(time)` 阻塞，改为立即返回
- [ ] `driving_state_stop()` 同时将 PWM 占空比置 0，电机完全停转
- [ ] 左右电机方向 GPIO（IN1~IN4）在每次运动函数调用时都重新设置，不依赖上次状态
- [ ] `Left_motor_speed_control` / `Right_motor_speed_control` 速度参数边界处理正确（speed >= 100 截断）

## 4. 断连超时

- [ ] `bt_tick` 毫秒计数器在 SysTick 中断中正确自增
- [ ] `last_rx_tick` 在每次成功解析到完整帧后更新
- [ ] 超时阈值 500ms 合理，不会因正常指令间隔触发误停车
- [ ] 上电初始状态：`last_rx_tick` 初始值设置合理，避免上电瞬间误判超时

## 5. 主循环

- [ ] 主循环只调用 `bluetooth_cmd_parse()` 和 `bluetooth_timeout_check()`，无多余阻塞
- [ ] 删除了 `Driving_mode()`、`tracking_mode()`、`obstacle_avoidance_mode()` 的调用
- [ ] 删除了 `key_value` 状态机相关代码
- [ ] `uart_init` 在 `TIM4_PWM_Init` 之前调用，初始化顺序正确

## 6. 删除的模块

- [ ] `tracking.c / tracking.h` 已从 Keil 工程中移除
- [ ] `obstacle_avoidance.c / obstacle_avoidance.h` 已从 Keil 工程中移除
- [ ] `main.c` 中对应的 `#include` 已删除
- [ ] Keil 工程编译无 warning（未使用的变量/函数）

## 7. 安全行为

- [ ] 上电后小车默认停止状态，不会自动运动
- [ ] 蓝牙未连接时（超时）小车保持停止
- [ ] 收到 `ONF`（松开）指令立即停车，响应及时
- [ ] 异常指令（非 ON 开头、长度不为 3）不触发任何运动，静默丢弃
