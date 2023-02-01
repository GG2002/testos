#include "timer.h"
#include "io.h"
#include "print.h"
#include "debug.h"
#include "thread.h"
#include "interrupt.h"

#define IRQ0_FREQUENCY 100
#define INPUT_FREQUENCY 1193180
#define COUNTER0_VALUE INPUT_FREQUENCY/IRQ0_FREQUENCY
#define COUNTER0_PORT 0x40
#define COUNTER0_NO 0
#define COUNTER0_MODE 2
#define READ_WRITE_LATCH 3
#define PIT_CONTROL_PORT 0x43
uint32_t ticks;                 // 内核自中断开启以来总共的嘀嗒数

static void frequency_set(uint8_t counter_port,uint8_t counter_no,uint8_t rwl,uint8_t counter_mode,uint16_t counter_value){
    // 往0x43中写入控制字
    outb(PIT_CONTROL_PORT,(uint8_t)(counter_no<<6|rwl<<4|counter_mode<<1));
    // 先写入counter_value低8位
    outb(counter_port,(uint8_t)counter_value);
    // 再写入counter_value高8位
    outb(counter_port,(uint8_t)(counter_value>>8));
}

static void intr_timer_handler(void){
    struct task_struct* cur_thread=running_thread();
    ASSERT(cur_thread->stack_magic==0x19870916);
    cur_thread->elapsed_ticks++;
    ticks++;

    if(cur_thread->ticks==0){
        schedule();
    }else{
        cur_thread->ticks--;
    }
}

void timer_init(void){
    put_str("timer_init start.\n");
    frequency_set(COUNTER0_PORT,COUNTER0_NO,READ_WRITE_LATCH,COUNTER0_MODE,COUNTER0_VALUE);
    register_handler(0x20,intr_timer_handler);
    put_str("timer_init done.\n");
}