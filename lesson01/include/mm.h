#ifndef	_MM_H
#define	_MM_H

#define PAGE_SHIFT	 		    12
#define TABLE_SHIFT 			9
#define SECTION_SHIFT			(PAGE_SHIFT + TABLE_SHIFT)

#define PAGE_SIZE   			(1 << PAGE_SHIFT)	
#define SECTION_SIZE			(1 << SECTION_SHIFT)	

#define LOW_MEMORY              (2 * SECTION_SIZE)  // 4,194,304 bytes
#define SECONDARY_STACK_START	(1 << 20)           // Each core gets 1MB of stack

#ifndef __ASSEMBLER__

void memzero(unsigned long src, unsigned long n);

#endif

#endif  /*_MM_H */
