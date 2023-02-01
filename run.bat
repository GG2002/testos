@REM 编译MBR
nasm -I chapter5/include/ -o chapter5/mbr.bin chapter5/mbr4.s
dd if=chapter5/mbr.bin of=hd60M.img bs=512 count=1 conv=notrunc

@REM 编译Loader
nasm -I chapter5/include/ -o chapter5/loader.bin chapter5/loader.s
dd if=chapter5/loader.bin of=hd60M.img bs=512 count=4 seek=2 conv=notrunc

bochsdbg -f .\bochsrc.src
@REM bochs -f .\bochsrc.src

@REM @REM 编译MBR
@REM nasm -I tiny-os/chapter4/include/ -o tiny-os/chapter4/mbr.bin tiny-os/chapter4/mbr.asm
@REM dd if=tiny-os/chapter4/mbr.bin of=hd60M.img bs=512 count=1 conv=notrunc

@REM @REM 编译Loader
@REM nasm -I tiny-os/chapter4/include/ -o tiny-os/chapter4/loader.bin tiny-os/chapter4/loader.asm
@REM dd if=tiny-os/chapter4/loader.bin of=hd60M.img bs=512 count=4 seek=2 conv=notrunc

@REM bochsdbg -f .\bochsrc.src
@REM @REM bochs -f .\bochsrc.src