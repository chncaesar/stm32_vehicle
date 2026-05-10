#ifndef __MOTOR_DRIVE_H_
#define __MOTOR_DRIVE_H_
#include "sys.h"

// L298N 方向控制引脚（通过位带宏操作）
#define L298N_IN1 PBout(10) // 左电机正转
#define L298N_IN2 PCout(2)  // 左电机反转
#define L298N_IN3 PBout(12) // 右电机正转
#define L298N_IN4 PBout(13) // 右电机反转

void TIM4_PWM_Init(unsigned short arr, unsigned short psc); // TIM4 PWM 初始化
void Left_motor_speed_control(signed char speed);           // 左电机速度控制 (0~100)
void Right_motor_speed_control(signed char speed);          // 右电机速度控制 (0~100)
void driving_state_run(signed char speed, int time);        // 前进
void driving_state_stop(int time);                          // 停止
void driving_state_left(signed char speed, int time);       // 左转（左轮停）
void driving_state_spin_left(signed char speed, int time);  // 原地左转
void driving_state_right(signed char speed, int time);      // 右转（右轮停）
void driving_state_spin_right(signed char speed, int time); // 原地右转
void driving_state_back(signed char speed, int time);       // 后退

#endif
