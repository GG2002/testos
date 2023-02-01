#include "list.h"
#include "interrupt.h"

void list_init(struct list* plist){
    plist->head.prev=NULL;
    plist->head.next=&plist->tail;
    plist->tail.prev=&plist->head;
    plist->tail.next=NULL;
}

// 把elem插在before前
void list_insert_before(node* before,node* elem){
    enum intr_status old_status=intr_disable();
    before->prev->next=elem;
    elem->prev=before->prev;
    elem->next=before;
    before->prev=elem;

    intr_set_status(old_status);
}

// 添加elem到队首
void list_push(struct list* plist,node* elem){
    list_insert_before(plist->head.next,elem);
}

// 添加elem到队尾
void list_append(struct list* plist,node* elem){
    list_insert_before(&plist->tail,elem);
}

// 从队伍中remove elem
void list_remove(node* pelem){
    enum intr_status old_status=intr_disable();
    pelem->prev->next=pelem->next;
    pelem->next->prev=pelem->prev;

    intr_set_status(old_status);
}

// 弹出队伍第一个元素
node* list_pop(struct list* plist){
    node* elem = plist->head.next;
    list_remove(elem);
    return elem;
}

// 查找元素obj_elem，成功时返回1，失败返回0
int elem_find(struct list* plist,node* obj_elem){
    node* elem = plist->head.next;
    while (elem != &plist->tail)
    {
        if(elem==obj_elem){
            return 1;
        }
        elem=elem->next;
    }
    return 0;
}

// 把列表plist中每个元素elem和arg传给func，判断elem是否符合条件
// 本函数的功能是遍历列表内所有元素，逐个判断是否有符合条件的元素，找到符合条件的元素返回元素指针，否则返回NULL
node* list_traversal(struct list* plist,function func,int arg){
    struct list_elem* elem=plist->head.next;
    if(list_empty(plist)){
        return NULL;
    }
    while (elem != &plist->tail)
    {
        if(func(elem,arg)){
            return elem;
        }
        elem=elem->next;
    }
    return NULL;
}

uint32_t list_len(struct list* plist){
    node* elem=plist->head.next;
    uint32_t length=0;
    while (elem != &plist->tail)
    {
        length++;
        elem=elem->next;
    }
    return length;
}

// 为空返回1，不为空返回0
int list_empty(struct list* plist){
    return (plist->head.next==&plist->tail?1:0);
}