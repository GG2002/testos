// #include "../lib/kernel/print.h"
#include "print.h"
int main(void)
// int _start(void)
{
    put_str("OPSM");

    put_char('\n');
    put_char('S');
    put_char('\b');
    put_char('S');
    put_char('M');
    put_char('\n');
    put_int(1);

    while (1);
    return 0;
}