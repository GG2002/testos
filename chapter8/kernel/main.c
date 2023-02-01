#include "print.h"
#include "init.h"
#include "debug.h"
#include "memory.h"

int main(void)
{
    put_str("OPSM.\n");
    init_all();
    put_str("-----------------------------\n\n");
    void* addr=get_kernel_pages(3);
    put_str("\nget_kernel_page start vaddr is ");put_int((uint32_t)addr);put_str("\n");
    while (1);
    return 0;
}