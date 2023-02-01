%include "boot.inc"
SECTION loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR

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

    ;total_mem_bytes用于保存内存容量，以字节为单位，此位置比较好记
    ;当前偏移loader.bin文件头0x200字节，
    ;loader.bin的加载地址是0x900
    ;故total_mem_bytes内存中的地址为0xb00
    ;将来会在内核中引用此地址
    total_mem_bytes dd 0

    ;以下是GDT的指针，前2字节是GDT界限，后4字节是GDT起始地址
    gdt_ptr     dw  GDT_LIMIT
                dd  GDT_BASE

    ;偏移值凑个0x300便于mbr跳转至loader_start函数
    ards_buf times 244 db 0 ;total_mem_bytes + gdt_ptr  +ards_buf + ards_nr=256字节
    ards_nr     dw 0
    
    loader_start:

;int 15h eax=E820h ,edx=534D4150h('SMAP')获取内存布局
    xor ebx,ebx             ;ebx置0
    mov edx,0x534d4150      ;edx只赋值一次,循环体中不会改变
    mov di,ards_buf         ;ards结构缓冲区
    
.e820_mem_get_loop:
    mov eax,0x0000e820      ;执行int 0x15后,eax值变为0x534d4150,所以每次执行int前都要更新为子功能号
    mov ecx,20              ;ards地址范围描述符结构大小是20字节
    int 0x15

    jc .e820_failed_so_try_e801;若cf为1则有错误发生,尝试0xe801子功能号
    add di,cx               ;使di增加20字节指向缓冲区中新的ards结构位置
    inc word [ards_nr]      ;记录ards数量
    cmp ebx,0               ;若ebx为0且cf不为1,这说明ards全部返回
    jnz .e820_mem_get_loop

    ;在所有ards结构中找出(base_add_low+length_low)的最大值,及内存的容量
    mov cx,[ards_nr]
    ;遍历每一个ards结构体,循环次数使ards的数量
    mov ebx,ards_buf
    xor edx,edx             ;设置edx为最大容量,先置0
    .find_max_mem_area:
        mov eax,[ebx]       ;base_add_low
        add eax,[ebx+8]     ;length_low
        add ebx,20          ;指向缓冲区中下一个ards结构
        cmp edx,eax
        ;冒泡排序,找出最大,edx寄存器始终是最大的内存容量
        jge .next_ards
        mov edx,eax
        .next_ards:
            loop .find_max_mem_area
            jmp .mem_get_ok

;int 15h ax=E801h 获取内存大小,最大支持4G
;返回后,ax cx值相同,以KB为单位,bx dx值相同,以64KB为单位
;在ax和cx寄存器中为低16MB,在bx和dx寄存器中为16MB至4GB
.e820_failed_so_try_e801:
    mov ax,0xe801
    int 0x15
    jc .e801_failded_so_try88

    ;1 先算出低15MB的内存
    ;ax和cx中是以KB为单位的内存数量,将其转换为byte为单位
    mov cx,0x400
    mul cx
    shl edx,16
    and eax,0x0000FFFF
    or edx,eax
    add edx,0x100000        ;ax只是15MB,故要加1MB
    mov esi,edx             ;先把低15MB的内存容量存入esi寄存器备份

    ;再将16MB上的内存转换为byte为单位
    ;寄存器bx和dx中是以64KB为单位的内存数量
    xor eax,eax
    mov ax,bx
    mov ecx,0x10000         ;0x10000十进制为64KB
    mul ecx                 ;32位乘法,默认的被乘数是eax,积为64位
                            ;高32位存入edx,低32位存入eax
    add esi,eax
    mov edx,esi
    jmp .mem_get_ok

;int 15h ah=0x88获取内存大小,只能获取64MB内的
.e801_failded_so_try88:
    ;int 15h后,ax存入的是以KB为单位的内存容量
    mov ah,0x88
    int 0x15
    ; jc .error_hlt
    and eax,0x0000FFFF
    mov cx,0x400
    mul cx
    shl edx,16
    or edx,eax
    add edx,0x100000        ;实际内存大小要加上1MB

.mem_get_ok:
    mov [total_mem_bytes],edx

;----------准备进入保护模式--------------
;1 打开A20地址线
;2 加载GDT
;3 将CR0的pe位置设为1
    mov ax,0xb800
    mov gs,ax

;----------------打开A20-----------------
    in  al,0x92
    or  al,0000_0010b
    out 0x92,al
;---------------加载GDT------------------
    lgdt [gdt_ptr]
;--------------CR0第0位置1---------------
    mov eax,cr0
    or eax,0x0000_0001
    mov cr0,eax

    mov ax,SELECTOR_VIDEO
    mov gs,ax

    jmp dword SELECTOR_CODE:p_mode_start

[bits 32]
p_mode_start:
    mov ax,SELECTOR_DATA
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov esp,LOADER_STACK_TOP
    mov ax,SELECTOR_VIDEO
    mov gs,ax

    mov byte [gs:162],'O'
    
;----------加载内核--------------
    mov eax,KERNEL_START_SECTOR        ;9号扇区
    mov ebx,KERNEL_BIN_BASE_ADDR       ;内核加载的位置
    mov ecx,200                        ;扇区数200

    call rd_disk_m_32

;----------内存分页--------------

;创建页目录及页表并初始化业内存位图
    mov byte [gs:164],'P'
    call setup_page
;要将描述符地址及偏移量写入内存gdt_ptr,一会用新地址重新加载
    sgdt [gdt_ptr]

;将gdt描述符中视频段描述符中的段基址+0xc0000000
    mov ebx,[gdt_ptr+2]
    or dword [ebx+0x18+4],0xc0000000

    add dword [gdt_ptr+2],0xc0000000
    add esp,0xc0000000                  ;将栈指针同样映射到内核地址

    ;把页目录地址赋给cr3
    mov eax,PAGE_DIR_TABLE_POS
    mov cr3,eax

    ;打开cr0的pg位(第31位)
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    ;在开启分页后,用gdt新的地址重新加载
    lgdt [gdt_ptr]

    ;-----------------据说此时不刷新流水线也没问题----------------
    jmp SELECTOR_CODE:enter_kernel

    enter_kernel:
        call kernel_init
        mov esp, 0xc009f000
        jmp KERNEL_ENTRY_POINT

    mov byte [gs:166],'M'

    jmp $

;----------创建页目录及页表------------
setup_page:
;先把页目录占用的空间逐字节清0
    mov byte [gs:166],'S'
    mov ecx,4096
    mov esi,0
.clear_page_dir:
    ;调试地址0x0d32
    mov byte [PAGE_DIR_TABLE_POS+esi],0
    inc esi
    loop .clear_page_dir

;开始构建页目录项(PDE)
.create_pde:                                ;创建Page Directory Entry
    mov eax,PAGE_DIR_TABLE_POS
    add eax,0x1000                          ;此时eax为第一个页表的位置及属性
    mov ebx,eax                             ;为.create_pde做准备,ebx为基址

    ;下面将页目录项0和0xc00都存为第一个页表的地址,每个页表都表示4MB内存
    ;这样0xc0000000~0xc03fffff的地址和0x00000000~0x003fffff都指向相同的页表
    ;这是为将地址映射为内核地址做准备

    or eax,PG_US_U | PG_RW_W | PG_P         ;页目录项的属性RW和P位为1,US为1,表示用户属性,所有特权级别都可以访问
    mov [PAGE_DIR_TABLE_POS+0x0],eax        ;第一个目录项,位置为0x101000
    mov [PAGE_DIR_TABLE_POS+0xc00],eax      ;0xc00表示第768个页表项,0xc00以上的目录项用于内核空间

    sub eax,0x1000                          ;0x101000-0x1000=0x100000
    mov [PAGE_DIR_TABLE_POS+4092],eax       ;使最后一个目录项指向页目录表自身

    ;下面创建页表项(PTE)
    mov ecx,256                             ;1M低段内存 / 每页大小 4k = 256
    mov esi,0
    mov edx,PG_US_U | PG_RW_W | PG_P        ;属性为7,RW和P位为1,US为1
.create_pte:
    mov [ebx+esi*4],edx                     ;此时的ebx已经在上面通过eax赋值0x101000,也就是第一个页表的地址

    add edx,4096                            ;4096=0x1000
    inc esi
    loop .create_pte

    ;创建内核其他页表的PTE
    mov eax,PAGE_DIR_TABLE_POS
    add eax,0x2000                          ;此时eax为第二个页表的位置
    or eax,PG_US_U | PG_RW_W | PG_P         ;页目录项的US,RW,P都为1
    mov ebx,PAGE_DIR_TABLE_POS
    mov ecx,254
    mov esi,769
.create_kernel_pte:
    mov [ebx+esi*4],eax
    inc esi
    add eax,0x1000
    loop .create_kernel_pte
    ret

;---------------读取内核-----------------
rd_disk_m_32:

    mov esi, eax
    mov di, cx

    mov dx, 0x1f2
    mov al, cl
    out dx, al

    mov eax, esi
    ; 保存LBA地址
    mov dx, 0x1f3
    out dx, al

    mov cl, 8
    shr eax, cl
    mov dx, 0x1f4
    out dx, al

    shr eax, cl
    mov dx, 0x1f5
    out dx, al

    shr eax, cl
    and al, 0x0f
    or al, 0xe0
    mov dx, 0x1f6
    out dx, al

    mov dx, 0x1f7
    mov al, 0x20
    out dx, al

.not_ready:
    nop
    in al, dx
    and al, 0x88
    cmp al, 0x08
    jnz .not_ready

    mov ax, di
    mov dx, 256
    mul dx
    mov cx, ax
    mov dx, 0x1f0

.go_on_read:
    in ax, dx
    mov [ds:ebx], ax
    add ebx, 2
    loop .go_on_read
    ret

;--------------初始化内核----------------
kernel_init:
    xor eax,eax
    xor ebx,ebx                 ;ebx记录程序头表地址
    xor ecx,ecx                 ;cx记录程序头表中的program header数量
    xor edx,edx                 ;dx记录program header尺寸,即e_phentsize

    mov dx,[KERNEL_BIN_BASE_ADDR+42]    ;内核elf文件偏移42字节处是e_phentsize
    mov ebx,[KERNEL_BIN_BASE_ADDR+28]   ;内核elf文件偏移28字节处是e_phoff
                                        ;表示第一个program header在文件中的偏移量
    add ebx,KERNEL_BIN_BASE_ADDR        
    mov cx,[KERNEL_BIN_BASE_ADDR+44]    ;内核elf文件偏移44字节处是e_phnum,表示有几个program header

.each_segment:
    cmp byte [ebx],PT_NULL            ;若p_type等于PT_NULL,则说明此program header未使用
    je .PTNULL

    ;为函数memcpy压入参数,参数是从右往左依次压入
    ;函数原型类似于memcpy(dst,src,size)
    ;先压入size
    push dword [ebx+16]                 ;program header中偏移16字节的地方是p_filesz

    ;压入src(源地址)
    mov eax,[ebx+4]                     ;program header中偏移4字节的地方是p_offset
    add eax,KERNEL_BIN_BASE_ADDR
    push eax                            

    ;压入dst(目的地址)
    push dword [ebx+8]                  ;program header中偏移4字节的地方是p_vaddr,目的地址
    
    mov byte [gs:168],'M'
    call mem_cpy                        ;调用mem_cpy完成段复制
    add esp,12                          ;清理栈中3个参数

.PTNULL:
    add ebx,edx                         ;edx为program header大小
    loop .each_segment
    ret

mem_cpy:
    cld
    push ebp
    mov ebp,esp
    push ecx                            ;rep指令用到了ecx,故须备份

    mov edi,[ebp+8]                     ;dst
    mov esi,[ebp+12]                    ;src
    mov ecx,[ebp+16]                    ;size
    rep movsb                           ;逐字节拷贝

    pop ecx
    pop ebp
    ret
