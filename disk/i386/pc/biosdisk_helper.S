/*
 *  GRUB  --  GRand Unified Bootloader
 *  Copyright (C) 1999,2000,2001,2002,2003,2005,2006,2007,2008 Free Software Foundation, Inc.
 *
 *  GRUB is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  GRUB is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with GRUB.  If not, see <http://www.gnu.org/licenses/>.
 */


#include <grub/symbol.h>
#include <grub/i386/memory.h>
	
	LOWMEM
	.code32


/*
 *   int grub_biosdisk_rw_int13_extensions (int ah, int drive, void *dap)
 *
 *   Call IBM/MS INT13 Extensions (int 13 %ah=AH) for DRIVE. DAP
 *   is passed for disk address packet. If an error occurs, return
 *   non-zero, otherwise zero.
 */

FUNCTION(grub_biosdisk_rw_int13_extensions)
	pushl	%ebp
	pushl	%esi

	/* compute the address of disk_address_packet */
	movw	%cx, %si
	xorw	%cx, %cx
	shrl	$4, %ecx	/* save the segment to cx */

	/* ah */
	movb	%al, %dh
	/* enter real mode */
	PROT_TO_REAL

	.code16
	movb	%dh, %ah
	movw	%cx, %ds
	int	$0x13		/* do the operation */
	movb	%ah, %dl	/* save return value */
	/* back to protected mode */
	REAL_TO_PROT
	.code32

	movb	%dl, %al	/* return value in %eax */

	popl	%esi
	popl	%ebp

	ret

/*
 *   int grub_biosdisk_rw_standard (int ah, int drive, int coff, int hoff,
 *                                  int soff, int nsec, int segment)
 *
 *   Call standard and old INT13 (int 13 %ah=AH) for DRIVE. Read/write
 *   NSEC sectors from COFF/HOFF/SOFF into SEGMENT. If an error occurs,
 *   return non-zero, otherwise zero.
 */

FUNCTION(grub_biosdisk_rw_standard)
	pushl	%ebp
	movl	%esp, %ebp

	pushl	%ebx
	pushl	%edi
	pushl	%esi

	/* set up CHS information */

	/* set %ch to low eight bits of cylinder */
	xchgb	%cl, %ch
	/* set bits 6-7 of %cl to high two bits of cylinder */
	shlb	$6, %cl
	/* set bits 0-5 of %cl to sector */
	addb	0xc(%ebp), %cl
	/* set %dh to head */
	movb	0x8(%ebp), %dh
	/* set %ah to AH */
	movb	%al, %ah
	/* set %al to NSEC */
	movb	0x10(%ebp), %al
	/* save %ax in %di */
	movw	%ax, %di
	/* save SEGMENT in %bx */
	movw	0x14(%ebp), %bx

	/* enter real mode */
	PROT_TO_REAL

	.code16
	movw	%bx, %es
	xorw	%bx, %bx
	movw	$3, %si		/* attempt at least three times */

1:
	movw	%di, %ax
	int	$0x13		/* do the operation */
	jnc	2f		/* check if successful */

	movb	%ah, %bl	/* save return value */
	/* if fail, reset the disk system */
	xorw	%ax, %ax
	int	$0x13

	decw	%si
	cmpw	$0, %si
	je	2f
	xorb	%bl, %bl
	jmp	1b		/* retry */
2:
	/* back to protected mode */
	REAL_TO_PROT
	.code32

	movb	%bl, %al	/* return value in %eax */

	popl	%esi
	popl	%edi
	popl	%ebx
	popl	%ebp

	ret	$(4 * 4)


/*
 *   int grub_biosdisk_check_int13_extensions (int drive)
 *
 *   Check if LBA is supported for DRIVE. If it is supported, then return
 *   the major version of extensions, otherwise zero.
 */

FUNCTION(grub_biosdisk_check_int13_extensions)
	pushl	%ebp
	pushl	%ebx

	/* drive */
	movb	%al, %dl
	/* enter real mode */
	PROT_TO_REAL

	.code16
	movb	$0x41, %ah
	movw	$0x55aa, %bx
	int	$0x13		/* do the operation */

	/* check the result */
	jc	1f
	cmpw	$0xaa55, %bx
	jne	1f

	movb	%ah, %bl	/* save the major version into %bl */

	/* check if AH=0x42 is supported */
	andw	$1, %cx
	jnz	2f

1:
	xorb	%bl, %bl
2:
	/* back to protected mode */
	REAL_TO_PROT
	.code32

	movb	%bl, %al	/* return value in %eax */

	popl	%ebx
	popl	%ebp

	ret


/*
 *   int grub_biosdisk_get_cdinfo_int13_extensions (int drive, void *cdrp)
 *
 *   Return the cdrom information of DRIVE in CDRP. If an error occurs,
 *   then return non-zero, otherwise zero.
 */

FUNCTION(grub_biosdisk_get_cdinfo_int13_extensions)
	movw	$0x4B01, %cx
	jmp	1f

/*
 *   int grub_biosdisk_get_diskinfo_int13_extensions (int drive, void *drp)
 *
 *   Return the geometry of DRIVE in a drive parameters, DRP. If an error
 *   occurs, then return non-zero, otherwise zero.
 */

FUNCTION(grub_biosdisk_get_diskinfo_int13_extensions)
	movb	$0x48, %ch
1:
	pushl	%ebp
	pushl	%ebx
	pushl	%esi

	/* compute the address of drive parameters */
	movw	%dx, %si
	andl	$0xf, %esi
	shrl	$4, %edx
	movw	%dx, %bx	/* save the segment into %bx */
	/* drive */
	movb	%al, %dl

	/* enter real mode */
	PROT_TO_REAL
	.code16
	
	movw	%cx, %ax
	movw	%bx, %ds
	int	$0x13		/* do the operation */
	jc      noclean
	/* Clean return value if carry isn't set to workaround
	some buggy BIOSes.  */
	xor     %ax, %ax

noclean:
	movb	%ah, %bl	/* save return value in %bl */

	/* back to protected mode */
	REAL_TO_PROT
	.code32

	movb	%bl, %al	/* return value in %eax */

	popl	%esi
	popl	%ebx
	popl	%ebp

	ret


/*
 *   int grub_biosdisk_get_diskinfo_standard (int drive,
 *                                            unsigned long *cylinders,
 *                                            unsigned long *heads,
 *                                            unsigned long *sectors)
 *
 *   Return the geometry of DRIVE in CYLINDERS, HEADS and SECTORS. If an
 *   error occurs, then return non-zero, otherwise zero.
 */

FUNCTION(grub_biosdisk_get_diskinfo_standard)
	pushl	%ebp
	pushl	%ebx
	pushl	%edi

	/* push CYLINDERS */
	pushl	%edx
	/* push HEADS */
	pushl	%ecx
	/* SECTORS is on the stack */

	/* drive */
	movb	%al, %dl
	/* enter real mode */
	PROT_TO_REAL

	.code16
	movb	$0x8, %ah
	int	$0x13		/* do the operation */
       jc      noclean2
       /* Clean return value if carry isn't set to workaround
       some buggy BIOSes.  */
       xor     %ax, %ax
noclean2:
	/* check if successful */
	testb	%ah, %ah
	jnz	1f
	/* bogus BIOSes may not return an error number */
	testb	$0x3f, %cl	/* 0 sectors means no disk */
	jnz	1f		/* if non-zero, then succeed */
	/* XXX 0x60 is one of the unused error numbers */
	movb	$0x60, %ah
1:
	movb	%ah, %bl	/* save return value in %bl */
	/* back to protected mode */
	REAL_TO_PROT
	.code32

	/* pop HEADS */
	popl	%edi
	movb	%dh, %al
	incl	%eax	/* the number of heads is counted from zero */
	movl	%eax, (%edi)

	/* pop CYLINDERS */
	popl	%edi
	movb	%ch, %al
	movb	%cl, %ah
	shrb	$6, %ah	/* the number of cylinders is counted from zero */
	incl	%eax
	movl	%eax, (%edi)

	/* SECTORS */
	movl	0x10(%esp), %edi
	andb	$0x3f, %cl
	movzbl	%cl, %eax
	movl	%eax, (%edi)

	xorl	%eax, %eax
	movb	%bl, %al	/* return value in %eax */

	popl	%edi
	popl	%ebx
	popl	%ebp

	ret	$4


/*
 * int grub_biosdisk_get_num_floppies (void)
 */
FUNCTION(grub_biosdisk_get_num_floppies)
	pushl	%ebp

	xorl	%edx, %edx
	PROT_TO_REAL

	.code16
	/* reset the disk system first */
	int	$0x13
1:
	stc

	/* call GET DISK TYPE */
	movb	$0x15, %ah
	int	$0x13

	jc	2f

	/* check if this drive exists */
	testb	$0x3, %ah
	jz	2f

	incb	%dl
	cmpb	$2, %dl
	jne	1b
2:
	REAL_TO_PROT
	.code32

	movl	%edx, %eax
	popl	%ebp
	ret
