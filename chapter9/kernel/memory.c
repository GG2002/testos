#include "memory.h"
#include "stdint.h"
#include "print.h"
#include "bitmap.h"
#include "global.h"
#include "string.h"
#include "debug.h"

#define PG_SIZE 4096

// 0xc009f000是内核主线程栈顶，0xc009e000是内核主线程的pcb。一个页大小的位图可支持128MB内存
// 位图位置安排在0xc009a000，这样本系统最大支持4个页的位图，即512MB
#define MEM_BITMAP_BASE 0xc009a000

// 0xc0000000是内核从虚拟地址3G起。0x100000意指跨过低端1MB内存，使虚拟地址在逻辑上连续。
#define K_HEAP_START 0xc0100000

#define PDE_IDX(addr) ((addr & 0xffc00000) >> 22)
#define PTE_IDX(addr) ((addr & 0x003ff000) >> 12)

// 内存池结构
struct pool
{
    struct bitmap pool_bitmap;
    uint32_t phy_addr_start;
    uint32_t pool_size;
};
struct pool kernel_pool, user_pool;
struct virtual_addr kernel_vaddr;
// 内存初始化
static void mem_pool_init(uint32_t all_mem){
    put_str("mem_pool_init start.\n");
    uint32_t page_table_size=PG_SIZE*256;
    uint32_t used_mem=page_table_size+0x100000;
    uint32_t free_mem=all_mem-used_mem;
    uint16_t all_free_pages=free_mem/PG_SIZE;

    uint16_t kernel_free_pages=all_free_pages/2;
    uint16_t user_free_pages=all_free_pages-kernel_free_pages;

    // 为简化位图操作，余数不做处理
    uint32_t kbm_length=kernel_free_pages/8;
    uint32_t ubm_length=user_free_pages/8;

    uint32_t kp_start=used_mem;
    uint32_t up_start=kp_start+kernel_free_pages*PG_SIZE;

    kernel_pool.phy_addr_start=kp_start;
    user_pool.phy_addr_start=up_start;

    kernel_pool.pool_size=kernel_free_pages*PG_SIZE;
    user_pool.pool_size=user_free_pages*PG_SIZE;

    kernel_pool.pool_bitmap.btmp_bytes_len=kbm_length;
    user_pool.pool_bitmap.btmp_bytes_len=ubm_length;

    kernel_pool.pool_bitmap.bits=(void*)MEM_BITMAP_BASE;
    user_pool.pool_bitmap.bits=(void*)(MEM_BITMAP_BASE+kbm_length);

    put_str("----------------------------------------\n");
    put_str("kernel_pool_bitmap_start:");put_int((int)kernel_pool.pool_bitmap.bits);
    put_str("\nkernel_pool_phy_addr_start:");put_int(kernel_pool.phy_addr_start);
    put_str("\n\n");
    put_str("user_pool_bitmap_start");put_int((int)user_pool.pool_bitmap.bits);
    put_str("\nuser_pool_phy_addr_start:");put_int(user_pool.phy_addr_start);
    put_str("\n----------------------------------------\n");


    bitmap_init(&kernel_pool.pool_bitmap);
    bitmap_init(&user_pool.pool_bitmap);

    kernel_vaddr.vaddr_bitmap.btmp_bytes_len=kbm_length;
    kernel_vaddr.vaddr_bitmap.bits=(void*)(MEM_BITMAP_BASE+kbm_length+ubm_length);
    kernel_vaddr.vaddr_start=K_HEAP_START;
    bitmap_init(&kernel_vaddr.vaddr_bitmap);

    put_str("mem_pool_init done.\n");
}

// 内存管理部分初始化入口
void mem_init(void) {
    put_str("Init memory start.\n");
    uint32_t total_memory = (*(uint32_t*) (0xb00));
    mem_pool_init(total_memory);
    put_str("Init memory done.\n");
}

// 在pf表示的虚拟内存池中申请pg_cnt个虚拟页，成功则返回虚拟页的起始地址，失败则返回NULL
static void* vaddr_get(enum pool_flags pf, uint32_t pg_cnt){
    int vaddr_start=0,bit_idx_start=-1;
    uint32_t cnt=0;
    if(pf==PF_KERNEL){
        bit_idx_start=bitmap_scan(&kernel_vaddr.vaddr_bitmap, pg_cnt);
        if(bit_idx_start==-1){
            return NULL;
        }
        while(cnt<pg_cnt){
            bitmap_set(&kernel_vaddr.vaddr_bitmap,bit_idx_start+cnt++,1);
        }
        vaddr_start=kernel_vaddr.vaddr_start+bit_idx_start*PG_SIZE;
    }else{
        //用户内存池，目前未实现
    }
    return (void*)vaddr_start;
}

// 得到虚拟地址vaddr对应的pte指针
static uint32_t* pte_ptr(uint32_t vaddr){
    uint32_t* pte=(uint32_t*)(0xffc00000+((vaddr&0xffc00000)>>10)+(PTE_IDX(vaddr) << 2));
    return pte;
}

// 得到虚拟地址vaddr对应的pde指针
static uint32_t* pde_ptr(uint32_t vaddr){
    uint32_t* pde=(uint32_t*)(0xfffff000+(PDE_IDX(vaddr) << 2));
    return pde;
}

// 在m_pool指向的物理内存池中分配1个物理页。成功则返回页的物理地址，失败则返回NULL
static void* palloc(struct pool* m_pool){
    int bit_idx=bitmap_scan(&m_pool->pool_bitmap,1);
    if (bit_idx==-1){
        return NULL;
    }
    bitmap_set(&m_pool->pool_bitmap,bit_idx,1);
    uint32_t page_phyaddr=((bit_idx*PG_SIZE)+m_pool->phy_addr_start);
    return (void*)page_phyaddr;
}

// 页表中添加虚拟地址_vaddr与物理地址_page_phyaddr的映射
static void page_table_add(void* _vaddr, void* _page_phyaddr){
    uint32_t vaddr = (uint32_t)_vaddr, page_phyaddr=(uint32_t)_page_phyaddr;
    uint32_t* pde=pde_ptr(vaddr);
    uint32_t* pte=pte_ptr(vaddr);

    put_int(vaddr);put_str(" ");put_int(page_phyaddr);put_str("\n");
    put_int(*pde);put_str(" ");put_int(*pte);put_str("\n");

    if(*pde & 0x00000001){
        ASSERT(!((*pte) & 0x00000001));
        if(!(*pte & 0x00000001)){
            *pte=(page_phyaddr|PG_US_U|PG_RW_W|PG_P_1);
        }else{
            PANIC("pte repeat");
            *pte=(page_phyaddr|PG_US_U|PG_RW_W|PG_P_1);
        }
    }else{
        uint32_t pde_phyaddr=(uint32_t)palloc(&kernel_pool);
        *pde=(pde_phyaddr|PG_US_U|PG_RW_W|PG_P_1);
        memset((void*)((int)pte&0xfffff000),0,PG_SIZE);

        ASSERT(!(*pte&0x00000001));
        *pte=(page_phyaddr|PG_US_U|PG_RW_W|PG_P_1);
    }
}

/* 分配pg_cnt个页空间，成功则返回虚拟地址，失败时返回NULL */
/**************** malloc_page的原理是三个动作的合成 *****************
    1.通过vaddr_get在虚拟内存池中申请虚拟地址
    2.通过palloc在物理内存池中申请物理页
    3.通过page_table_add将以上得到的虚拟地址和物理地址在页表中完成映射
*******************************************************************/
void* malloc_page(enum pool_flags pf,uint32_t pg_cnt){
    ASSERT(pg_cnt>0&&pg_cnt<3840);
    void* vaddr_start=vaddr_get(pf,pg_cnt);
    if(vaddr_start==NULL){
        return NULL;
    }
    uint32_t vaddr=(uint32_t)vaddr_start,cnt=pg_cnt;
    struct pool* mem_pool=(pf&PF_KERNEL) ? &kernel_pool : &user_pool;
    while (cnt-->0)
    {
        void* page_phyaddr=palloc(mem_pool);
        if(page_phyaddr==NULL){
            return NULL;
        }
        page_table_add((void*)vaddr,page_phyaddr);
        vaddr+=PG_SIZE;
    }
    return vaddr_start;
}

// 从内核物理内存池中申请pg_cnt页内存地址，成功则返回其虚拟地址，失败则返回NULL
void* get_kernel_pages(uint32_t pg_cnt){
    put_int(pg_cnt);
    put_str("\n");
    void* vaddr = malloc_page(PF_KERNEL,pg_cnt);
    if(vaddr!=NULL){
        memset(vaddr,0,pg_cnt*PG_SIZE);
    }
    return vaddr;
}
