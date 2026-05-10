#include "motor_drive.h"
#include <math.h>
#include "delay.h"

// TIM4 PWM 及电机方向 GPIO 初始化
// arr: 自动重装值, psc: 预分频值
void TIM4_PWM_Init(unsigned short arr, unsigned short psc)
{
	TIM_TimeBaseInitTypeDef TIM_TimeBaseStructure;
	TIM_OCInitTypeDef       TIM_OCInitStructure;
	GPIO_InitTypeDef        GPIO_InitStructure;

	RCC_APB1PeriphClockCmd(RCC_APB1Periph_TIM4, ENABLE);
	RCC_APB2PeriphClockCmd(RCC_APB2Periph_GPIOB | RCC_APB2Periph_GPIOC, ENABLE);

	// L298N_IN1 — 左电机正转 PB10
	GPIO_InitStructure.GPIO_Pin   = GPIO_Pin_10;
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
	GPIO_InitStructure.GPIO_Mode  = GPIO_Mode_Out_PP;
	GPIO_Init(GPIOB, &GPIO_InitStructure);

	// L298N_IN2 — 左电机反转 PC2
	GPIO_InitStructure.GPIO_Pin   = GPIO_Pin_2;
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
	GPIO_InitStructure.GPIO_Mode  = GPIO_Mode_Out_PP;
	GPIO_Init(GPIOC, &GPIO_InitStructure);

	// L298N_IN3 — 右电机正转 PB12
	GPIO_InitStructure.GPIO_Pin   = GPIO_Pin_12;
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
	GPIO_InitStructure.GPIO_Mode  = GPIO_Mode_Out_PP;
	GPIO_Init(GPIOB, &GPIO_InitStructure);

	// L298N_IN4 — 右电机反转 PB13
	GPIO_InitStructure.GPIO_Pin   = GPIO_Pin_13;
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
	GPIO_InitStructure.GPIO_Mode  = GPIO_Mode_Out_PP;
	GPIO_Init(GPIOB, &GPIO_InitStructure);

	// L298N_ENA — 左电机 PWM 使能 PB6 (TIM4_CH1)
	GPIO_InitStructure.GPIO_Pin   = GPIO_Pin_6;
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
	GPIO_InitStructure.GPIO_Mode  = GPIO_Mode_AF_PP; // 复用推挽输出
	GPIO_Init(GPIOB, &GPIO_InitStructure);

	// L298N_ENB — 右电机 PWM 使能 PB9 (TIM4_CH4)
	GPIO_InitStructure.GPIO_Pin   = GPIO_Pin_9;
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
	GPIO_InitStructure.GPIO_Mode  = GPIO_Mode_AF_PP; // 复用推挽输出
	GPIO_Init(GPIOB, &GPIO_InitStructure);

	// TIM4 时基配置 — 72MHz / (psc+1) / (arr+1) = PWM频率
	TIM_TimeBaseStructure.TIM_Period        = arr;
	TIM_TimeBaseStructure.TIM_Prescaler     = psc;
	TIM_TimeBaseStructure.TIM_ClockDivision = 0;
	TIM_TimeBaseStructure.TIM_CounterMode   = TIM_CounterMode_Up;
	TIM_TimeBaseInit(TIM4, &TIM_TimeBaseStructure);

	// PWM 模式2，初始占空比为0
	TIM_OCInitStructure.TIM_OCMode      = TIM_OCMode_PWM2;
	TIM_OCInitStructure.TIM_OutputState = TIM_OutputState_Enable;
	TIM_OCInitStructure.TIM_Pulse       = 0;
	TIM_OCInitStructure.TIM_OCPolarity  = TIM_OCPolarity_High;
	TIM_OC1Init(TIM4, &TIM_OCInitStructure); // CH1 — 左电机
	TIM_OC4Init(TIM4, &TIM_OCInitStructure); // CH4 — 右电机

	TIM_CtrlPWMOutputs(TIM4, ENABLE);
	TIM_OC1PreloadConfig(TIM4, TIM_OCPreload_Enable);
	TIM_OC4PreloadConfig(TIM4, TIM_OCPreload_Enable);
	TIM_ARRPreloadConfig(TIM4, ENABLE);
	TIM_Cmd(TIM4, ENABLE);
}

// 左电机速度控制
// speed: 0~100，映射到 PWM 占空比
void Left_motor_speed_control(signed char speed)
{
	short pwm;
	if(speed >= 100) speed = 100;
	pwm = 7201 - (short)(fabs(speed) * 72);
	TIM_SetCompare1(TIM4, pwm);
}

// 右电机速度控制
// speed: 0~100，映射到 PWM 占空比
void Right_motor_speed_control(signed char speed)
{
	short pwm;
	if(speed >= 100) speed = 100;
	pwm = 7201 - (short)(fabs(speed) * 72);
	TIM_SetCompare4(TIM4, pwm);
}

// 前进
void driving_state_run(signed char speed, int time)
{
	L298N_IN1 = 0; L298N_IN2 = 1; // 左电机正转
	L298N_IN3 = 1; L298N_IN4 = 0; // 右电机正转
	Left_motor_speed_control(speed);
	Right_motor_speed_control(speed);
	delay_ms(time);
}

// 停止
void driving_state_stop(int time)
{
	L298N_IN1 = 0; L298N_IN2 = 0; // 左电机停
	L298N_IN3 = 0; L298N_IN4 = 0; // 右电机停
	Left_motor_speed_control(0);
	Right_motor_speed_control(0);
	delay_ms(time);
}

// 左转（左轮停，右轮转）
void driving_state_left(signed char speed, int time)
{
	L298N_IN1 = 0; L298N_IN2 = 0; // 左电机停
	L298N_IN3 = 1; L298N_IN4 = 0; // 右电机正转
	Left_motor_speed_control(0);
	Right_motor_speed_control(speed);
	delay_ms(time);
}

// 原地左转（左轮反转，右轮正转）
void driving_state_spin_left(signed char speed, int time)
{
	L298N_IN1 = 1; L298N_IN2 = 0; // 左电机反转
	L298N_IN3 = 1; L298N_IN4 = 0; // 右电机正转
	Left_motor_speed_control(speed);
	Right_motor_speed_control(speed);
	delay_ms(time);
}

// 右转（左轮转，右轮停）
void driving_state_right(signed char speed, int time)
{
	L298N_IN1 = 0; L298N_IN2 = 1; // 左电机正转
	L298N_IN3 = 0; L298N_IN4 = 0; // 右电机停
	Left_motor_speed_control(speed);
	Right_motor_speed_control(0);
	delay_ms(time);
}

// 原地右转（左轮正转，右轮反转）
void driving_state_spin_right(signed char speed, int time)
{
	L298N_IN1 = 0; L298N_IN2 = 1; // 左电机正转
	L298N_IN3 = 0; L298N_IN4 = 1; // 右电机反转
	Left_motor_speed_control(speed);
	Right_motor_speed_control(speed);
	delay_ms(time);
}

// 后退
void driving_state_back(signed char speed, int time)
{
	L298N_IN1 = 1; L298N_IN2 = 0; // 左电机反转
	L298N_IN3 = 0; L298N_IN4 = 1; // 右电机反转
	Left_motor_speed_control(speed);
	Right_motor_speed_control(speed);
	delay_ms(time);
}
