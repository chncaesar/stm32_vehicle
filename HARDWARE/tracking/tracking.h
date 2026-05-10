#ifndef __TRACKING_H_
#define __TRACKING_H_
#include "sys.h"

/*
 *	红外循迹驱动头文件
 */

void tracking_init(void);//相关GPIO初始化
void tracking_mode(void);//循迹行车状态处理函数

//右循迹
#define right_tracking		GPIO_ReadInputDataBit(GPIOA, GPIO_Pin_14)
//左循迹
#define left_tracking			GPIO_ReadInputDataBit(GPIOA, GPIO_Pin_13)

#endif
