[bits 32]
section .text:
global switch_to
switch_to:
    push esi
    push edi
    push ebx
    push ebp
    mov eax,[esp+20]        ;获取thread.c中cur值
    mov [eax],esp

    ;以上是备份当前线程环境，下面是恢复下一个线程环境
    mov eax,[esp+24]        ;获取thread.c中next值
    mov esp,[eax]
    pop ebp
    pop ebx
    pop edi
    pop esi
    ret