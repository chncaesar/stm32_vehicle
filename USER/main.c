#include "sys.h"
#include "delay.h"
#include "usart.h"
#include "led.h"
#include "motor_drive.h"
#include "key.h"
#include "beep.h"
#include "string.h"
#include <stdio.h>

static signed char current_speed = 50;

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
	u32 no_data_count = 0;

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
		if (USART_RX_STA & 0x8000) {
			no_data_count = 0;
			bluetooth_cmd_parse();
		} else {
			no_data_count++;
			if (no_data_count > 50000) {
				driving_state_stop();
				no_data_count = 50000;
			}
		}
	}
}
