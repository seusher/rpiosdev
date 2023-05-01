#include "mm.h"

.section ".text.boot"

.globl _start
_start:
	 nop
	 nop
	 //nop					// Uncommenting this line will cause all of the cores to try and initialize the Uart and they get stuck.

	/*
		Code Execution:

		The code always seems to start all cores running at memory location 0x078:

			(lldb) thread list
			Process 1 stopped
			* thread #1: tid = 0x0001, 0x0000000000000078 kernel8.elf`uart_send(c=<unavailable>) at mini_uart.c:6, stop reason = signal SIGTRAP
			thread #2: tid = 0x0002, 0x0000000000000078 kernel8.elf`uart_send(c=<unavailable>) at mini_uart.c:6
			thread #3: tid = 0x0003, 0x0000000000000078 kernel8.elf`uart_send(c=<unavailable>) at mini_uart.c:6
			thread #4: tid = 0x0004, 0x0000000000000078 kernel8.elf`uart_send(c=<unavailable>) at mini_uart.c:6

		This is the start of the `.text` section and not the `.text.boot` section, which makes sense since `.text` is the code section.

		$ objdump --arch=aarch64 -d ./build/kernel_c.o

		Disassembly of section .text.boot:

			0000000000000000 <_start>:
				0: 1f 20 03 d5  	nop
				4: 1f 20 03 d5  	nop
				8: 1f 20 03 d5  	nop
				c: a0 00 38 d5  	mrs	x0, MPIDR_EL1
				10: 00 1c 40 92  	and	x0, x0, #0xff
				14: e2 03 00 aa  	mov	x2, x0

				...
				[The rest of the code in .text.boot]
				...

			Disassembly of section .text:

			0000000000000078 <uart_send>:
				78: fd 7b be a9  	stp	x29, x30, [sp, #-32]!
				7c: fd 03 00 91  	mov	x29, sp
				80: a0 7f 00 39  	strb	w0, [x29, #31]
				84: 80 0a 8a d2  	mov	x0, #20564

				...
				[The rest of the code in .text]
				...

			I wonder if this is causing issues since all of the cores are running the uart_send() code which won't even have been invoked
			properly, the uart won't have been set up, and these cores all need to start at PC = 0x0000 to figure out if they should run
			uart initialization code at all.

			From https://wiki.osdev.org/Raspberry_Pi:

			When the RPi powers up the ARM CPU is halted and the GPU runs. The GPU loads the bootloader from rom and executes it. 
			That then finds the SD card and loads the bootcode.bin. The bootcode handles the config.txt and cmdline.txt 
			(or does start.elf read that?) and then runs start.elf. start.elf loads the kernel.img at 0x00008000, puts a few opcodes 
			at 0x00000000 and the ATAGS at 0x00000100 and at last the ARM CPU is started. The CPU starts executing at 0x00000000, where 
			it will initialize r0, r1 and r2 and jump to 0x00008000 where the kernel image starts.

			I wonder if this is part of the problem, and it is the difference between elf loading (which does things the Linux way) and
			kernel8.img loading, which does things the Pi way, but only runs the img on one core.
	*/

	/*
		Undefined Instruction Exception:

		When I uncomment the `nop` opcode, lldb shows me this:

			(lldb) next
			Process 1 stopped
			* thread #1, stop reason = step over
				frame #0: 0x000000000000026c kernel8.elf`uart_init at mini_uart.c:56
			Target 0: (kernel8.elf) stopped.

			(lldb) next
			Process 1 stopped
			* thread #1, stop reason = step over
				frame #0: 0x0000000000000000 kernel8.elf
			->  0x0: udf    #0x0
				0x4: nop
				0x8: nop
				0xc: mrs    x0, MPIDR_EL1

		I'm interested in the `udf` opcode, which is an "Undefined Instruction Exception" (F5.1.269). This seems to be what causes
		the infinite loop. When we hit it, the PC jumps back to 0x0200 and the code starts all over again:

			(lldb) next
			Process 1 stopped
			* thread #4, stop reason = step over
				frame #0: 0x0000000000000000 kernel8.elf
			->  0x0: udf    #0x0
				0x4: nop
				0x8: nop
				0xc: mrs    x0, MPIDR_EL1
			Target 0: (kernel8.elf) stopped.

			(lldb) next
			Process 1 stopped
			* thread #4, stop reason = instruction step over
				frame #0: 0x0000000000000200 kernel8.elf`uart_init at mini_uart.c:48
			Target 0: (kernel8.elf) stopped.

		The code at address 0x026c is the `ret` opcode at the end up uart_init().

		This is interesting because the objdump of boot_s.o shows three `nop` opcodes and not a `udf`:

			$ objdump --arch=aarch64 -d ./build/boot_s.o:

				0000000000000000 <_start>:
					0: 1f 20 03 d5  	nop
					4: 1f 20 03 d5  	nop
					8: 1f 20 03 d5  	nop
					c: a0 00 38 d5  	mrs	x0, MPIDR_EL1
					10: 00 1c 40 92  	and	x0, x0, #0xff
					14: e2 03 00 aa  	mov	x2, x0

		Perhaps the UDF is injected because the previous operation resulted in an exception.

		I need to get real hardware to check if this is a result of qemu booting elf files in the way Linux expects.
		It may be worth booting kernel8.img and having the code start the other cores to check.

		If I set a breakpoint at 0x026c and look at the x30 reg (Link Return), it's set to '0xd53800a0d503201f':

			(lldb) br set -a 0x000000000000026c
				Breakpoint 1: where = kernel8.elf`uart_init + 272 at mini_uart.c:56, address = 0x000000000000026c
			(lldb) c
			Process 1 resuming

			Process 1 stopped
			* thread #4, stop reason = breakpoint 1.1
				frame #0: 0x000000000000026c kernel8.elf`uart_init at mini_uart.c:56
			Target 0: (kernel8.elf) stopped.
			(lldb) thread list
			Process 1 stopped
			thread #1: tid = 0x0001, 0x0000000000000310 kernel8.elf`put32 + 4
			thread #2: tid = 0x0002, 0x000000000000026c kernel8.elf`uart_init at mini_uart.c:56
			thread #3: tid = 0x0003, 0x0000000000000310 kernel8.elf`put32 + 4
			* thread #4: tid = 0x0004, 0x000000000000026c kernel8.elf`uart_init at mini_uart.c:56, stop reason = breakpoint 1.1
			(lldb) register read
			general:
					x0 = 0x000000003f215060
					x1 = 0x0000000000000003
					...[omitted regs have a value of 0x0]...
					x29 = 0xd503201f00000000
					x30 = 0xd53800a0d503201f
					sp = 0x0000000000000020
					pc = 0x000000000000026c  kernel8.elf`uart_init + 272 at mini_uart.c:56

		The next execution tries to return to a memory address that's based on x30 and fails:

			(lldb) next
			Process 1 stopped
			* thread #4, stop reason = step over failed (Could not create return address breakpoint.)
				frame #0: 0x00000020d503201f
			error: memory read failed for 0x20d5032000
			Target 0: (kernel8.elf) stopped.
			(lldb) thread list
			Process 1 stopped
			thread #1: tid = 0x0001, 0x0000000000000310 kernel8.elf`put32 + 4
			thread #2: tid = 0x0002, 0x000000000000026c kernel8.elf`uart_init at mini_uart.c:56
			thread #3: tid = 0x0003, 0x0000000000000310 kernel8.elf`put32 + 4
			* thread #4: tid = 0x0004, 0x00000020d503201f, stop reason = step over failed (Could not create return address breakpoint.)

		Even in the *working scenario*, we end up in a similar situation, and it somehow recovers:

			(lldb) br set -a 0x268
			Breakpoint 1: where = kernel8.elf`uart_init + 272 at mini_uart.c:56, address = 0x0000000000000268
			(lldb) c
			Process 1 resuming

			Process 1 stopped
			* thread #4, stop reason = breakpoint 1.1
				frame #0: 0x0000000000000268 kernel8.elf`uart_init at mini_uart.c:56
			Target 0: (kernel8.elf) stopped.
			(lldb) thread info
			thread #4: tid = 0x0004, 0x0000000000000268 kernel8.elf`uart_init at mini_uart.c:56, stop reason = breakpoint 1.1

			(lldb) thread list
			Process 1 stopped
			thread #1: tid = 0x0001, 0x0000000000000268 kernel8.elf`uart_init at mini_uart.c:56
			thread #2: tid = 0x0002, 0x0000000000000268 kernel8.elf`uart_init at mini_uart.c:56
			thread #3: tid = 0x0003, 0x0000000000000074 kernel8.elf`uart_send(c=<unavailable>) at mini_uart.c:6
			* thread #4: tid = 0x0004, 0x0000000000000268 kernel8.elf`uart_init at mini_uart.c:56, stop reason = breakpoint 1.1

			(lldb) register read
			general:
					x0 = 0x000000003f215060
					x1 = 0x0000000000000003
					...[omitted regs have a value of 0x0]...
					x29 = 0xd503201fd503201f
					x30 = 0x92401c00d53800a0
					sp = 0x0000000000000020
					pc = 0x0000000000000268  kernel8.elf`uart_init + 272 at mini_uart.c:56
					cpsr = 0x000003cd

			(lldb) si
			Process 1 stopped
			* thread #4, stop reason = instruction step into
				frame #0: 0x00000000d53800a0
			error: memory read failed for 0xd5380000
			Target 0: (kernel8.elf) stopped.

			(lldb) si
			Process 1 stopped
			* thread #4, stop reason = instruction step into
				frame #0: 0x0000000000000200 kernel8.elf`uart_init at mini_uart.c:49
			Target 0: (kernel8.elf) stopped.

			(lldb) si
			Process 1 stopped
			* thread #4, stop reason = instruction step into
				frame #0: 0x0000000000000204 kernel8.elf`uart_init at mini_uart.c:49
			Target 0: (kernel8.elf) stopped.

			(lldb) si
			Process 1 stopped
			* thread #4, stop reason = instruction step into
				frame #0: 0x0000000000000208 kernel8.elf`uart_init at mini_uart.c:49
			Target 0: (kernel8.elf) stopped.

		Somehow the code went from jumping to 0xd5380000 and failing, to running at 0x200, which is the line right after
		where uart_init() jumps to put32() to call `put32(AUX_MU_CNTL_REG,0)`:

			1f0: 21 00 80 52  	mov	w1, #1
			1f4: 80 00 8a d2  	mov	x0, #20484
			1f8: 20 e4 a7 f2  	movk	x0, #16161, lsl #16
			1fc: 43 00 00 94  	bl	0x308 <put32>
			200: 01 00 80 52  	mov	w1, #0
			204: 00 0c 8a d2  	mov	x0, #20576
			208: 20 e4 a7 f2  	movk	x0, #16161, lsl #16
			20c: 3f 00 00 94  	bl	0x308 <put32>

		Since this all seems to happen around:

			264: fd 7b c2 a8  	ldp	x29, x30, [sp], #32

		I wonder if I'm not setting up the stack space for each core correctly and that's causing issues.
	*/

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
procid:
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