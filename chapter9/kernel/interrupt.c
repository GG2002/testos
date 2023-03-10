#include "interrupt.h"
#include "stdint.h"
#include "global.h"
#include "io.h"
#include "print.h"

#define IDT_DESC_CNT 0x21
#define PIC_M_CTRL 0x20
#define PIC_M_DATA 0x21
#define PIC_S_CTRL 0xa0
#define PIC_S_DATA 0xa1

#define EFLAGS_IF 0x00000200    //eflags寄存器中的if位为1
#define GET_EFLAGS(EFLAG_VAR) asm volatile("pushfl;popl %0":"=g"(EFLAG_VAR))

// 中断门描述符结构体
struct gate_desc
{
    uint16_t func_offset_low_word;
    uint16_t selector;
    uint8_t dcount; // 双字计数字段，门描述符的第4字节，固定值，无需考虑
    uint8_t attribute;
    uint16_t func_offset_high_word;
};

//静态函数声明，为加快速度，舍弃一定存储空间，非必须
static void make_idt_desc(struct gate_desc *p_gdesc, uint8_t attr, intr_handler function);
static struct gate_desc idt[IDT_DESC_CNT];
extern intr_handler intr_entry_table[IDT_DESC_CNT];
//用于保存异常的名字
char* intr_name[IDT_DESC_CNT];
//只是中断处理程序的入口，最终调用的是ide_table中的处理程序
intr_handler idt_table[IDT_DESC_CNT];

// 创建中断门描述符
static void make_idt_desc(struct gate_desc *p_gdesc, uint8_t attr, intr_handler function)
{
    p_gdesc->func_offset_low_word = (uint32_t)function & 0x0000FFFF;
    p_gdesc->dcount=0;
    p_gdesc->attribute=attr;
    p_gdesc->selector=SELECTOR_K_CODE;
    p_gdesc->func_offset_high_word = ((uint32_t)function & 0x0000FFFF) >> 16;
}
// 初始化中断描述符表
static void idt_desc_init(void){
    int i;
    for (i=0;i<IDT_DESC_CNT;i++){
        make_idt_desc(&idt[i],IDT_DESC_ATTR_DPL0,intr_entry_table[i]);
    }
    put_str("idt_desc_init done.\n");
}
// 初始化可编程中断控制器8259A
static void pic_init(void){
    outb(PIC_M_CTRL,0x11);
    outb(PIC_M_DATA,0x20);

    outb(PIC_M_DATA,0x04);
    outb(PIC_M_DATA,0x01);
    
    outb(PIC_S_CTRL,0x11);
    outb(PIC_S_DATA,0x28);
    
    outb(PIC_S_DATA,0x02);
    outb(PIC_S_DATA,0x01);

    outb(PIC_M_DATA,0xfe);
    outb(PIC_S_DATA,0xff);

    put_str("pic_init done.\n");
}
// 通用的中断处理函数
static void general_intr_handler(uint8_t vec_nr){
    if (vec_nr == 0x27||vec_nr==0x2f){
        //IRQ7和IRQ15会产生伪中断，无需处理
        //0x2f是从片8259A上最后一个IRQ引脚，也无需处理
        return;
    }

    set_cursor(0);
    int cursor_pos=0;
    while (cursor_pos<480)
    {
        put_char(' ');
        cursor_pos++;
    }

    set_cursor(0);
    put_str("!!!!!!    excetion meassage begin    !!!!!!\n");
    put_str("int vector:0x");
    put_int(vec_nr);
    set_cursor(160);
    put_str(intr_name[vec_nr]);
    if(vec_nr==0xe){
        // 若为Pagefault，将缺失的地址打印出来并悬停
        int page_fault_vaddr=0;
        asm("movl %%cr2,%0":"=r"(page_fault_vaddr));        // cr2是存放page_fault的地址
        put_str("\npage fault addr is ");put_int(page_fault_vaddr);
    }
    put_str("\n!!!!!!    excetion meassage end    !!!!!!\n");
    while (1);
    
}
// 完成一般中断处理函数注册及异常名称注册
static void exception_init(void){
    int i;
    for(i=0;i<IDT_DESC_CNT;i++){
        // idt_table数组中的函数是在进入中断后根据中断向量号调用的
        idt_table[i]=general_intr_handler;
        intr_name[i]="unknown";
    }
    intr_name[0] = "#DE Divide Error";
    intr_name[1] = "#DB Debug Exception";
    intr_name[2] = "NMI Interrupt";
    intr_name[3] = "#BP Breakpoint Exception";
    intr_name[4] = "#OF Overflow Exception";
    intr_name[5] = "#BR BOUND Range Exceeded Exception";
    intr_name[6] = "#UD Invalid Opcode Exception";
    intr_name[7] = "#NM Device Not Available Exception";
    intr_name[8] = "#DF Double Fault Exception";
    intr_name[9] = "Coprocessor Segment Overrun";
    intr_name[10] = "#TS Invalid TSS Exception";
    intr_name[11] = "#NP Segment Not Present";
    intr_name[12] = "#SS Stack Fault Exception";
    intr_name[13] = "#GP General Protection Exception";
    intr_name[14] = "#PF Page-Fault Exception";
    intr_name[16] = "#MF 0x87 FPU Floating-Point Error";
    intr_name[17] = "#AC Alignment Check Exception";
    intr_name[18] = "#MC Machine-Check Exception";
    intr_name[19] = "#XF SIMD Floating-Point Exception";
}
// 完成有关中断的所有初始化工作
void idt_init(){
    put_str("idt_init start.\n");
    idt_desc_init();                // 初始化中断描述符表
    exception_init();               // 异常名初始化并注册通常的中断处理函数
    pic_init();                     // 初始化8259A

    // 加载IDT
    uint64_t idt_operand=((sizeof(idt) - 1) | ((uint64_t)((uint32_t)idt<<16)));
    asm volatile("lidt %0"::"m"(idt_operand));
    put_str("idt_init done.\n");
}

//开中断并返回中断前的状态
enum intr_status intr_enable(void){
    enum intr_status old_status;
    if(INTR_ON==intr_get_status()){
        old_status=INTR_ON;
    }else{
        old_status=INTR_OFF;
        asm volatile("sti");
    }
    return old_status;
}
//关中断并返回中断前的状态
enum intr_status intr_disable(void){
    enum intr_status old_status;
    if(INTR_OFF==intr_get_status()){
        old_status=INTR_OFF;
    }else{
        old_status=INTR_ON;
        asm volatile("cli":::"memory");
    }
    return old_status;
}
//将中断状态设置为status
enum intr_status intr_set_status(enum intr_status status){
    return status & INTR_ON ?intr_enable():intr_disable();
}
enum intr_status intr_get_status(){
    uint32_t eflags=0;
    GET_EFLAGS(eflags);
    return (EFLAGS_IF&eflags)?INTR_ON:INTR_OFF;
}

// 在中断处理程序数组第vector_no个元素中，注册安装中断处理程序
void register_handler(uint8_t vector_no,intr_handler function){
    idt_table[vector_no]=function;
}