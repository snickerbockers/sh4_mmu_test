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

.globl testcase_data_tlb_miss


	.align 2

invalidate_tlb:
	! disable any existing TLB entries
	mov.l mmu_base, r1
	mov.l @(16, r1), r0
	or #4, r0 ! TI bit
	mov.l r0, @(16, r1)

	! need to make sure at least 8 instructions pass before we
	! return to the callee and it potentially does something involving the
	! mmu
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	nop

enable_mmu:
	! enable MMU address translation
	mov.l mmu_base, r1
	mov.l @(16, r1), r0
	or #1, r0 ! AT bit
	mov.l r0, @(16, r1)

	! need to make sure at least 8 instructions pass before we
	! return to the callee and it potentially does something involving the
	! mmu
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	nop

disable_mmu:
	! disable MMU address translation
	mov.l mmu_base, r1
	mov.l @(16, r1), r0
	mov #1, r2
	not r2, r2
	and r2, r0
	mov.l r0, @(16, r1)

	! need to make sure at least 8 instructions pass before we
	! return to the callee and it potentially does something involving the
	! mmu
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	rts
	nop

testcase_data_tlb_miss:

	! make sure we're in the P1 area to disable instruction address
	! translation
	mova testcase_data_tlb_miss_p1_area, r0
	mov #-1, r1
	shlr r1
	shlr r1
	shlr r1
	and r1, r0

	mov #1, r1
	rotr r1
	or r1, r0

	jmp @r0
	nop

.align 4
testcase_data_tlb_miss_p1_area:
	mov.l r8, @-r15
	mov.l r9, @-r15
	sts.l pr, @-r15

	mov.l addr_read_tlb_miss_results, r8

	bsr invalidate_tlb
	nop

	! set up the TLB handler
	mova my_tlb_miss_handler, r0
	mov.l addr_addr_tlb_miss_handler, r1
	mov.l r0, @r1

	bsr enable_mmu
	nop

	! first testcase: a simple read which will miss the TLB
	mova after_testcase1, r0
	mov r0, r9
	xor r0, r0
	mov.l @r0, r0

	.align 4
after_testcase1:

	! second testcase: a simple write which will miss the TLB
	mova after_testcase2, r0
	mov r0, r9
	xor r0, r0
	mov.l r0, @r0

	.align 4
after_testcase2:

	! third testcase: a read which will miss the TLB from within a branch
	! delay slot
	mova after_testcase3, r0
	mov r0, r9
	xor r0, r0

	! doesn't matter which label it jumps to because we won't get there
	bsr disable_mmu
	mov.l @r0, r0

	.align 4
after_testcase3:

	! fourth testcase: a write which will miss the TLB from within a branch
	! delay slot
	mova after_testcase4, r0
	mov r0, r9
	xor r0, r0

	! doesn't matter which label it jumps to because we won't get there
	bsr disable_mmu
	mov.l r0, @r0

	.align 4
after_testcase4:

	bsr disable_mmu
	nop

	lds.l @r15+, pr
	mov.l addr_read_tlb_miss_results, r0
	mov.l @r15+, r9
	rts
	mov.l @r15+, r8

.align 4
my_tlb_miss_handler:

	! validate that EXPEVT is either write-miss or read-miss
	! we don't check that it's the specific value it should be for the
	! given testcase, we just assume that if it's one of the two then it
	! must be right
	mov.l mmu_base, r0
	mov.l @(0x24, r0), r0
	cmp/eq #0x40, r0
	bt my_tlb_miss_handler_no_error
	cmp/eq #0x60, r0
	bt my_tlb_miss_handler_no_error

	bra my_tlb_miss_handler_ret
	mov #0, r1

my_tlb_miss_handler_no_error:
	stc spc, r1

my_tlb_miss_handler_ret:
	mov.l r1, @r8
	ldc r9, spc
	rte
	add #4, r8

	.align 4
	! pointer to MMU registers
	! offset 0 - PTEH
	! offset 4 - PTEL
	! offset 8  - TTB
	! offset 12 - TEA
	! offset 16 - MMUCR
	! offset 52 - PTEA
mmu_base:
	.long 0xff000000
addr_addr_tlb_miss_handler:
	.long addr_tlb_miss_handler

	.set N_READ_TLB_MISS_RESULTS, 4
read_tlb_miss_results:
	.space 4*N_READ_TLB_MISS_RESULTS
addr_read_tlb_miss_results:
	.long read_tlb_miss_results
