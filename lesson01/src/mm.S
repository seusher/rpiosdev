.globl memzero
memzero:
	str xzr, [x0], #8		// xzr is the zero register and always reads as zero.
							// This offset syntax is called post-indexed addressing and
							// stores 0 to the address of x0, and then adds 8 to x0.
	subs x1, x1, #8
	b.gt memzero			// If x1 > 0, go back to memzero and loop
	ret
