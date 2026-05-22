#include "sys.h"
#include "delay.h"
#include "usart.h"
#include "led.h"
#include "motor_drive.h"
#include "key.h"
#include "beep.h"
#include "string.h"
#include <stdio.h>

#define BT_TIMEOUT_MS  500

volatile u32 bt_tick = 0;          // SysTick 每 1ms 自增
static u32   last_rx_tick = 0;
static signed char current_speed = 50;

void SysTick_Handler(void)
{
    bt_tick++;
}

void led_beep_switch(u8 value)
{
	u8 i;
	for (i = 0; i < value; i++) {
		LED1 = 0;
		BEEP = 0;
		delay_ms(100);
		LED1 = 1;
		BEEP = 1;
		delay_ms(100);
	}
}

static void bluetooth_cmd_parse(void)
{
	u8 len = USART_RX_STA & 0x3FFF;
	last_rx_tick = bt_tick;
	if (len == 3) {
		if      (strncmp((char*)USART_RX_BUF, "ONA", 3) == 0) driving_state_run(current_speed);
		else if (strncmp((char*)USART_RX_BUF, "ONB", 3) == 0) driving_state_back(current_speed);
		else if (strncmp((char*)USART_RX_BUF, "ONC", 3) == 0) driving_state_left(current_speed);
		else if (strncmp((char*)USART_RX_BUF, "OND", 3) == 0) driving_state_right(current_speed);
		else if (strncmp((char*)USART_RX_BUF, "ONE", 3) == 0) driving_state_stop();
		else if (strncmp((char*)USART_RX_BUF, "ONF", 3) == 0) driving_state_stop();
		else if (USART_RX_BUF[0] == 'O' && USART_RX_BUF[1] == 'N') {
			char c = (char)USART_RX_BUF[2];
			if (c >= '1' && c <= '9')
				current_speed = 20 + (c - '1') * 10;
		}
	}
	USART_RX_STA = 0;
}

int main(void)
{
	delay_init();
	uart_init(9600);

	// 配置 SysTick 为 1ms 中断（HCLK/8 = 9MHz，9000 计数 = 1ms）
	SysTick->LOAD = 9000 - 1;
	SysTick->VAL  = 0;
	SysTick->CTRL = SysTick_CTRL_TICKINT_Msk | SysTick_CTRL_ENABLE_Msk;

	TIM4_PWM_Init(7199, 0);
	LED_Init();
	BEEP_Init();
	BEEP = 1;
	KEY_Init();

	driving_state_stop();
	led_beep_switch(3);

	// delay_ms() 会关闭 SysTick，重新配置以恢复 1ms 中断
	SysTick->LOAD = 9000 - 1;
	SysTick->VAL  = 0;
	SysTick->CTRL = SysTick_CTRL_TICKINT_Msk | SysTick_CTRL_ENABLE_Msk;
	last_rx_tick = bt_tick;

	while (1) {
		if (USART_RX_STA & 0x8000) {
			bluetooth_cmd_parse();
		}
		if (bt_tick - last_rx_tick > BT_TIMEOUT_MS) {
			driving_state_stop();
		}
	}
}
