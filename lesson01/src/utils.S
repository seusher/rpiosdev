.globl put32
put32:				// x0 = The address to write to, w1 = the value to store
	str w1,[x0]		// Store the second value passed in (w1) into the provided address.
	ret

.globl get32
get32:
	ldr w0,[x0]		// Loads the value of w0 into the address specified at x0. w0 is the 32-bit reg which is the first half of x0.
					// x0 is both the standard reg for the first func argument as well as the standard reg for return values.
	ret

.globl delay
delay:
	subs x0, x0, #1
	bne delay
	ret
