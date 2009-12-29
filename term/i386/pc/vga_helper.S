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
 * unsigned char grub_vga_set_mode (unsigned char mode)
 */
FUNCTION(grub_vga_set_mode)
	pushl	%ebp
	pushl	%ebx
	movl	%eax, %ecx

	PROT_TO_REAL
	.code16
	/* get current mode */
	xorw	%bx, %bx
	movb	$0x0f, %ah
	int	$0x10
	movb	%al, %dl

	/* set the new mode */
	movb	%cl, %al
	xorb	%ah, %ah
	int	$0x10

	REAL_TO_PROT
	.code32

	movb	%dl, %al
	popl	%ebx
	popl	%ebp
	ret


