!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
! "THE BEER-WARE LICENSE" (Revision 42):
! <snickerbockers@washemu.org> wrote this file.  As long as you retain this
! notice you can do whatever you want with this stuff. If we meet some day,
! and you think this stuff is worth it, you can buy me a beer in return.
!
! snickerbockers
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!	.globl irq_entry
	.globl vecbase
!	.globl irq_count_ch2_dma
!	.globl wtf_istnrm
!	.globl n_timer_overflows
!	.globl irq_count_yuv_complete
	.global addr_invalid_addr_handler
	.global addr_tlb_miss_handler

	.align 2
vecbase:
	.space 0x100
	mov.l addr_invalid_addr_handler, r0
	jmp @r0
	nop

	.space 0x2fa
	mov.l addr_tlb_miss_handler, r0
	jmp @r0
	nop
!!! Below is IRQ code that I copied from pvr2_mem_test and do not need for the mmu test
! 	.space 0x1fa
! irq_entry:
! 	mov.l addr_intevt, r0
! 	mov.l @r0, r0
! 	mov.l irq_code_holly, r1
! 	cmp/eq r0, r1
! 	bt holly_int
! 	mov.l irq_code_tuni0, r1
! 	cmp/eq r0, r1
! 	bt tuni0_int
! 	bra kill_me_now
! 	nop

! tuni0_int:
! 	mov.l addr_n_timer_overflows, r0
! 	mov.l @r0, r1
! 	add #1, r1
! 	bra kill_me_now
! 	mov.l r1, @r0

! holly_int:
! 	mov.l addr_istnrm, r0
! 	mov.l @r0, r1

! 	! test for ch2 dma irq
! 	mov #1, r2
! 	shll8 r2
! 	shll8 r2
! 	shll2 r2
! 	shll r2
! 	tst r2, r1
! 	bf on_irq_ch2_dma

! 	! test for yuv-complete irq
! 	mov #1, r2
! 	shll2 r2
! 	shll2 r2
! 	shll2 r2
! 	tst r2, r1
! 	bf on_irq_yuv_complete

! 	bra irq_filtered
! 	nop

! on_irq_ch2_dma:
! 	! read from ISTNRM twice more
! 	!
! 	! when we wrote to ISTNRM, that successfully cleared bit 19.
! 	! However, the interrupt is still being generated until we write to it
! 	! or read from it again.  This appears to be a bug on real hardware.
! 	!
! 	! Since the initial write to ISTNRM did successfully clear the bit, it
! 	! would be safe to omit the second write and instead rely upon the
! 	! filtering code below to ignore the second IRQ.  I'd expect that
! 	! most/all programs do this since Dreamcast multiplexes most interrupts
! 	! together onto a single line, and that is why I've never heard of
! 	! anybody else getting snagged on this behavior.
! 	mov.l r2, @r0
! 	mov.l @r0, r3
! 	mov.l @r0, r3

! 	mov.l addr_irq_count_ch2_dma, r0
! 	mov.l @r0, r1
! 	add #1, r1
! 	bra kill_me_now
! 	mov.l r1, @r0

! on_irq_yuv_complete:
! 	! clear IRQ and read from ISTNRM twice for reasons described above
! 	mov.l r2, @r0
! 	mov.l @r0, r3
! 	mov.l @r0, r3

! 	mov.l addr_irq_count_yuv_complete, r0
! 	mov.l @r0, r1
! 	add #1, r1
! 	bra kill_me_now
! 	mov.l r1, @r0

! irq_filtered:
! 	! old debug code I no longer need
! 	! mov.l addr_wtf_istnrm, r0
! 	! mov.l addr_intevt, r1
! 	! mov.l @r1, r1
! 	! mov.l r1, @r0

! kill_me_now:
! 	rte
! 	nop

! 	.align 4
! addr_intevt:
! 	.long 0xff000028
! irq_code_holly:
! 	.long 0x320
! irq_code_tuni0:
! 	.long 0x400
! addr_irq_count_ch2_dma:
! 	.long irq_count_ch2_dma
! addr_irq_count_yuv_complete:
! 	.long irq_count_yuv_complete
! irq_count_ch2_dma:
! 	.long 0
! irq_count_yuv_complete:
! 	.long 0
! addr_istnrm:
! 	.long 0xa05f6900
! addr_n_timer_overflows:
! 	.long n_timer_overflows
! n_timer_overflows:
! 	.long 0
.align 4
addr_tlb_miss_handler:
	.long 0
addr_invalid_addr_handler:
	.long 0
