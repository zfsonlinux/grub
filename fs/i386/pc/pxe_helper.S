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

pxe_rm_entry:
	.long	0

/*
 * struct grub_pxenv *grub_pxe_scan (void);
 */
FUNCTION(grub_pxe_scan)
	pushl	%ebp
	pushl	%ebx

	xorl	%ebx, %ebx
	xorl	%ecx, %ecx

	PROT_TO_REAL
	.code16

	pushw	%es

	movw	$0x5650, %ax
	int	$0x1A
	cmpw	$0x564E, %ax
	jnz	1f
	cmpl	$0x4E455850, %es:(%bx)		/* PXEN(V+)  */
	jnz	1f
	cmpw	$0x201, %es:6(%bx)		/* API version  */
	jb	1f
	lesw	%es:0x28(%bx), %bx		/* !PXE structure  */
	cmpl	$0x45585021, %es:(%bx)		/* !PXE  */
	jnz	1f
	movw	%es, %cx
	jmp	2f
1:
	xorw	%bx, %bx
	xorw	%cx, %cx
2:

	popw	%es

	REAL_TO_PROT
	.code32

	xorl	%eax, %eax
	leal	(%eax, %ecx, 4), %ecx
	leal	(%ebx, %ecx, 4), %eax		/* eax = ecx * 16 + ebx  */

	orl	%eax, %eax
	jz	1f

	movl	0x10(%eax), %ecx
	movl	%ecx, pxe_rm_entry

1:

	popl	%ebx
	popl	%ebp
	ret

/*
 * int grub_pxe_call (int func, void* data);
 */
FUNCTION(grub_pxe_call)
	pushl	%ebp
	movl	%esp, %ebp
	pushl	%esi
	pushl	%edi
	pushl	%ebx

	movl	%eax, %ecx
	movl	%edx, %eax
	andl	$0xF, %eax
	shrl	$4, %edx
	shll	$16, %edx
	addl	%eax, %edx
	movl	pxe_rm_entry, %ebx

	PROT_TO_REAL
	.code16

	pushl	%ebx
	pushl	%edx
	pushw	%cx
	movw	%sp, %bx
	lcall	*%ss:6(%bx)
	cld
	addw	$10, %sp
	movw	%ax, %cx

	REAL_TO_PROT
	.code32

	movzwl	%cx, %eax

	popl	%ebx
	popl	%edi
	popl	%esi
	popl	%ebp
	ret
