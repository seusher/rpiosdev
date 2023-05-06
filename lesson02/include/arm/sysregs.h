#ifndef _SYSREGS_H
#define _SYSREGS_H

// ***************************************
// SCTLR_EL1, System Control Register (EL1), Page 2654 of AArch64-Reference-Manual.
// ***************************************

// Set the Reserved bits to 1
#define SCTLR_RESERVED                  (3 << 28) | (3 << 22) | (1 << 20) | (1 << 11) 
// 00110000110100000000100000000000

// AArch64 supports Pointer Authentication. Enabling this means code gets access to a pointer that's injected
// with some signatures to ensure they aren't tampered with.
// 2 keys for instruction addresses (APIAKey, APIBKey)
// 2 keys for data addresses (APDAKey, APDBKey)
// 1 key for generic authentication (APGAKey).
//
// I don't know when each key is used and what happens if I enable for A and disable for B, but it seems that
// it will be the kernel's job: https://www.kernel.org/doc/html/latest/arm64/pointer-authentication.html to
// assign keys to each process that is launched.
//
// The challenge here is that some of these bits WERE reserved, and are now used for real things:
//
// 31/30 = Disable Pointer Authentication for E1/o using both AKey and BKey (no longer reserved as of 8.3)
// 29 = Memory access is ordered and multi-load/stores can't be interrupted by interrupts. (no longer reserved as of 8.2)
// 28 = Don't trap Load Multiple and Store Multiple to Device. (no longer reserved as of 8.2)
// 23 = Doesn't disable Privileged Access Reads in E1 when taking an exception. (no longer reserved as of 8.1)
// 22 = Undocumented, still reserved.
// 20 = Undocumented, still reserved.
// 11 = Undocumented, still reserved.

#define SCTLR_EE_LITTLE_ENDIAN          (0 << 25)
#define SCTLR_EOE_LITTLE_ENDIAN         (0 << 24)
#define SCTLR_I_CACHE_DISABLED          (0 << 12)
#define SCTLR_D_CACHE_DISABLED          (0 << 2)
#define SCTLR_MMU_DISABLED              (0 << 0)
#define SCTLR_MMU_ENABLED               (1 << 0)

#define SCTLR_VALUE_MMU_DISABLED	(SCTLR_RESERVED | SCTLR_EE_LITTLE_ENDIAN | SCTLR_I_CACHE_DISABLED | SCTLR_D_CACHE_DISABLED | SCTLR_MMU_DISABLED)

// ***************************************
// HCR_EL2, Hypervisor Configuration Register (EL2), Page 2487 of AArch64-Reference-Manual.
// ***************************************

#define HCR_RW	    			        (1 << 31)
#define HCR_VALUE			            HCR_RW

// ***************************************
// SCR_EL3, Secure Configuration Register (EL3), Page 2648 of AArch64-Reference-Manual.
// ***************************************

// 110000
// Bits 4/5 = Reserved 1.
// 10 = Set execution state control to AArch64.
// 0 = EL 0/1 are in a Secure State and memory accesses can happen from those levels (they are non-secure).
#define SCR_RESERVED	    		    (3 << 4)
#define SCR_RW				            (1 << 10)
#define SCR_NS				            (1 << 0)
#define SCR_VALUE	    	    	    (SCR_RESERVED | SCR_RW | SCR_NS)

// ***************************************
// SPSR_EL3, Saved Program Status Register (EL3) Page 389 of AArch64-Reference-Manual.
// ***************************************

#define SPSR_MASK_ALL 			        (7 << 6)

// Don't use EL0's SP when taking an exception:
// https://developer.arm.com/documentation/ddi0488/d/programmers-model/armv8-architecture-concepts/stack-pointer-selection
// 'H' means 'handler' and 'T' means 'thread'.
//
// The SPSR register in the current EL is used to define which EL we return to when calling `eret`.
// M[3:2] define the exception level (00, 01, 11).
// M[1] is RES 0.
// M[0] defined 'h' or 't' (the SP) - 0 for 't' (SP0) and 1 for 'h' (EL's SP).
//
// (9 << 0) will bring us to EL2h
// (5 << 0) will bring up to EL1h
//
// I don't know how to jump to E0. Doing so results in the processor throwing an exception. We will probably figure that
// out when running programs, so it isn't worth dealing with right now.
//
// Here I define (M[3:2] | M[1] | M[0]) instead so it's clearer:
#define SPSR_EL1h			            (1 << 2 | 0 << 1 | 1 << 0)
#define SPSR_EL2h			            (2 << 2 | 0 << 1 | 1 << 0)

#define SPSR_EL1_VALUE			        (SPSR_MASK_ALL | SPSR_EL1h)
#define SPSR_EL2_VALUE			        (SPSR_MASK_ALL | SPSR_EL2h)

// ***************************************
// CPACR_EL1, Architectural Feature Access Control Register (EL1) Page 2411 of AArch64-Reference-Manual.
// ***************************************
#define CPACR_MASK_ALL                  0xFFFFFFFF
#define CPACR_ENABLE_FPEN               (3 << 20)

#endif
