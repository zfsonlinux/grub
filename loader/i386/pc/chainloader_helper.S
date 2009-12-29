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
#include <grub/cpu/memory.h>
#include <grub/machine/memory.h>
	
	LOWMEM
	.code32

/*
 *  void grub_chainloader_real_boot (int drive, void *part_addr)
 *
 *  This starts another boot loader.
 */

FUNCTION(grub_chainloader_real_boot)
	pushl	%edx
	pushl	%eax

	/* Turn off Gate A20 */
	xorl	%eax, %eax
	call	EXT_C(grub_gate_a20)

	/* set up to pass boot drive */
	popl	%edx

	/* ESI must point to a partition table entry */
	popl	%esi

	PROT_TO_REAL
	.code16
	ljmp	$0, $GRUB_MEMORY_MACHINE_BOOT_LOADER_ADDR
	.code32
