SECTION MBR vstart=0x7c00
    mov ax,cs
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov fs,ax
    mov sp,0x7c00

; 清屏,利用0x06功能，上卷全部行，则可清屏
; INT 0x10 功能号:0x06 功能描述:上卷窗口
    mov ax,0x600 ;AH:功能号=0x06
                 ;AL:上卷的行数(为0则表示全部)
    mov bx,0x700 ;BH:上卷行属性
    mov cx,0     ;(CH,CL) 窗口左上角(0,0)位置
    mov dx,0x184f;(DH,DL) 窗口右下角(80,25)
                 ;vga文本模式中,一行80个字符,共25行.
                 ;从0计起,0x18=24,0x4f=79
    int 0x10

; 获取光标位置
    mov ah,3     ;3号子功能为获取光标位置
    mov bh,0     ;待获取光标的页号

    int 0x10

; 打印字符
    mov ax,message
    mov bp,ax      ;es:bp为串首地址,es此时同cs一致,
                   ;开头已为sreg初始化
    mov cx,11       ;字符串长度
    mov ax,0x1301  ;AH:子功能号13显示字符及属性
                   ;AL:设置写字符方式 01:显示字符串,光标跟随移动
    mov bx,0x2     ;BH储存要显示的页号,此处为0页
                   ;BL中是字符属性,黑底绿字 02
    int 0x10
; 打印结束

    jmp $          ;使程序悬停在此
    message db "HELLO WORLD"
    times 510-($-$$) db 00
    dw 0xaa55