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

	.globl vecbase
	.global addr_invalid_addr_handler
	.global addr_tlb_miss_handler
	.global addr_general_illegal_inst_handler
	.global addr_trap_handler

	.align 2
vecbase:
	.space 0x100
	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	!!
	!!                       VECTOR 0x100
	!!
	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	! load 0xff000000 into r1
	mov #0xff, r1
	shll8 r1
	shll8 r1
	shll8 r1

	# load expevt into r0
	mov.l @(0x24, r1), r0

	# INSTRUCTION ADDRESS AERROR
	mov #0xe0, r2
	extu.b r2, r2
	cmp/eq r0, r2
	bt vec_inst_addr_errorhandler

	# GENERAL ILLEGAL INSTRUCTION EXCEPTION
	mov #0x18, r2
	shll2 r2
	shll2 r2
	cmp/eq r0, r2
	bt vec_general_illegal_instruction_errorhandler

	# TRAPA INSTRUCTION
	mov #0x16, r2
	shll2 r2
	shll2 r2
	cmp/eq r0, r2
	bt vec_trap_errorhandler

	# unknown exception, just loop forever i guess
unknown_excp_0x100:
	bra unknown_excp_0x100
	nop

vec_inst_addr_errorhandler:
	mov.l addr_invalid_addr_handler, r0
	jmp @r0
	nop

vec_general_illegal_instruction_errorhandler:
	mov.l addr_general_illegal_inst_handler, r0
	jmp @r0
	nop

vec_trap_errorhandler:
	mov.l addr_trap_handler, r0
	jmp @r0
	nop

end_of_vector_100:
	.space vecbase + 0x400 - end_of_vector_100

	! .space 0x2e4
	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	!!
	!!                       VECTOR 0x400
	!!
	!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	! load 0xff000000 into r1
	mov #0xff, r1
	shll8 r1
	shll8 r1
	shll8 r1

	# load expevt into r0
	mov.l @(0x24, r1), r0

	# tlb data miss for read or excpetion fetch
	mov #0x40, r2
	cmp/eq r0, r2
	bt vec_tlb_miss_handler

	mov #0x60, r2
	cmp/eq r0, r2
	bt vec_tlb_miss_handler

	# unknown exception, just loop forever i guess
unknown_excp_0x400:
	bra unknown_excp_0x400
	nop

vec_tlb_miss_handler:
	mov.l addr_tlb_miss_handler, r0
	jmp @r0
	nop

	.align 4
addr_tlb_miss_handler:
	.long 0
addr_invalid_addr_handler:
	.long 0
addr_general_illegal_inst_handler:
	.long 0
addr_trap_handler:
	.long 0
