# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context

Current development decisions, hardware details, protocol, and TODO list are maintained in:
**[docs/project_context.md](docs/project_context.md)**

Read this file first before making any changes to firmware or iOS app code.

## Project Overview

STM32 smart car (智能小车) firmware for STM32F103RC, built with the STM32 Standard Peripheral Library and Keil MDK (uVision). The car supports **Bluetooth remote control only** via an HM-10 BLE module (USART1). Line tracking and obstacle avoidance modules have been removed. An iOS companion app (`ios_app/STM32Car/`) communicates over BLE 4.0.

## Build

This is a Keil MDK project. The project file is `USER/STM32智能小车.uvprojx`. Build via Keil uVision IDE or command line:

```
"C:\Keil_v5\UV4\UV4.exe" -b "USER\STM32智能小车.uvprojx" -o build_log.txt
```

Target MCU: STM32F103RC (256KB Flash at 0x08000000, 48KB RAM at 0x20000000). Startup file: `CORE/startup_stm32f10x_hd.s`. Compiler: ARMCC V5.06 (not AC6). MicroLIB must be enabled in Keil target options for `printf` to work via USART1.

Flash programming uses J-Link (configured in `USER/JLinkSettings.ini`). The debug configuration files are in `USER/DebugConfig/`.

## Architecture

```
USER/           - Application entry (main.c), system config, interrupt handlers
HARDWARE/       - Peripheral drivers for the car's hardware modules
  motor_drive/  - L298N dual H-bridge motor control via TIM4 PWM (PB6=ENA, PB9=ENB)
  tracking/     - Empty (module removed)
  obstacle_avoidance/ - Empty (module removed)
  led/          - Status LEDs (LED0=PA8, LED1=PC3)
  beep/         - Buzzer (PC4)
  key/          - Push button input (KEY0=PC5, KEY1=PA15, WK_UP=PA0)
SYSTEM/         - Low-level system utilities (delay, USART1 printf redirect, bit-band GPIO)
CORE/           - CMSIS core (core_cm3, startup)
STM32F10x_FWLib/ - ST Standard Peripheral Library
OBJ/            - Build output (hex, axf, object files)
ios_app/        - iOS BLE remote control app (Swift/SwiftUI, Xcode)
```

## Key Design Decisions

- GPIO is controlled via bit-band addressing macros (`PBout(n)`, `PAin(n)` etc.) defined in `SYSTEM/sys/sys.h`. These map directly to hardware registers and are used throughout HARDWARE drivers as single-bit aliases (e.g. `L298N_IN1`, `BEEP`, `LED1`).
- Motor speed is 0–100 mapped to PWM duty cycle on TIM4 CH1 (left) and CH4 (right), with ARR=7199 (10kHz PWM at 72MHz). The formula is `pwm = 7201 - fabs(speed)*72`. Direction is set by the IN1–IN4 GPIO lines before calling the speed functions. Motor state functions execute immediately (no blocking delay).
- Bluetooth control uses USART1 (PA9/PA10) at 9600 baud connected to HM-10 (BLE 4.0). The main loop polls `USART_RX_STA & 0x8000` for a complete frame (terminated by `\r\n`), then dispatches to motor functions. A 500ms inactivity timeout (`bt_tick - last_rx_tick > BT_TIMEOUT_MS`) stops the car automatically.
- `bt_tick` is a `volatile u32` incremented every 1ms by `SysTick_Handler` in `main.c`. SysTick is configured with LOAD=8999 and clock source HCLK/8 (9MHz), giving exactly 1ms per tick. **Important:** `delay_ms()` (non-OS path) overwrites SysTick->CTRL and clears the TICKINT bit, stopping `bt_tick`. After any call to `delay_ms()`, SysTick must be reconfigured: call `SysTick_CLKSourceConfig(SysTick_CLKSource_HCLK_Div8)` then set LOAD/VAL/CTRL. Omitting the clock source call causes HCLK (72MHz) to be used instead of HCLK/8, making bt_tick run 8× fast and the timeout fire at ~62ms instead of 500ms.
- `delay_ms()` is a blocking SysTick-based delay (HCLK/8 clock source, non-OS path). It overwrites SysTick->CTRL completely, disabling the TICKINT interrupt. Do not call it in the main loop after initialization.
- USART1 RX uses interrupt-driven buffering (`USART_RX_BUF[200]`, `USART_RX_STA`). Frame end is detected by `\r\n` (0x0D 0x0A); `bit15` of `USART_RX_STA` is set when a complete frame is ready.
- JTAG is disabled at startup (`GPIO_Remap_SWJ_JTAGDisable`) to free PA15 for KEY1. SWD remains active on PA13/PA14. PA13/PA14 are no longer used for tracking sensors (module removed) — they are idle GPIO.

## Pin Mapping

Extension board schematic: **[docs/扩展板原理图.png](docs/扩展板原理图.png)**

| Function | Pin |
|----------|-----|
| L298N IN1 (left fwd) | PB10 |
| L298N IN2 (left rev) | PC2 |
| L298N IN3 (right fwd) | PB12 |
| L298N IN4 (right rev) | PB13 |
| L298N ENA (left PWM) | PB6 (TIM4_CH1) |
| L298N ENB (right PWM) | PB9 (TIM4_CH4) |
| Left tracking sensor (removed) | PA13 — idle |
| Right tracking sensor (removed) | PA14 — idle |
| Left obstacle sensor (removed) | PB14 — idle |
| Right obstacle sensor (removed) | PB15 — idle |
| LED0 | PA8 |
| LED1 | PC3 |
| Buzzer (BEEP) | PC4 |
| KEY0 (mode switch) | PC5 (active-low) |
| KEY1 | PA15 (active-low) |
| WK_UP | PA0 (active-high) |
| USART1 TX (→ HM-10 RXD) | PA9 |
| USART1 RX (← HM-10 TXD) | PA10 |
| HM-10 BLE module | P16 (pin1=VCC 3.3V, pin3=RXD/PA10, pin4=TXD/PA9, pin5=GND) |
| SWD debug (P14) | SWDIO=PA13, SWCLK=PA14, GND=pin4 (no NRST on connector) |
| Serial download (P15) | pin1=RXD, pin2=TXD, pin3=GND |

## Obstacle Avoidance Logic (`HARDWARE/obstacle_avoidance/obstacle_avoidance.c`)

**This module has been removed.** The source files no longer exist. The directory `HARDWARE/obstacle_avoidance/` is empty.

## Notes on Stale OBJ Files

`OBJ/` contains `.d` and `.o` files for modules (`remote`, `usart2`, `server`, `ultrasonic_wave`) that no longer have corresponding source files in the tree. `HARDWARE/tracking/` and `HARDWARE/obstacle_avoidance/` directories exist but are empty — source files were removed when the project was refactored to Bluetooth-only. The Keil project include path still references these empty directories; this is harmless.
