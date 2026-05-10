#include "obstacle_avoidance.h"
#include "motor_drive.h"

extern void led_beep_switch(u8 value);

static u8 both_blocked_turn = 0; // 0=左转, 1=右转，两侧都有障碍时交替切换

// 传感器GPIO初始化
void obstacle_avoidance_init(void)
{
	GPIO_InitTypeDef  GPIO_InitStructure;
	RCC_APB2PeriphClockCmd(RCC_APB2Periph_GPIOB, ENABLE);

	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_14;        // 左传感器 PB14
	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_IPU;     // 上拉输入
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
	GPIO_Init(GPIOB, &GPIO_InitStructure);

	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_15;        // 右传感器 PB15
	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_IPU;     // 上拉输入
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
	GPIO_Init(GPIOB, &GPIO_InitStructure);
}

// 避障行驶状态决策函数
// 传感器信号: 1=畅通, 0=检测到障碍
void obstacle_avoidance_mode(void)
{
	if(left_obstacle_avoidance == 1 && right_obstacle_avoidance == 1)
	{
		driving_state_run(90, 1);           // 两侧畅通，前进	
	}
	else if(left_obstacle_avoidance == 1 && right_obstacle_avoidance == 0)
	{
		driving_state_spin_right(70, 200);  // 右侧有障碍，原地右转
		led_beep_switch(1);
	}
	else if(right_obstacle_avoidance == 1 && left_obstacle_avoidance == 0)
	{
		driving_state_spin_left(70, 200);   // 左侧有障碍，原地左转
		led_beep_switch(1);
	}
	else
	{
		driving_state_stop(300);            // 两侧都有障碍：停车
		led_beep_switch(1);
		driving_state_back(70, 1000);       // 后退
		if(both_blocked_turn == 0){
			driving_state_spin_left(70, 200);   // 偶数次：左转
		} else {
			driving_state_spin_right(70, 200);  // 奇数次：右转
		}
		both_blocked_turn = !both_blocked_turn; // 下次换方向
	}
}
