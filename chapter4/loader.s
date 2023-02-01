%include "boot.inc"
SECTION loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR
jmp loader_start

;构建gdt及其内部的描述符
    GDT_BASE:           dd  0x00000000
                        dd  0x00000000
    CODE_DESC:          dd  0x0000FFFF
                        dd  DESC_CODE_HIGH4
    DATA_STACK_DESC:    dd  0x0000FFFF
                        dd  DESC_DATA_HIGH4
    VIDEO_DESC:         dd  0x8000_0007             ;limit为(0xbffff-0xb8000)/4k=0x7
                        dd  DESC_VIDEO_HIGH4        ;此时DPL为0

    GDT_SIZE        equ $ - GDT_BASE
    GDT_LIMIT       equ GDT_SIZE - 1
    times 60 dq 0                               ;此处预留60个描述符的空位
    SELECTOR_CODE   equ (0x0001<<3)+TI_GDT+RPL0 ;相当于(CODE_DESC-GDT_BASE)/8+TI_GDT+RPL0
    SELECTOR_DATA   equ (0x0002<<3)+TI_GDT+RPL0
    SELECTOR_VIDEO  equ (0x0003<<3)+TI_GDT+RPL0
    ; SELECTOR_VIDEO  equ 0xb800

    ;以下是GDT的指针，前2字节是GDT界限，后4字节是GDT起始地址
    gdt_ptr     dw  GDT_LIMIT
                dd  GDT_BASE
    loadermsg   db  '2 loader in real.'

; ---------------------
; 功能：打印字符串
; ---------------------
    loader_start:


;----------准备进入保护模式--------------
;1 打开A20地址线
;2 加载GDT
;3 将CR0的pe位置设为1

;----------------打开A20-----------------
    mov byte [gs:160],'O'
    in  al,0x92
    or  al,00000010b
    out 0x92,al
;---------------加载GDT------------------
    lgdt [gdt_ptr]
;--------------CR0第0位置1---------------
    mov eax,CR0
    or eax,0x00000001
    mov CR0,eax

    mov byte [gs:162],'P'
    jmp SELECTOR_CODE:p_mode_start

[bits 32]
p_mode_start:
    mov ax,SELECTOR_DATA
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov esp,LOADER_STACK_TOP
    mov byte [gs:164],'S'
    mov ax,SELECTOR_VIDEO
    mov gs,ax
    mov byte [gs:166],'M'

    jmp $
