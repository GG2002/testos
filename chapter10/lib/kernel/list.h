#ifndef __LIB_KERNEL_LIST_H
#define __LIB_KERNEL_LIST_H
#include "global.h"

#define offset(struct_type,member) (int)(&((struct_type*)0)->member)
# define elem2entry(struct_type, struct_member_name, elem_ptr) \
    (struct_type*) ((int) elem_ptr - offset(struct_type, struct_member_name))

struct list_elem{
    struct list_elem* prev;
    struct list_elem* next;
};

struct list
{
    struct list_elem head;
    struct list_elem tail;
};

#define node struct list_elem

typedef int (function)(node* n,int arg);

void list_init(struct list*);
void list_insert_before(node* before,node* elem);
void list_push(struct list* plist,node* elem);
void list_iterate(struct list* plist);
void list_append(struct list* plist,node* elem);
void list_remove(node* pelem);
node* list_pop(struct list* plist);
int list_empty(struct list* plist);
uint32_t list_len(struct list* plist);
node* list_traversal(struct list* plist,function func,int arg);
int elem_find(struct list* plist,node* obj_elem);

#endif