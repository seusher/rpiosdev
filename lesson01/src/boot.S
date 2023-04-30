#include "mm.h"

.section ".text.boot"

.globl _start
_start:
	 nop
	 nop
	// nop					// Uncommenting this line will cause all of the cores to try and initialize the Uart and they get stuck.

	/*
		This is the gdb view when having the wrong number of NOPs in place. Thread 1 (CPU#0) jumps to some unknown frame, which also happens
		in the happy-path, but at that point, the code comes back and doesnt go back to _start.

			Cannot find bounds of current function
			(gdb) info threads
			Id   Target Id                    Frame
			* 1    Thread 1.1 (CPU#0 [running]) 0xd53800a0d503201f in ?? ()
			2    Thread 1.2 (CPU#1 [running]) 0x0000000000000310 in put32 ()
			3    Thread 1.3 (CPU#2 [running]) 0x000000000000024c in uart_init () at src/mini_uart.c:53
			4    Thread 1.4 (CPU#3 [running]) 0x0000000000000220 in uart_init () at src/mini_uart.c:50

			It then later loops back to _start:

			(gdb) info threads
			Id   Target Id                    Frame
			* 1    Thread 1.1 (CPU#0 [running]) 0x0000000000000000 in _start ()
			2    Thread 1.2 (CPU#1 [running]) 0x0000000000000310 in put32 ()
			3    Thread 1.3 (CPU#2 [running]) 0x0000000000000310 in put32 ()
			4    Thread 1.4 (CPU#3 [running]) 0x000000000000021c in uart_init () at src/mini_uart.c:50

		It also seems like in the happy-path case, the cores start in uart_init(), execute the initialization code,
		and then move around in some unknown memory space, before eventually jumping to the 'master' label, which is
		where we want the code to end up

			uart_init () at src/mini_uart.c:49
			49		put32(AUX_MU_CNTL_REG,0);               //Disable auto flow control and disable receiver and transmitter (for now)
			(gdb) info threads
			Id   Target Id                    Frame
			* 1    Thread 1.1 (CPU#0 [running]) uart_init () at src/mini_uart.c:49
			2    Thread 1.2 (CPU#1 [running]) 0x0000000000000204 in uart_init () at src/mini_uart.c:49
			3    Thread 1.3 (CPU#2 [running]) 0x0000000000000208 in uart_init () at src/mini_uart.c:49
			4    Thread 1.4 (CPU#3 [running]) 0x0000000000000208 in uart_init () at src/mini_uart.c:49
			(gdb) s

			(gdb) info threads
			Id   Target Id                    Frame
			* 1    Thread 1.1 (CPU#0 [running]) 0x92401c00d53800a0 in ?? ()
			2    Thread 1.2 (CPU#1 [running]) 0x0000000000000308 in put32 ()
			3    Thread 1.3 (CPU#2 [running]) 0x0000000000000308 in put32 ()
			4    Thread 1.4 (CPU#3 [running]) 0x000000000000030c in put32 ()
			(gdb) c

			Thread 1 hit Breakpoint 1, 0x0000000000000054 in master ()
			(gdb) info threads
			Id   Target Id                    Frame
			* 1    Thread 1.1 (CPU#0 [running]) 0x0000000000000054 in master ()
			2    Thread 1.2 (CPU#1 [running]) 0x000000000000031c in delay ()
			3    Thread 1.3 (CPU#2 [running]) 0x000000000000031c in delay ()
			4    Thread 1.4 (CPU#3 [running]) 0x0000000000000318 in delay ()
			(gdb) s

			(gdb) info threads
			Id   Target Id                    Frame
			* 1    Thread 1.1 (CPU#0 [running]) 0x000000000000001c in proc_hang ()
			2    Thread 1.2 (CPU#1 [running]) 0x000000000000001c in proc_hang ()
			3    Thread 1.3 (CPU#2 [running]) 0x000000000000001c in proc_hang ()
			4    Thread 1.4 (CPU#3 [running]) 0x000000000000001c in proc_hang ()

		A successful execution results in all cores looping in proc_hang().
		This is all very confusing, but I assume there is some obvious thing that Im missing.
	*/

	mrs	x0, mpidr_el1		
	and	x0, x0, #0xFF					// Check processor id
	mov x2, x0 							// Backup the processor id

	cbz	x0, master						// Core 0 is in charge of initializing the uart and zeroing .bss
	b 	nonmaster						// All other cores initialize their own SP and then try to use the uart.

proc_hang: 
	b 	proc_hang

nonmaster:
	mrs	x19, mpidr_el1		
	and	x19, x19, #0xFF					// Check processor id again...but why cant we use the previous value? TODO: Figure that out.

	sub x18, x19, #0					// Chose which other core is active. Using #0 means all cores are active.
	cbz x18, proc_hang

	mov 	x0, SECONDARY_STACK_START	// Secondary stack size is 1MB
	mul 	x2, x0, x19					// calculate SP for each core 1MB * CoreId
	mov 	sp, x2						// setup sp for this core

	mov	x1, #30000
	mul	x0, x1, x19						// calc delay for each core
	bl	delay

	mov	x0, x19							// Restore x0 to pass CoreId as param to kernel_other
	bl kernel_other

	b proc_hang

master:
	adr	x0, bss_begin
	adr	x1, bss_end
	sub	x1, x1, x0
	bl 	memzero

	mov		sp, #LOW_MEMORY		 		// Set the stack pointer to 4,194,304 bytes (4MB) - defined in mm.h

	mov x0, x2
	bl	kernel_main
	b 	proc_hang						// should never come here