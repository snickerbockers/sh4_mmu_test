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


.globl testcase_addr_error

	.align 2
testcase_addr_error:
	mov.l r8, @-r15
	mov.l r9, @-r15
	mov.l r10, @-r15
	sts.l pr, @-r15

	mov.l addr_invalid_addr_results, r8

	mov.l addr_addr_invalid_addr_handler, r0
	mov.l addr_my_invalid_addr_handler, r1
	mov.l r1, @r0

	! testcase 1 - jump to invalid address
	mov #0, r10
	mova after_testcase1, r0
	mov r0, r9
	mov.l invalid_addr, r0
	jsr @r0
	mov #45, r10 ! the exception handler will check for this to see if the delay slot ran

	.align 4
after_testcase1:

	mov.l addr_invalid_addr_results, r0
	lds.l @r15+, pr
	mov.l @r15+, r10
	mov.l @r15+, r9
	rts
	mov.l @r15+, r8

my_invalid_addr_handler:

	! check EXPEVT
	mov #0xe0, r1
	extu.b r1, r1
	mov.l mmu_base, r0
	mov.l @(0x24, r0), r0
	cmp/eq r1, r0
	bf my_invalid_addr_handler_error

	! check delay slot
	mov r10, r0
	cmp/eq #45, r0
	bt my_invalid_addr_handler_no_error

my_invalid_addr_handler_error:
	! either EXPEVT was wrong or
	! the delay slot did not execute,
	! so signal an error
	bra my_invalid_addr_handler_ret
	mov #0, r1

my_invalid_addr_handler_no_error:
	! delay slot executed
	stc spc, r1

my_invalid_addr_handler_ret:
	mov.l r1, @r8
	ldc r10, spc
	ldc r9, spc
	rte
	add #4, r8

	.align 4
mmu_base:
	.long 0xff000000
invalid_addr:
	.long 0xFFFFFD5D
addr_addr_invalid_addr_handler:
	.long addr_invalid_addr_handler
addr_my_invalid_addr_handler:
	.long my_invalid_addr_handler
	.set N_INVALID_ADDR_RESULTS, 1
invalid_addr_results:
	.space 4*N_INVALID_ADDR_RESULTS
addr_invalid_addr_results:
	.long invalid_addr_results
