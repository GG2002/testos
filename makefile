CHAPTER=./chapter11
BUILD_DIR=$(CHAPTER)/build
ENTRY_POINT=0xc0001500
AS=nasm
CC=gcc
LD=ld
LIB=-I $(CHAPTER)/lib -I $(CHAPTER)/lib/kernel -I $(CHAPTER)/lib/user -I $(CHAPTER)/kernel \
	-I $(CHAPTER)/device -I $(CHAPTER)/thread -I $(CHAPTER)/userprog
ASFLAGS=-f elf
ASIB = -I $(CHAPTER)/include/
CFLAGS= -Wall -m32 $(LIB) -c -fno-builtin -W -Wstrict-prototypes -Wmissing-prototypes
LDFLAGS= -m elf_i386 -Ttext $(ENTRY_POINT) -e main -Map $(CHAPTER)/kernel/kernel.map
OBJS = $(BUILD_DIR)/main.o $(BUILD_DIR)/init.o $(BUILD_DIR)/interrupt.o $(BUILD_DIR)/timer.o \
	   $(BUILD_DIR)/kernel.o $(BUILD_DIR)/print.o $(BUILD_DIR)/debug.o $(BUILD_DIR)/string.o \
	   $(BUILD_DIR)/bitmap.o $(BUILD_DIR)/memory.o \
	   $(BUILD_DIR)/list.o $(BUILD_DIR)/thread.o $(BUILD_DIR)/switch.o \
	   $(BUILD_DIR)/sync.o $(BUILD_DIR)/console.o $(BUILD_DIR)/keyboard.o $(BUILD_DIR)/ioqueue.o \
	   $(BUILD_DIR)/tss.o

# c代码编译
$(BUILD_DIR)/main.o:$(CHAPTER)/kernel/main.c $(CHAPTER)/lib/kernel/print.h $(CHAPTER)/lib/stdint.h \
					$(CHAPTER)/kernel/init.h $(CHAPTER)/kernel/memory.h $(CHAPTER)/thread/thread.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/init.o:$(CHAPTER)/kernel/init.c $(CHAPTER)/kernel/init.h $(CHAPTER)/lib/kernel/print.h \
					$(CHAPTER)/lib/stdint.h $(CHAPTER)/kernel/interrupt.h $(CHAPTER)/device/timer.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/interrupt.o:$(CHAPTER)/kernel/interrupt.c $(CHAPTER)/kernel/interrupt.h $(CHAPTER)/lib/stdint.h \
						 $(CHAPTER)/kernel/global.h $(CHAPTER)/kernel/io.h $(CHAPTER)/lib/kernel/print.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/timer.o:$(CHAPTER)/device/timer.c $(CHAPTER)/device/timer.h $(CHAPTER)/lib/stdint.h \
					 $(CHAPTER)/kernel/io.h $(CHAPTER)/lib/kernel/print.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/debug.o:$(CHAPTER)/kernel/debug.c $(CHAPTER)/kernel/debug.h $(CHAPTER)/lib/kernel/print.h \
					 $(CHAPTER)/lib/stdint.h $(CHAPTER)/kernel/interrupt.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/string.o:$(CHAPTER)/lib/string.c $(CHAPTER)/lib/string.h $(CHAPTER)/lib/kernel/print.h \
					 $(CHAPTER)/lib/stdint.h $(CHAPTER)/kernel/interrupt.h $(CHAPTER)/kernel/global.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/bitmap.o:$(CHAPTER)/lib/kernel/bitmap.c $(CHAPTER)/lib/kernel/bitmap.h $(CHAPTER)/lib/kernel/print.h \
					 $(CHAPTER)/lib/stdint.h $(CHAPTER)/kernel/interrupt.h $(CHAPTER)/lib/string.h 
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/memory.o:$(CHAPTER)/kernel/memory.c $(CHAPTER)/kernel/memory.h $(CHAPTER)/lib/kernel/print.h \
					 $(CHAPTER)/lib/stdint.h $(CHAPTER)/kernel/interrupt.h $(CHAPTER)/lib/string.h 
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/list.o:$(CHAPTER)/lib/kernel/list.c $(CHAPTER)/lib/kernel/list.h $(CHAPTER)/kernel/interrupt.h $(CHAPTER)/kernel/global.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/thread.o:$(CHAPTER)/thread/thread.c $(CHAPTER)/thread/thread.h $(CHAPTER)/lib/kernel/list.h \
					$(CHAPTER)/kernel/memory.h $(CHAPTER)/lib/kernel/print.h $(CHAPTER)/lib/stdint.h \
					$(CHAPTER)/kernel/interrupt.h $(CHAPTER)/lib/string.h $(CHAPTER)/kernel/global.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/sync.o:$(CHAPTER)/thread/sync.c $(CHAPTER)/thread/sync.h $(CHAPTER)/lib/kernel/list.h $(CHAPTER)/lib/stdint.h \
					$(CHAPTER)/kernel/interrupt.h $(CHAPTER)/lib/string.h $(CHAPTER)/thread/thread.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/console.o:$(CHAPTER)/device/console.c $(CHAPTER)/device/console.h $(CHAPTER)/thread/thread.h $(CHAPTER)/lib/kernel/list.h \
					$(CHAPTER)/kernel/memory.h $(CHAPTER)/lib/kernel/print.h $(CHAPTER)/lib/stdint.h 
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/keyboard.o:$(CHAPTER)/device/keyboard.c $(CHAPTER)/device/keyboard.h $(CHAPTER)/kernel/global.h $(CHAPTER)/kernel/interrupt.h \
					$(CHAPTER)/kernel/io.h $(CHAPTER)/lib/kernel/print.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/ioqueue.o:$(CHAPTER)/device/ioqueue.c $(CHAPTER)/device/ioqueue.h $(CHAPTER)/kernel/global.h $(CHAPTER)/kernel/interrupt.h \
					$(CHAPTER)/kernel/debug.h $(CHAPTER)/lib/kernel/print.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/tss.o:$(CHAPTER)/userprog/tss.c $(CHAPTER)/userprog/tss.h $(CHAPTER)/kernel/global.h $(CHAPTER)/kernel/interrupt.h \
					$(CHAPTER)/kernel/debug.h $(CHAPTER)/lib/kernel/print.h
	$(CC) $(CFLAGS) $< -o $@

# 编译loader和mbr
$(BUILD_DIR)/mbr.bin:$(CHAPTER)/mbr4.s
	$(AS) $(ASIB) $< -o $@

$(BUILD_DIR)/loader.bin:$(CHAPTER)/loader.s
	$(AS) $(ASIB) $< -o $@

# 编译汇编
$(BUILD_DIR)/kernel.o:$(CHAPTER)/kernel/kernel.s
	$(AS) $(ASFLAGS) $< -o $@

$(BUILD_DIR)/print.o:$(CHAPTER)/lib/kernel/print.s
	$(AS) $(ASFLAGS) $< -o $@

$(BUILD_DIR)/switch.o:$(CHAPTER)/thread/switch.s
	$(AS) $(ASFLAGS) $< -o $@

# 链接
$(BUILD_DIR)/kernel.bin:$(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@

.PHONY:mk_dir hd clean all

mk_dir:
	if [[ ! -d $(BUILD_DIR) ]]; then mkdir $(BUILD_DIR); fi

hd:
	dd if=$(BUILD_DIR)/mbr.bin of=hd60M.img bs=512 count=1 conv=notrunc
	dd if=$(BUILD_DIR)/loader.bin of=hd60M.img bs=512 count=4 seek=2 conv=notrunc
	dd if=$(BUILD_DIR)/kernel.bin of=hd60M.img bs=512 count=200 seek=9 conv=notrunc

clean:
	cd $(BUILD_DIR) && rm -f ./*

build: $(BUILD_DIR)/mbr.bin $(BUILD_DIR)/loader.bin $(BUILD_DIR)/kernel.bin

all: mk_dir clean build hd