#ifndef GRUB_CPU_MEMORY_HEADER
#define GRUB_CPU_MEMORY_HEADER	1

#include <grub/symbol.h>

#ifdef __apple__
#define LOWMEM_SECTION "_lowmem, _lowmem"
#else
#define LOWMEM_SECTION ".lowmem"
#endif

#ifdef ASM_FILE
#define LOWMEM .section LOWMEM_SECTION, "ax"
#else
#define LOWMEM __attribute__ ((section (LOWMEM_SECTION)))
#endif

#define GRUB_MM_MALLOC_LOW 2
#define GRUB_MM_MALLOC_LOW_END 3

#ifndef ASM_FILE
void EXPORT_FUNC(grub_real_to_prot) (void);
void EXPORT_FUNC(grub_prot_to_real) (void);
#ifdef GRUB_MACHINE_PCBIOS
/* Turn on/off Gate A20.  */
void EXPORT_FUNC(grub_gate_a20) (int on);
#endif
#endif

#ifdef ASM_FILE
#define REAL_TO_PROT 	DATA32	lcall	$0, $(EXT_C(grub_real_to_prot))
#define PROT_TO_REAL	call	EXT_C(grub_prot_to_real)
#endif

/* The flag for protected mode.  */
#define GRUB_MEMORY_CPU_CR0_PE_ON		0x1
#define GRUB_MEMORY_CPU_CR4_PAE_ON		0x00000040
#define GRUB_MEMORY_CPU_CR0_PAGING_ON		0x80000000
#define GRUB_MEMORY_CPU_AMD64_MSR		0xc0000080
#define GRUB_MEMORY_CPU_AMD64_MSR_ON		0x00000100

#endif
