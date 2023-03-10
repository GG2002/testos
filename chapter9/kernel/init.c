#include "init.h"
#include "print.h"
#include "interrupt.h"
#include "timer.h"
#include "memory.h"
#include "thread.h"

//负责初始化所有模块
void init_all(){
    put_str("init_all.\n");
    idt_init();
    mem_init();
    timer_init();
    thread_init();
}