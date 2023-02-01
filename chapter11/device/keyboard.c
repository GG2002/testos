#include "keyboard.h"
#include "print.h"
#include "interrupt.h"
#include "io.h"
#include "global.h"
#include "ioqueue.h"

#define KBD_BUF_PORT 0x60           // 键盘buffer寄存器端口号为0x60

#define esc             '\033'
#define backspace       '\b'
#define tab             '\t'
#define enter           '\r'
#define delete          '\177'

#define char_invisible  0
#define ctrl_l_char     char_invisible
#define ctrl_r_char     char_invisible
#define shift_l_char    char_invisible
#define shift_r_char    char_invisible
#define alt_l_char      char_invisible
#define alt_r_char      char_invisible
#define caps_lock_char  char_invisible

#define shift_l_make    0x2a
#define shift_r_make    0x36
#define alt_l_make      0x38
#define alt_r_make      0xe038
#define alt_r_break     0xe0b8
#define ctrl_l_make     0x1d
#define ctrl_r_make     0xe01d
#define ctrl_r_break    0xe09d
#define caps_lock_make  0x3a

// 记录相应键是否按下的状态，ext_scancode用于记录makecode是否以0xe0开头
static int ctrl_status,shift_status,alt_status,caps_lock_status,ext_scancode;
struct ioqueue kbd_buf;                      // 键盘缓冲区

// 以通码为索引的显示字符数组，零号元素为shift没有按下时的展示，1反之.
static char keymap[][2] = {
    {'0', '0'},
    {esc, esc},
    {'1', '!'},
    {'2', '@'},
    {'3', '#'},
    {'4', '$'},
    {'5', '%'},
    {'6', '^'},
    {'7', '&'},
    {'8', '*'},
    {'9', '('},
    {'0', ')'},
    {'-', '_'},
    {'=', '+'},
    {backspace, backspace},
    {tab, tab},
    {'q', 'Q'},
    {'w', 'W'},
    {'e', 'E'},
    {'r', 'R'},
    {'t', 'T'},
    {'y', 'Y'},
    {'u', 'U'},
    {'i', 'I'},
    {'o', 'O'},
    {'p', 'P'},
    {'[', '{'},
    {']', '}'},
    {enter, enter},
    {ctrl_l_char, ctrl_l_char},
    {'a', 'A'},
    {'s', 'S'},
    {'d', 'D'},
    {'f', 'F'},
    {'g', 'G'},
    {'h', 'H'},
    {'j', 'J'},
    {'k', 'K'},
    {'l', 'L'},
    {';', ':'},
    {'\'', '"'},
    {'`', '~'},
    {shift_l_char, shift_l_char},
    {'\\', '|'},
    {'z', 'Z'},
    {'x', 'X'},
    {'c', 'C'},
    {'v', 'V'},
    {'b', 'B'},
    {'n', 'N'},
    {'m', 'M'},
    {',', '<'},
    {'.', '>'},
    {'/', '?'},
    {shift_r_char, shift_r_char},
    {'*', '*'},
    {alt_l_char, alt_l_char},
    {' ', ' '},
    {caps_lock_char, caps_lock_char}
};

static void intr_keyboard_handler(void){
    int ctrl_down_last=ctrl_status;
    int shift_down_last=shift_status;
    int caps_lock_last=caps_lock_status;

    int break_code;
    uint16_t scancode=inb(KBD_BUF_PORT);

    // 若scancode为e0开头则表示此键的按下将产生多个扫描码，所以马上结束等待新的
    if(scancode==0xe0){
        ext_scancode=1;
        return;
    }

    if(ext_scancode){
        scancode=(0xe000|scancode);
        ext_scancode=0;
    }

    break_code=((scancode&0x0080)!=0);

    if(break_code){
        uint16_t make_code=(scancode&=0xff7f);
        // 若以下三个键弹起了，将状态置0
        if(make_code==ctrl_l_make||make_code==ctrl_r_make){
            ctrl_status=0;
        }else if(make_code==shift_l_make||make_code==shift_r_make){
            shift_status=0;
        }else if(make_code==alt_l_make||make_code==alt_r_make){
            alt_status=0;
        }
        return;
    }else if((scancode>0x00&&scancode<0x3b)||(scancode==alt_r_make)||(scancode==ctrl_r_make)){
    // 若是通码则进行以下处理
        int shift=0;

        if ((scancode<0x0e)||(scancode==0x29)||(scancode==0x1a)||\
            (scancode==0x1b)||(scancode==0x2b)||(scancode==0x27)||\
            (scancode==0x28)||(scancode==0x33)||(scancode==0x34)||\
            (scancode==0x35)){
                if(shift_down_last){
                    shift=1;
                }
        }else{
            if(shift_down_last&&caps_lock_last){
                shift=0;
            }else if(shift_down_last||caps_lock_last){
                shift=1;
            }else{
                shift=0;
            }
        }
        uint8_t index=(scancode&=0x00ff);
        char cur_char=keymap[index][shift];

        if(cur_char){
            if(!ioq_full(&kbd_buf)){
                put_char(cur_char);
                ioq_putchar(&kbd_buf,cur_char);
            }
            return;
        }
        if(scancode==ctrl_l_make||scancode==ctrl_r_make){
            ctrl_status=1;
        }else if(scancode==shift_l_make||scancode==shift_r_make){
            shift_status=1;
        }else if(scancode==alt_l_make||scancode==alt_r_make){
            alt_status=1;
        }else if(scancode==caps_lock_make){
            caps_lock_status=caps_lock_status==1?0:1;
        }
    }else{
        put_str("unknown key.\n");
    }
    
    return;
}

void keyboard_init(){
    put_str("keyboard init start.\n");
    ioqueue_init(&kbd_buf);
    register_handler(0x21,intr_keyboard_handler);
    put_str("keyboard init done.\n");
}