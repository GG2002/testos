TI_GDT         equ 0
RPL0           equ 0
SELECTOR_VIDEO equ (0x0003<<3)+TI_GDT+RPL0

section .data
put_int_buffer dq  0    ;定义8字节缓冲区用于数字到字符的转换

[bits 32]
section .text
;-------------------put_char---------------------
;功能描述：把栈中的一个字符写入光标所在处
;------------------------------------------------
global put_char
global put_str
global put_int
global set_cursor

put_char:
    pushad                  ;备份32位环境
    ;需要保证gs中为正确的视频段选择子
    ;为保险起见，每次打印都为gs赋值
    mov ax,SELECTOR_VIDEO
    mov gs,ax

    ;获取当前光标位置
    mov dx,0x03d4 
    mov al,0x0e             ;用于提供光标位置的高8位
    out dx,al
    mov dx,0x03d5
    in al,dx
    mov ah,al

    ;再获取低8位
    mov dx,0x03d4
    mov al,0x0f             ;用于提供光标位置的低8位
    out dx,al
    mov dx,0x03d5
    in al,dx

    ;将光标存入bx
    mov bx,ax
    ;下面这行是在栈中获取待打印的字符
    mov ecx,[esp+36]        ;pushad压入4*8=32字节，加上主调函数4字节的返回地址，故esp+36字节
                            ;CR为0x0d,LF为0x0a
    cmp cl,0xd
    jz .iscarriage_return
    cmp cl,0xa
    jz .is_line_feed

    cmp cl,0x8              ;BS(backspace)的ascii码为8
    jz .is_backspace
    jmp .put_other

;--------------------------------------
.is_backspace:
    dec bx
    shl bx,1                ;光标左移1位等于乘2，对应显存内偏移字节
    mov byte [gs:bx],0x20   ;补0或空格均可
    inc bx                  ;自增1位，对显存内字符属性的位置
    mov byte [gs:bx],0x07   ;设置属性
    shr bx,1                ;还原
    jmp .set_cursor

.put_other:
    shl bx,1
    mov byte [gs:bx],cl     ;ecx中为栈中字符
    inc bx
    mov byte [gs:bx],0x07
    shr bx,1
    inc bx
    cmp bx,2000             ;是否超出屏幕2000个字符限制
    jl .set_cursor          ;未超出则设置新光标值，超出则换行处理（顺序执行至下面）

.is_line_feed:              ;换行符LF(\n)
.iscarriage_return:         ;回车符CR(\r)
    xor dx,dx
    mov ax,bx
    mov si,80               ;一行80字符
    div si                  ;除数为16位时，商在ax内，余数在dx内
    sub bx,dx

.iscarriage_return_end:
    add bx,80
    cmp bx,2000
.is_line_feed_end:
    jl .set_cursor

;字符超出2000范围故需要滚屏
.roll_screen:
    cld
    mov ecx,960             ;2000-80=1920个字符需要搬运，共1920*2个字节，每次搬4字节，搬960次
    mov esi,0xc00b80a0
    mov edi,0xc00b8000      ;第1行行首
    rep movsd

;将最后一行填充为空白
    mov ebx,3840            ;最后一行首字符偏移值为1920*2
    mov ecx,80
.cls:
    mov word [gs:ebx]  ,0x0720 ;一次性设定字符和字符属性，黑底白字的空格键
    add ebx,2
    loop .cls
    mov bx,1920                ;将光标设置为最后一行的首字符

.set_cursor:
    mov dx,0x03d4 
    mov al,0x0e             ;用于提供光标位置的高8位
    out dx,al
    mov dx,0x03d5
    mov al,bh
    out dx,al

    mov dx,0x03d4
    mov al,0x0f             ;用于提供光标位置的低8位
    out dx,al
    mov dx,0x03d5
    mov al,bl
    out dx,al

.put_char_done:
    popad
    ret                     ;put_char函数退出


;-------------------打印字符串--------------------
put_str:
    push ebx
    push ecx
    xor ecx,ecx
    mov ebx,[esp+12]        ;从栈中获取待打印字符串地址
.goon: 
    mov cl,[ebx]
    cmp cl,0                ;为\0则处理至字符串尾
    jz .str_over
    push ecx                ;从栈中传递参数
    call put_char
    add esp,4               ;清理栈
    inc ebx
    jmp .goon
.str_over:
    pop ecx
    pop ebx
    ret                     ;put_str函数退出


;----------------打印16进制数字-------------------
;不会输出前缀0x
;例：
;输入：15，输出：f（没有0x）
;------------------------------------------------
put_int:
    pushad
    mov ebp,esp
    mov eax,[ebp+36]
    mov edx,eax
    mov edi,7               ;指定在put_int_buffer中初始的偏移量
    mov ecx,8               ;32位数字中,16进制数字的个数是8
    mov ebx,put_int_buffer  ;指向上方定义的8字节.data区域 

;将32位数字按照16进制的形式从低位到高位逐个处理
.16based_4bits:
;遍历每一位16进制数字
    and edx,0x0000000F      ;解析16进制数字的每一位
                            ;and操作后，edx只有低4位有效
    cmp edx,9               ;0~9和A~F需分别处理
    jg .isA2F
    add edx,'0'
    jmp .store
.isA2F:
    sub edx,10              
    add edx,'A'             ;A~F-10+'A'的ascii码 即为A~F对应的ascii码
.store:
    mov [ebx+edi],dl
    dec edi
    shr eax,4               ;右移1个字节
    mov edx,eax
    loop .16based_4bits

.ready_to_print:
    inc edi                 ;此时edi自减为-1，加1使其为0
.skip_prefix_0:
    cmp edi,8               ;若已经比较第9个字符了，表示待打印的字符串为全0
    je .full0
.go_on_skip:
;找出开头连续的0字符，不打印出来
    mov cl,[put_int_buffer+edi]
    inc edi
    cmp cl,'0'
    je .skip_prefix_0
    dec edi
    jmp .put_each_num

.full0:
    mov cl,'0'
.put_each_num:
    push ecx
    call put_char
    add esp,4

    inc edi
    mov cl,[put_int_buffer+edi]
    cmp edi,8
    jl .put_each_num
.int_over:
    popad
    ret                     ;put_int函数退出

set_cursor:
    pushad                  ;备份32位环境
    mov ecx,[esp+36]
    mov dx,0x03d4 
    mov al,0x0e             ;用于提供光标位置的高8位
    out dx,al
    mov dx,0x03d5
    mov al,ch
    out dx,al

    mov dx,0x03d4
    mov al,0x0f             ;用于提供光标位置的低8位
    out dx,al
    mov dx,0x03d5
    mov al,cl
    out dx,al
    
    popad
    ret