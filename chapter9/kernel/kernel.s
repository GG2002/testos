[bits 32]   

;空声明,不做任何处理
%define ERROR_CODE nop   
;若相关异常中CPU没有压入错误码，为统一栈中格式，手动压入一个0
%define ZERO push 0

extern put_str              ;声明外部put_str
extern idt_table            ;声明外部idt_table

section .data
intr_str db "interrupt occured!",0xa,0  ;0xa为换行，0为c语言风格字符串结尾
global intr_entry_table     ;声明全局中断向量表intr_entry_table
intr_entry_table:

%macro VECTOR 2
section .text
intr%1entry:
    %2
    push ds
    push es
    push fs
    push gs
    pushad                  ;保存上下文环境，pushad依次压入32位寄存器，顺序懒得写了

    ;如果是从片上进入的中断，除了往从片上发送EOI外，还要往主片上发送EOI
    mov al,0x20         ;中断结束命令EOI
    out 0xa0,al         ;向从片发送
    out 0x20,al         ;向主片发送

    push %1             ;不管idt_table的程序代码是否需要中断向量号都压入
    call [idt_table+%1*4]
    jmp intr_exit

section .data
    dd intr%1entry

%endmacro

section .text
global intr_exit
intr_exit:
    ;恢复上下文环境
    add esp,4
    popad
    pop gs
    pop fs
    pop es
    pop ds
    add esp,4
    iretd

VECTOR 0x00, ZERO
VECTOR 0x01, ZERO
VECTOR 0x02, ZERO
VECTOR 0x03, ZERO
VECTOR 0x04, ZERO
VECTOR 0x05, ZERO
VECTOR 0x06, ZERO
VECTOR 0x07, ZERO
VECTOR 0x08, ZERO
VECTOR 0x09, ZERO
VECTOR 0x0a, ZERO
VECTOR 0x0b, ZERO
VECTOR 0x0c, ZERO
VECTOR 0x0d, ZERO
VECTOR 0x0e, ZERO
VECTOR 0x0f, ZERO
VECTOR 0x10, ZERO
VECTOR 0x11, ZERO
VECTOR 0x12, ZERO
VECTOR 0x13, ZERO
VECTOR 0x14, ZERO
VECTOR 0x15, ZERO
VECTOR 0x16, ZERO
VECTOR 0x17, ZERO
VECTOR 0x18, ZERO
VECTOR 0x19, ZERO
VECTOR 0x1a, ZERO
VECTOR 0x1b, ZERO
VECTOR 0x1c, ZERO
VECTOR 0x1d, ZERO
VECTOR 0x1e, ERROR_CODE
VECTOR 0x1f, ZERO
VECTOR 0x20, ZERO