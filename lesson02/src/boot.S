#include "arm/sysregs.h"

#include "mm.h"

.section ".text.boot"

.globl _start
_start:
	mrs	x0, mpidr_el1		
	and	x0, x0,#0xFF		// Check processor id
	cbz	x0, master		// Hang for all non-primary CPU
	b	proc_hang

proc_hang: 
	b 	proc_hang

master:

	// Disable the MMU until Lesson 06
	ldr	x0, =SCTLR_VALUE_MMU_DISABLED 
	msr	sctlr_el1, x0		

	// Set EL1 execution state to 64 bits
	ldr	x0, =HCR_VALUE
	msr	hcr_el2, x0

	ldr	x0, =SCR_VALUE
	msr	scr_el3, x0

	// Eret to EL2
	ldr	x0, =SPSR_EL2h
	msr	spsr_el3, x0

	adr	x0, el2_entry		
	msr	elr_el3, x0

	eret	

el2_entry:

	// ERET to EL1
	ldr	x0, =SPSR_EL1h
	msr	spsr_el2, x0

	adr	x0, el1_entry		
	msr	elr_el2, x0

	ldr x0, =CPACR_ENABLE_FPEN
	msr cpacr_el1, x0

	eret			

el1_entry:
	adr	x0, bss_begin
	adr	x1, bss_end
	sub	x1, x1, x0
	bl 	memzero

	mov	sp, #LOW_MEMORY
	bl	kernel_main
	b 	proc_hang		// should never come here

/*
Output with `-d int` to debug interrupts (which let's us see when exceptions happen):

❯ qemu-system-aarch64 -M raspi3b -device loader,file=./kernel8.img,addr=0x0 -smp 4 -serial null -serial stdio -display none -d int
Exception return from AArch64 EL3 to AArch64 EL2 PC 0x40
Exception return from AArch64 EL2 to AArch64 EL1 PC 0x54
Exception level: 1

*/