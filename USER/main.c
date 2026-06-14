#include "sys.h"
#include "delay.h"
#include "usart.h"
#include "led.h"
#include "motor_drive.h"
#include "key.h"
#include "beep.h"
#include "string.h"
#include <stdio.h>

#define BT_TIMEOUT_MS  600000   // 调试用：单发一次指令跑 10 分钟，方便万用表测量。排查完改回 500

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
	u8 i;

	last_rx_tick = bt_tick;

	printf("[RX len=%d:", len);
	for (i = 0; i < len && i < 10; i++) {
		printf("%c", USART_RX_BUF[i]);
	}
	printf("]\r\n");

	if (len == 3) {
		if      (strncmp((char*)USART_RX_BUF, "ONA", 3) == 0) { printf("CMD: FWD\r\n"); driving_state_run(current_speed); }
		else if (strncmp((char*)USART_RX_BUF, "ONB", 3) == 0) { printf("CMD: BACK\r\n"); driving_state_back(current_speed); }
		else if (strncmp((char*)USART_RX_BUF, "ONC", 3) == 0) { printf("CMD: LEFT\r\n"); driving_state_left(current_speed); }
		else if (strncmp((char*)USART_RX_BUF, "OND", 3) == 0) { printf("CMD: RIGHT\r\n"); driving_state_right(current_speed); }
		else if (strncmp((char*)USART_RX_BUF, "ONE", 3) == 0) { printf("CMD: STOP\r\n"); driving_state_stop(); }
		else if (strncmp((char*)USART_RX_BUF, "ONF", 3) == 0) { printf("CMD: STOPF\r\n"); driving_state_stop(); }
		else if (USART_RX_BUF[0] == 'O' && USART_RX_BUF[1] == 'N') {
			char c = (char)USART_RX_BUF[2];
			if (c >= '1' && c <= '9') {
				current_speed = 20 + (c - '1') * 10;
				printf("CMD: SPEED=%d\r\n", current_speed);
			}
		}
	} else {
		printf("CMD: BADLEN\r\n");
	}
	USART_RX_STA = 0;
}

int main(void)
{
	delay_init();
	uart_init(9600);

	// 配置 SysTick 为 1ms 中断（HCLK/8 = 9MHz，9000 计数 = 1ms）
	SysTick_CLKSourceConfig(SysTick_CLKSource_HCLK_Div8);
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
	SysTick_CLKSourceConfig(SysTick_CLKSource_HCLK_Div8);
	SysTick->LOAD = 9000 - 1;
	SysTick->VAL  = 0;
	SysTick->CTRL = SysTick_CTRL_TICKINT_Msk | SysTick_CTRL_ENABLE_Msk;
	last_rx_tick = bt_tick;


	while (1) {
		static u32 last_dbg_tick = 0;
		if (USART_RX_STA & 0x8000) {
			bluetooth_cmd_parse();
		}
		if (bt_tick - last_rx_tick > BT_TIMEOUT_MS) {
			driving_state_stop();
		}

		// === 调试：每 10 秒打一次 USART 接收计数器（排查完删除）===
		if (bt_tick - last_dbg_tick > 10000) {
			last_dbg_tick = bt_tick;
			printf("[DBG isr=%u rxne=%u err=%u last=0x%02X sr=0x%04X]\r\n",
			       dbg_isr_count, dbg_rxne_count, dbg_err_count,
			       dbg_last_byte, dbg_last_sr);
		}
	}
}
