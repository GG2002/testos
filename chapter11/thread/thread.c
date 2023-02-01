#include "thread.h"
#include "stdint.h"
#include "global.h"
#include "memory.h"
#include "debug.h"
#include "list.h"
#include "string.h"
#include "print.h"
#include "interrupt.h"

#define PG_SIZE 4096

struct task_struct* main_thread;    // 主线程PCB
struct list thread_ready_list;      // 就绪队列
struct list thread_all_list;        // 所有任务队列
static node* thread_tag;             // 用于保存队列中的线程节点

extern void switch_to(struct task_struct* cur,struct task_struct* next);

// 由kernel_thread执行function(func_arg)
static void kernel_thread(thread_func* function,void* func_arg){
    intr_enable();      // 开中断避免无法调度其他线程
    function(func_arg);
}

// 初始化线程基本信息
void init_thread(struct task_struct* pthread, char* name, int prio){
    memset(pthread,0,sizeof(*pthread));
    strcpy(pthread->name,name);

    if(pthread==main_thread){
        pthread->status=TASK_RUNNING;
    }else{
        pthread->status=TASK_READY;
    }
    pthread->priority=prio;
    pthread->ticks=prio;
    pthread->elapsed_ticks=0;
    pthread->pgdir=NULL;
    // self_kstack是线程自己在内核态下使用的栈顶地址
    pthread->self_kstack=(uint32_t*)((uint32_t)pthread+PG_SIZE);
    pthread->stack_magic=0x19870916;        // 自定义的魔数，怎么看都像是作者生日
}

// 初始化线程栈thread_stack
void thread_create(struct task_struct* pthread, thread_func function, void* func_arg){
    pthread->self_kstack-=sizeof(struct intr_stack);
    pthread->self_kstack-=sizeof(struct thread_stack);
    struct thread_stack* kthread_stack=(struct thread_stack*)pthread->self_kstack;
    kthread_stack->eip=kernel_thread;
    kthread_stack->function=function;
    kthread_stack->func_arg=func_arg;
    kthread_stack->ebp=kthread_stack->ebx=0;
    kthread_stack->esi=kthread_stack->edi=0;
}

struct task_struct* thread_start(char* name, int prio, thread_func function,void* func_arg)
{
    struct task_struct* thread=get_kernel_pages(1);
    init_thread(thread,name,prio);
    thread_create(thread,function,func_arg);
    ASSERT(!elem_find(&thread_ready_list,&thread->general_tag));
    list_append(&thread_ready_list,&thread->general_tag);
    ASSERT(!elem_find(&thread_all_list,&thread->all_list_tag));
    list_append(&thread_all_list,&thread->all_list_tag);
    
    return thread;
}

// 获取当前线程pcb指针
struct task_struct* running_thread(){
    uint32_t esp;
    asm("mov %%esp,%0":"=g"(esp));
    return (struct task_struct*)(esp&0xfffff000);
}

static void make_main_thread(void){
    //因为主线程main早已运行，在loader.s中进入内核时的mov esp,0xc009f000就是为其预留PCB的，因此PCB地址为0xc009e000
    main_thread=running_thread();
    init_thread(main_thread,"main",31);
    ASSERT(!elem_find(&thread_all_list,&main_thread->all_list_tag));
    list_append(&thread_all_list,&main_thread->all_list_tag);
}

// 启用调度器
void schedule(){
    ASSERT(intr_get_status()==INTR_OFF);
    struct task_struct* cur=running_thread();
    if(cur->status==TASK_RUNNING){
        ASSERT(!elem_find(&thread_ready_list,&cur->general_tag));
        list_append(&thread_ready_list,&cur->general_tag);
        cur->ticks=cur->priority;
        cur->status=TASK_READY;
    }else{
        // 若此线程不是RUNNING状态则不需要加入就绪队列中
    }

    // 准备将thread_ready_list队列中的第一个就绪线程弹出
    ASSERT(!list_empty(&thread_ready_list));
    thread_tag=NULL;
    thread_tag=list_pop(&thread_ready_list);
    struct task_struct* next=elem2entry(struct task_struct,general_tag,thread_tag);
    next->status=TASK_RUNNING;
    switch_to(cur,next);
}

// 初始化线程环境
void thread_init(void){
    put_str("thread_init start.\n");
    list_init(&thread_ready_list);
    list_init(&thread_all_list);
    make_main_thread();
    put_str("thread_init done.\n");
}

// 当前线程将自己阻塞，标志其状态为stat
void thread_block(enum task_status stat){
    ASSERT(((stat==TASK_WAITING)||(stat==TASK_HANGING)||(stat==TASK_BLOCKED)));
    enum intr_status old_status=intr_disable();
    struct task_struct* cur_thread=running_thread();
    cur_thread->status=stat;
    schedule();
    intr_set_status(old_status);
}

// 将线程pthread解除阻塞
void thread_unblock(struct task_struct* pthread){
    enum intr_status old_status=intr_disable();
    ASSERT(((pthread->status==TASK_WAITING)||(pthread->status==TASK_HANGING)||(pthread->status==TASK_BLOCKED)));
    if(pthread->status!=TASK_READY){
        ASSERT(!elem_find(&thread_ready_list,&pthread->general_tag));
        if(elem_find(&thread_ready_list,&pthread->general_tag)){
            PANIC("thread_unblock:blocked thread in ready_list\n");
        }
        list_push(&thread_ready_list,&pthread->general_tag);
        pthread->status=TASK_READY;
    }
    intr_set_status(old_status);
}