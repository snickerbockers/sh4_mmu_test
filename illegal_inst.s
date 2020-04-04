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

	.global testcase_illegal_inst

	.balign 2
testcase_illegal_inst:

	mov.l r8, @-r15
	sts.l pr, @-r15

	mov.l ptr_to_addr_general_illegal_inst_handler, r1
	mova on_illegal_inst, r0
	mov.l r0, @r1

	mov.l ptr_to_addr_trap_handler, r1
	mova on_trapa, r0
	mov.l r0, @r1

	mov.l addr_invalidate_tlb, r0
	jsr @r0
	nop

	mov.l addr_enable_mmu, r0
	jsr @r0
	nop

	! first let's get into user-mode
	mov.l mmu_base, r1

	! load PPN into r3 and clear upper 3 bits and lower 10 bits
	mova addr_in_usermode, r0
	mov.l @r0+, r3
	shll2 r3
	shll r3
	shlr2 r3
	shlr r3
	shlr8 r3
	shlr2 r3
	shll8 r3
	shll2 r3

	! now load r3 into ptel
	! v (bit 8) - 1
	! sz (bit 7) - 0
	! pr (bit 6-5) - 2
	! sz (bit 4) - 1
	! ergo value is 1 0101 0000
	mov #0x15, r4
	shll2 r4
	shll2 r4
	or r4, r3
	mov.l r3, @(4, r1)

	! set up pteh.  VPN doesn't really matter so let's use 0
	mov #0, r3
	mov.l r3, @r1

	! now set up ptea.  I don't think this matters
	mov.l r3, @(0x34, r1)

	! issue the ldtlb instruction
	ldtlb

	! let her rip!
	mov #0, r0
	ldc r0, spc
	mov.l usermode_sr_val, r1
	ldc r1, ssr
	mova return_sr, r0
	add #4, r0
	stc.l sr, @-r0
	mova return_pr, r0
	add #4, r0
	sts.l pr, @-r0
	mova return_sp, r0
	add #4, r0
	mov.l r15, @-r0
	rte
	nop

after_excp:
	mov.l return_sp, r15

	mov.l addr_disable_mmu, r0
	jsr @r0
	nop

	lds.l @r15+, pr
	mov r8, r0
	rts
	mov.l @r15+, r8
	
.balign 4
on_illegal_inst:
	mov.l return_sr, r0
	ldc r0, ssr
	mov.l return_pr, r0
	lds r0, pr
	mov.l addr_after_excp, r0
	ldc r0, spc
	rte
	mov #0, r8

	.balign 4
on_trapa:
	mov.l return_sr, r0
	ldc r0, ssr
	mov.l return_pr, r0
	lds r0, pr
	mov.l addr_after_excp, r0
	ldc r0, spc
	rte
	mov #255, r8

	.balign 4
mmu_base:
	.long 0xff000000
addr_in_usermode:
	.long in_usermode
addr_after_excp:
	.long after_excp
usermode_sr_val:
	.long 0x00000000
addr_enable_mmu:
	.long enable_mmu
addr_disable_mmu:
	.long disable_mmu
addr_invalidate_tlb:
	.long invalidate_tlb
ptr_to_addr_general_illegal_inst_handler:
	.long addr_general_illegal_inst_handler
ptr_to_addr_trap_handler:
	.long addr_trap_handler
return_sr:
	.long 0
return_pr:
	.long 0
return_sp:
	.long 0

	.balign 4096
in_usermode:
	nop
	nop
	nop
	nop
	.word 0
	.word 0
	trapa #66
