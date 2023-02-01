#include "process.h"

extern void intr_exit(void);

void start_process(void* filename_){
    void* function=filename_;
    struct task_struct* cur=running_thread();
    cur->self_kstack+=sizeof(struct thread_stack);
    struct intr_stack* proc_stack=(struct intr_stack*)cur->self_kstack;
    proc_stack->edi=proc_stack->esi=proc_stack->ebp=proc_stack->esp_dummy=0;
    proc_stack->ebx=proc_stack->edx=proc_stack->ecx=proc_stack->eax=0;
    proc_stack->gs=0
    proc_stack->ds=proc_stack->es=proc_stack->fs=SELECTOR_U_DATA;
    proc_stack->eip=function;
    proc_stack->cs=SELECTOR_U_CODE;
    proc_stack->eflags=(EFLAGS_IOPL_0|EFLAGS_MBS|EFLAGS_IF_1);
    proc_stack->esp=(void*)((uint32_t)get_a_page(PF_USER,USER_STACK3_VADDR)+PG_SIZE);
    proc_sack->ss=SELECTOR_U_DATA;
    asm volatile("movl %0,%%esp;jmp intr_exit"::"g"(proc_stack):"memory");
}

// 激活页表
void page_dir_activate(struct task_struct* pthread){
    // 执行此函数时，当前任务可能是线程，之所以对线程也要重新安装页表
    // 原因是上一次被调度的可能是进程，否则不恢复页表的话，线程就会使用进程的页表了

    // 若为内核线程，需要重新填充页表为0x100000
    uint32_t pagedir_phy_addr=0x100000;
    if(pthread->pgdir!=NULL){   
        // 用户态进程有自己的页目录表
        pagedir_phy_addr=addr_v2p((uint32_t)pthread->pgdir);
    }
    asm volatile("movl%0,%%cr3"::"r"(pagedir_phy_addr):"memory");
}

// 激活线程或进程的页表，更新tss中的esp0为进程的特权级0的栈
void procss_activate(struct task_struct* pthread){
    ASSERT(pthread!=NULL);
    page_dir_activate(pthread);
    if(pthread->pgdir){
        update_tss_esp(pthread);
    }
}