#ifndef __OBSTACLE_AVOIDANCE_H_
#define __OBSTACLE_AVOIDANCE_H_
#include "sys.h"

/*
 *	红外避障驱动头文件
 */

void obstacle_avoidance_init(void);//相关GPIO初始化
void obstacle_avoidance_mode(void);//避障行车状态处理函数

//右避障
#define right_obstacle_avoidance		GPIO_ReadInputDataBit(GPIOB, GPIO_Pin_15)
//左避障
#define left_obstacle_avoidance			GPIO_ReadInputDataBit(GPIOB, GPIO_Pin_14)

#endif
