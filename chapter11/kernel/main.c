#include "print.h"
#include "init.h"
#include "debug.h"
#include "memory.h"
#include "thread.h"
#include "interrupt.h"
#include "console.h"
#include "ioqueue.h"
#include "keyboard.h"

void k_thread_a(void*);
void k_thread_b(void*);

int main(void)
{
    // 这里不能使用console_put_str，因为还没有初始化
    put_str("OPSM.\n");
    init_all();
    
    thread_start("k_thread_a",31,k_thread_a,"argA ");
    thread_start("k_thread_b",8,k_thread_b,"argB ");

    intr_enable();

    while(1);
    return 0;
}

void k_thread_a(void* arg){
    char* para=arg;
    while(1){
        enum intr_status old_status=intr_disable();
        if (!ioq_empty(&kbd_buf)){
            console_put_str(para);
            char byte=ioq_getchar(&kbd_buf);
            console_put_char(byte);
        }
        intr_set_status(old_status);
    }
}

void k_thread_b(void* arg){
    char* para=arg;
    while(1){
        enum intr_status old_status=intr_disable();
        if (!ioq_empty(&kbd_buf)){
            console_put_str(para);
            char byte=ioq_getchar(&kbd_buf);
            console_put_char(byte);
        }
        intr_set_status(old_status);
    }
}