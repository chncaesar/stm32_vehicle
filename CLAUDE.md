# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context

Current development decisions, hardware details, protocol, and TODO list are maintained in:
**[docs/project_context.md](docs/project_context.md)**

Read this file first before making any changes to firmware or iOS app code.

## Project Overview

STM32 smart car (智能小车) firmware for STM32F103RC, built with the STM32 Standard Peripheral Library and Keil MDK (uVision). The car supports three driving modes switched via a physical button: forward driving, line tracking, and obstacle avoidance.

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
  tracking/     - IR line-tracking sensors (PA13, PA14)
  obstacle_avoidance/ - IR obstacle sensors (PB14, PB15)
  led/          - Status LEDs (LED0=PA8, LED1=PC3)
  beep/         - Buzzer (PC4)
  key/          - Push button input (KEY0=PC5, KEY1=PA15, WK_UP=PA0)
SYSTEM/         - Low-level system utilities (delay, USART1 printf redirect, bit-band GPIO)
CORE/           - CMSIS core (core_cm3, startup)
STM32F10x_FWLib/ - ST Standard Peripheral Library
OBJ/            - Build output (hex, axf, object files)
```

## Key Design Decisions

- GPIO is controlled via bit-band addressing macros (`PBout(n)`, `PAin(n)` etc.) defined in `SYSTEM/sys/sys.h`. These map directly to hardware registers and are used throughout HARDWARE drivers as single-bit aliases (e.g. `L298N_IN1`, `BEEP`, `LED1`).
- Motor speed is 0–100 mapped to PWM duty cycle on TIM4 CH1 (left) and CH4 (right), with ARR=7199 (10kHz PWM at 72MHz). The formula is `pwm = 7201 - fabs(speed)*72`. Direction is set by the IN1–IN4 GPIO lines before calling the speed functions.
- The mode state machine in `main.c:Driving_mode()` uses a global `key_value` (0=forward, 1=tracking, 2=obstacle avoidance). KEY0 (PC5, active-low) increments the mode; `key_value` wraps from 2 back to 1 (mode 0 is the boot default only). Each mode switch stops the car and blinks the LED/buzzer once.
- Sensor inputs use pull-up (`GPIO_Mode_IPU`). Tracking sensors read 0 when on the line, 1 when off. Obstacle sensors read 1 when clear, 0 when blocked.
- `delay_ms()` is a blocking SysTick-based delay (HCLK/8 clock source). All motor state functions take a `time` parameter in ms and block for that duration — the main loop is entirely polling-based with no interrupts used for control.
- USART1 RX uses interrupt-driven buffering (`USART_RX_BUF[200]`, `USART_RX_STA`). The buffer is populated in `SYSTEM/usart/usart.c` but nothing in the current application reads it.
- JTAG is disabled at startup (`GPIO_Remap_SWJ_JTAGDisable`) to free PA13/PA14 for tracking sensors and PA15 for KEY1. SWD remains active.

## Pin Mapping

| Function | Pin |
|----------|-----|
| L298N IN1 (left fwd) | PB10 |
| L298N IN2 (left rev) | PC2 |
| L298N IN3 (right fwd) | PB12 |
| L298N IN4 (right rev) | PB13 |
| L298N ENA (left PWM) | PB6 (TIM4_CH1) |
| L298N ENB (right PWM) | PB9 (TIM4_CH4) |
| Left tracking sensor | PA13 |
| Right tracking sensor | PA14 |
| Left obstacle sensor | PB14 |
| Right obstacle sensor | PB15 |
| LED0 | PA8 |
| LED1 | PC3 |
| Buzzer (BEEP) | PC4 |
| KEY0 (mode switch) | PC5 (active-low) |
| KEY1 | PA15 (active-low) |
| WK_UP | PA0 (active-high) |
| USART1 TX | PA9 |
| USART1 RX | PA10 |

## Obstacle Avoidance Logic (`HARDWARE/obstacle_avoidance/obstacle_avoidance.c`)

Sensors: left=PB14, right=PB15, both configured as pull-up input (`GPIO_Mode_IPU`).
Signal polarity: **1 = clear, 0 = obstacle detected**.

Decision table for `obstacle_avoidance_mode()`:

| Left (PB14) | Right (PB15) | Action |
|-------------|--------------|--------|
| 1 (clear)   | 1 (clear)    | Forward, speed 90, 1ms |
| 1 (clear)   | 0 (blocked)  | Spin right, speed 70, 200ms + beep |
| 0 (blocked) | 1 (clear)    | Spin left, speed 70, 200ms + beep |
| 0 (blocked) | 0 (blocked)  | Stop 300ms → reverse 1000ms → alternate spin left/right 200ms |

The both-blocked case uses a `static u8 both_blocked_turn` flag that toggles each time, so the car alternates left and right on successive encounters.

Known limitations:
- **Forward time is only 1ms** per loop iteration — effective forward speed is lower than the 90% setting due to function call overhead.
- **Turn duration is fixed at 200ms** regardless of obstacle distance, so the car may over- or under-correct.
- Commented-out lines in the source swap spin direction (left↔right) for the single-side cases — if the car turns the wrong way on hardware, toggle those comments.

## Notes on Stale OBJ Files

`OBJ/` contains `.d` and `.o` files for modules (`remote`, `usart2`, `server`, `ultrasonic_wave`) that no longer have corresponding source files in the tree. These are leftover build artifacts from a previous version of the project and can be ignored or cleaned.
