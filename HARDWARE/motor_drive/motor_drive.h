#ifndef __MOTOR_DRIVE_H_
#define __MOTOR_DRIVE_H_
#include "sys.h"

// L298N 方向控制引脚（通过位带宏操作）
#define L298N_IN1 PBout(10) // 左电机正转
#define L298N_IN2 PCout(2)  // 左电机反转
#define L298N_IN3 PBout(12) // 右电机正转
#define L298N_IN4 PBout(13) // 右电机反转

void TIM4_PWM_Init(unsigned short arr, unsigned short psc);
void Left_motor_speed_control(signed char speed);
void Right_motor_speed_control(signed char speed);
void driving_state_run(signed char speed);
void driving_state_stop(void);
void driving_state_left(signed char speed);
void driving_state_spin_left(signed char speed);
void driving_state_right(signed char speed);
void driving_state_spin_right(signed char speed);
void driving_state_back(signed char speed);

#endif
