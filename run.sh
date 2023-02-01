#!/bin/sh

# # 编译MBR
# nasm -I ./chapter7/include/ -o ./chapter7/mbr.bin ./chapter7/mbr4.s
# dd if=./chapter7/mbr.bin of=./hd60M.img bs=512 count=1 conv=notrunc

# # 编译Loader
# nasm -I ./chapter7/include/ -o ./chapter7/loader.bin ./chapter7/loader.s
# dd if=./chapter7/loader.bin of=./hd60M.img bs=512 count=4 seek=2 conv=notrunc

# # 1-6章前编译内核模板
# nasm -f elf -o chapter6/lib/kernel/print.o chapter6/lib/kernel/print.s
# gcc -m32 -c -I chapter6/lib/kernel/ -o chapter6/kernel/main.o chapter6/kernel/main.c
# ld -m elf_i386 -Ttext 0xc0001500 -e main -o chapter6/kernel/kernel.bin chapter6/kernel/main.o chapter6/lib/kernel/print.o
# dd if=./chapter6/kernel/kernel.bin of=./hd60M.img bs=512 count=200 seek=9 conv=notrunc

# # 7章编译内核
# gcc -m32 -I chapter7/lib/kernel/ -I chapter7/kernel/ -I chapter7/device/ -I chapter7/lib/ -c -fno-builtin -o chapter7/build/main.o chapter7/kernel/main.c
# nasm -f elf -o chapter7/build/print.o chapter7/lib/kernel/print.s
# nasm -f elf -o chapter7/build/kernel.o chapter7/kernel/kernel.s
# gcc -m32 -I chapter7/lib/kernel/ -I chapter7/kernel/ -I chapter7/device/ -I chapter7/lib/ -c -fno-builtin -o chapter7/build/interrupt.o chapter7/kernel/interrupt.c
# gcc -m32 -I chapter7/lib/kernel/ -I chapter7/kernel/ -I chapter7/device/ -I chapter7/lib/ -c -fno-builtin -o chapter7/build/timer.o chapter7/device/timer.c
# gcc -m32 -I chapter7/lib/kernel/ -I chapter7/kernel/ -I chapter7/device/ -I chapter7/lib/ -c -fno-builtin -o chapter7/build/init.o chapter7/kernel/init.c
# ld -m elf_i386 -Ttext 0xc0001500 -e main -o chapter7/build/kernel.bin chapter7/build/main.o chapter7/build/print.o chapter7/build/init.o chapter7/build/interrupt.o chapter7/build/kernel.o chapter7/build/timer.o
# dd if=./chapter7/build/kernel.bin of=./hd60M.img bs=512 count=200 seek=9 conv=notrunc

# 8章后makefile
make all

# ---------tiny-os-------------
# # 编译MBR
# nasm -I tiny-os/chapter6/include/ -o tiny-os/chapter6/mbr.bin tiny-os/chapter6/mbr.asm
# dd if=tiny-os/chapter6/mbr.bin of=hd60M.img bs=512 count=1 conv=notrunc

# # 编译Loader
# nasm -I tiny-os/chapter6/include/ -o tiny-os/chapter6/loader.bin tiny-os/chapter6/loader.asm
# dd if=tiny-os/chapter6/loader.bin of=hd60M.img bs=512 count=4 seek=2 conv=notrunc

# # 编译内核
# nasm -f elf -o tiny-os/chapter6/lib/kernel/print.o tiny-os/chapter6/lib/kernel/print.asm
# gcc -m32 -c -I tiny-os/chapter6/lib/ -o tiny-os/chapter6/kernel/main.o tiny-os/chapter6/kernel/main.c
# ld -m elf_i386 -Ttext 0xc0001500 -e main -o tiny-os/chapter6/kernel/kernel.bin tiny-os/chapter6/kernel/main.o tiny-os/chapter6/lib/kernel/print.o
# dd if=./tiny-os/chapter6/kernel/kernel.bin of=./hd60M.img bs=512 count=200 seek=9 conv=notrunc

bochs -f ./bochsrc.src