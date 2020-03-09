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

.globl testcase_tlb_miss_delay_slot


	.align 2

invalidate_tlb:
	! disable any existing TLB entries
	mov.l addr_mmu_base, r1
	mov.l @(16, r1), r0
	or #4, r0 ! TI bit
	rts
	mov.l r0, @(16, r1)

enable_mmu:
	! enable MMU address translation
	mov.l addr_mmu_base, r1
	mov.l @(16, r1), r0
	or #1, r0 ! AT bit
	rts
	mov.l r0, @(16, r1)

disable_mmu:
	! disable MMU address translation
	mov.l addr_mmu_base, r1
	mov.l @(16, r1), r0
	mov #1, r2
	not r2, r2
	and r2, r0
	rts
	mov.l r0, @(16, r1)

testcase_tlb_miss_delay_slot:

	! make sure we're in the P1 area to disable instruction address translation
	mov.l addr_tlb_miss_delay_slot_p1_area, r0
	mov.l p1_ptr_mask, r1
	and r1, r0
	mov.l p1_ptr_val, r1
	or r1, r0

	jmp @r0
	nop

tlb_miss_delay_slot_p1_area:
	mov.l r8, @-r15
	sts.l pr, @-r15

	mov.l addr_read_tlb_miss_results, r8

	bsr invalidate_tlb
	nop

	! set up the TLB handler
	mov.l addr_my_tlb_miss_handler, r0
	mov.l addr_addr_tlb_miss_handler, r1
	mov.l r0, @r1

	bsr enable_mmu
	nop

	! first testcase: a simple read which will miss the TLB
	xor r0, r0
	mov.l @r0, r0

skipit:
	bsr disable_mmu
	nop

	lds.l @r15+, pr
	mov.l addr_read_tlb_miss_results, r0
	rts
	mov.l @r15+, r8

my_tlb_miss_handler:

	stc spc, r1
	mov.l r1, @r8
	add #4, r8

	mov.l addr_skipit, r0
	ldc r0, spc

	rte
	nop

	.align 4
	! pointer to MMU registers
	! offset 0 - PTEH
	! offset 4 - PTEL
	! offset 8  - TTB
	! offset 12 - TEA
	! offset 16 - MMUCR
	! offset 52 - PTEA
addr_mmu_base:
	.long 0xff000000
addr_tlb_miss_delay_slot_p1_area:
	.long tlb_miss_delay_slot_p1_area
p1_ptr_mask:
	.long 0x1fffffff
p1_ptr_val:
	.long 0x80000000
bad_ptr:
	.long 0
addr_addr_tlb_miss_handler:
	.long addr_tlb_miss_handler
addr_my_tlb_miss_handler:
	.long my_tlb_miss_handler
addr_skipit:
	.long skipit

	.set N_READ_TLB_MISS_RESULTS, 1
read_tlb_miss_results:
	.space 4*N_READ_TLB_MISS_RESULTS
addr_read_tlb_miss_results:
	.long read_tlb_miss_results
