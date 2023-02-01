#include "string.h"
#include "stdint.h"
#include "global.h"
#include "debug.h"

/*将dst_起始的size个字符置为value*/
void memset(void* dst_,uint8_t value,uint32_t size){
    ASSERT(dst_!=NULL);
    uint8_t* dst = (uint8_t*)dst_;
    while (size-- > 0)
    {
        *dst++ = value;
    }   
}
// 将src_起始的size个字节复制到dst_
void memcpy(void* dst_,const void* src_,uint32_t size){
    ASSERT(dst_!=NULL&&src_!=NULL);
    uint8_t* dst=(uint8_t*)dst_;
    const uint8_t* src=src_;
    while (size-- > 0)
    {
        *dst++=*src++;
    }
}
// 连续比较地址a_和地址b_开头的size个字节
// 若相等则返回0，若a_大于b_返回1，否则返回-1
int memcmp(const void* a_,const void* b_,uint32_t size){
    const char* a=a_;
    const char* b=b_;
    ASSERT(a!=NULL||b!=NULL);
    while (size-- >0)
    {
        if(*a!=*b){
            return *a>*b?1:-1;
        }
        a++;
        b++;
    }
    return 0;
}

// 将字符串从b复制到a
char* strcpy(char* a,const char* b){
    ASSERT(a!=NULL&&b!=NULL);
    char* r = a;
    while ((*r++=*b++));
    return a;
}
// 返回字符串长度
uint32_t strlen(const char* str){
    ASSERT(str!=NULL);
    const char* p=str;
    while(*p++);
    return (p-str-1);
}
// 比较字符串
int8_t strcmp(const char* a,const char* b){
    ASSERT(a!=NULL||b!=NULL);
    while (*a!=0&&*a==*b)
    {
        a++;
        b++;
    }
    return *a>*b?1:*a<*b?-1:0;
}
// 查找字符串str中首次出现ch的地址
char* strchr(const char* str,const uint8_t ch){
    ASSERT(str!=NULL);
    while (*str!=0)
    {
        if(*str==ch){
            return (char*)str;  // 不强制转换编译器会报const属性丢失错误
        }
        str++;
    }
    return NULL;
}
// 从后往前查找
char* strrchr(const char* str,const uint8_t ch){
    ASSERT(str!=NULL);
    const char* last_chr=NULL;
    while (*str!=0)
    {
        if(*str==ch){
            last_chr=str;
        }
        str++;
    }
    return (char*)last_chr;
}
// 字符串拼接，返回拼接的串地址
char* strcat(char* a,const char* b){
    ASSERT(a!=NULL&&b!=NULL);
    char* str=a;
    while(str++);
    str--;
    while((*str++=*b++));
    return a;
}
// 查找字符在字符串中出现次数
uint8_t strchrs(const char* str,uint8_t ch){
    ASSERT(str!=NULL);
    uint32_t ch_cnt=0;
    const char* p=str;
    while(*p!=0){
        if(*p==ch){
            ch_cnt++;
        }
        p++;
    }
    return ch_cnt;
}