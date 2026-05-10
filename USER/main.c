/*
STM32����С������ ���Ű�
	*/
	
#include "sys.h"
#include "delay.h"							//��ʱ�����ļ�
#include "usart.h"							//����1�����ļ�
#include "led.h"								//LED�������ļ�
#include "motor_drive.h"				//��������ļ�
#include "key.h"								//���������ļ�
#include "obstacle_avoidance.h"	//������������ļ�
#include "tracking.h"						//����ѭ�������ļ�
#include "string.h"	 						//���ô�ͷ�ļ�����ʹ��strcmp
#include "beep.h"								//�����������ļ�
#include <stdio.h>

/* �г�ģʽ�궨�� */
#define	MODE0		0	 // ģʽ0
#define MODE1   1  // ģʽ1
#define MODE2   2  // ģʽ2


unsigned char key_value = 2;
 int object_value, left_value, right_value;

/* 
 * ��������LED�ƿ��ƺ��� 
 * value����������LED�� ��/��˸ ���������255
*/
void led_beep_switch(u8 value)
{
	u8 i;
	for(i = 0; i < value; i++){
		LED1=0;									//��LED��
		BEEP=0;									//�򿪷�����
		delay_ms(100);					//��ʱ100ms
		LED1=1;									//�ر�LED��
		BEEP=1;									//�رշ�����
		delay_ms(100);					//��ʱ100ms
	}
}	




/* �л��г�ģʽ���� */
void Driving_mode(void)
{
	u8 t=0;	
	t=KEY_Scan(0);										 //�õ���ֵ
	if(t == KEY0_PRES){								 //���ΪKEY0����
		driving_state_stop(500);				 //С��ֹͣ����
		led_beep_switch(1);							 //���������LED��˸ 1��
		key_value++;										 //����ֵ++	
		if(key_value > 2){key_value = 1;}//模式超过2回到模式1
	}
	
	switch(key_value)//�жϵ�ǰ�������µļ�ֵ�����ݼ�ֵ��ת����Ӧ���г�ģʽ
	{
		case MODE0: driving_state_run(90,100);	break;//ǰ����ģʽ0Ϊ����ģʽ��
		case MODE1: tracking_mode();					  break;//����ѭ���г�ģʽ
		case MODE2: obstacle_avoidance_mode();	break;//��������г��г�ģʽ

		default:	break;
	}
}

/* ������ */
int main(void)
{	
	delay_init();							//��ʱ��ʼ��
	uart_init(115200);				//����1��ʼ��Ϊ115200������

             	 

	TIM4_PWM_Init(7199,0);  	//��ʼ��PWM

	LED_Init();								//LED��ʼ��
	BEEP_Init();         			//��ʼ���������˿�
	BEEP=1;										//�رշ�����
	KEY_Init();          			//��ʼ���밴�����ӵ�Ӳ���ӿ�
	tracking_init();					//��ʼ��ѭ��
	obstacle_avoidance_init();//��ʼ������

	driving_state_stop(500);	//����С��Ϊֹͣ״̬����ֹ��ʼ������ܶ�

	led_beep_switch(3);				//�ϵ���������LED�� ��/��˸ 3��
	while(1)
	{  
		Driving_mode();					//ģʽ�л�
	}
}
