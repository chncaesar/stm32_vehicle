#include "tracking.h"
#include "motor_drive.h"

/*
 *	红外循迹驱动文件
 */
extern void led_beep_switch(u8 value);

char state_value = 0;//记录当前状态值，初始值默认为停止状态

//相关GPIO初始化
void tracking_init(void)
{
	GPIO_InitTypeDef  GPIO_InitStructure;
	RCC_APB2PeriphClockCmd(RCC_APB2Periph_GPIOA, ENABLE);
	
  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_13;   			//配置使能GPIO管脚
	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_IPU;			//配置GPIO模式,输入上拉
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz; //配置GPIO端口速度
	GPIO_Init(GPIOA , &GPIO_InitStructure); 
	
	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_14;					//配置使能GPIO管脚
	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_IPU;			//配置GPIO模式,输入上拉
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;	//配置GPIO端口速度
	GPIO_Init(GPIOA , &GPIO_InitStructure); 
}

//两路循迹
//循迹行车状态处理函数
void tracking_mode(void)
{
	if(left_tracking == 0 && right_tracking == 0){
		driving_state_run(90,1);//前进
	}
	else if(left_tracking == 1 && right_tracking == 0){
			driving_state_spin_right(65,10);//右旋转
    	led_beep_switch(1);						 //声光提示
//		driving_state_spin_left(65,10);//左旋转
//		led_beep_switch(1);						//声光提示
	}
	else if(right_tracking == 1 & left_tracking == 0){
				driving_state_spin_left(65,10);//左旋转
		led_beep_switch(1);						//声光提示
//		driving_state_spin_right(65,10);//右旋转
//		led_beep_switch(1);						 //声光提示
	}
	else {
		driving_state_stop(10);//停止
	}
}





