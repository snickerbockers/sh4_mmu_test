################################################################################
#
# "THE BEER-WARE LICENSE" (Revision 42):
# <snickerbockers@washemu.org> wrote this file.  As long as you retain this
# notice you can do whatever you want with this stuff. If we meet some day,
# and you think this stuff is worth it, you can buy me a beer in return.
#
# snickerbockers
#
################################################################################

AS=sh4-linux-gnu-as
LD=sh4-linux-gnu-ld
CC=sh4-linux-gnu-gcc
OBJCOPY=sh4-linux-gnu-objcopy

all: sh4_mmu_test.bin

clean:
	rm -f init.o sh4_mmu_test.elf sh4_mmu_test.bin main.o store_queue.o

init.o: init.s
	$(AS) -little -o init.o init.s -g

irq.o: irq.s
	$(AS) -little -o irq.o irq.s -g

tlb_miss.o: tlb_miss.s
	$(AS) -little -o tlb_miss.o tlb_miss.s -g

addr_error.o: addr_error.s
	$(AS) -little -o addr_error.o addr_error.s -g

store_queue.o: store_queue.s
	$(AS) -little -o store_queue.o store_queue.s -g

sh4_mmu_test.elf: init.o main.o irq.o tlb_miss.o addr_error.o
	$(CC) -Wl,-e_start,-Ttext,0x8c010000 init.o main.o irq.o tlb_miss.o addr_error.o -o sh4_mmu_test.elf -nostartfiles -nostdlib -lgcc -m4 -g

sh4_mmu_test.bin: sh4_mmu_test.elf
	$(OBJCOPY) -O binary -j .text -j .data -j .bss -j .rodata  --set-section-flags .bss=alloc,load,contents sh4_mmu_test.elf sh4_mmu_test.bin

main.o: main.c sh4_mmu_test.h
	$(CC) -c main.c -nostartfiles -nostdlib -g
