#include "print.h"
#include "init.h"
#include "debug.h"
#include "memory.h"
#include "thread.h"
#include "interrupt.h"

void k_thread_a(void*);
void k_thread_b(void*);
int main(void)
{
    put_str("OPSM.\n");
    init_all();
    thread_start("k_thread_a",31,k_thread_a,"A");
    thread_start("k_thread_b",8,k_thread_b,"B");
    intr_enable();
    while (1)
    {
        put_str("M ");
    }
    return 0;
}

void k_thread_a(void* arg){
    char* para=arg;
    while (1)
    {
        put_str(para);
        put_int(running_thread()->ticks);
    }
}

void k_thread_b(void* arg){
    char* para=arg;
    while (1)
    {
        put_str(para);
        put_int(running_thread()->ticks);
    }
}