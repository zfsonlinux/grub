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
 * grub_vbe_bios_status_t grub_vbe_get_controller_info (struct grub_vbe_info_block *controller_info)
 *
 * Register allocations for parameters:
 * %eax		*controller_info
 */
FUNCTION(grub_vbe_bios_get_controller_info)
	pushl	%ebp
	pushl	%edi
	pushl	%edx

	movw	%ax, %di	/* Store *controller_info to %edx:%di.  */
	xorw	%ax, %ax
	shrl	$4, %eax
	mov	%eax, %edx	/* PROT_TO_REAL destroys %eax.  */

	PROT_TO_REAL
	.code16

	pushw	%es

	movw	%dx, %es	/* *controller_info is now on %es:%di.  */
	movw	$0x4f00, %ax
	int	$0x10

	movw	%ax, %dx	/* REAL_TO_PROT destroys %eax.  */

	popw	%es

	REAL_TO_PROT
	.code32

	movl	%edx, %eax
	andl	$0x0FFFF, %eax	/* Return value in %eax.  */

	pop	%edx
	popl	%edi
	popl	%ebp
	ret

/*
 * grub_vbe_status_t grub_vbe_bios_get_mode_info (grub_uint32_t mode,
 *						  struct grub_vbe_mode_info_block *mode_info)
 *
 * Register allocations for parameters:
 * %eax		mode
 * %edx		*mode_info
 */
FUNCTION(grub_vbe_bios_get_mode_info)
	pushl   %ebp
	pushl   %edi

	movl	%eax, %ecx	/* Store mode number to %ecx.  */

	movw    %dx, %di	/* Store *mode_info to %edx:%di.  */
	xorw    %dx, %dx
	shrl    $4, %edx

	PROT_TO_REAL
	.code16

	pushw   %es

	movw    %dx, %es	/* *mode_info is now on %es:%di.  */
	movw    $0x4f01, %ax
	int     $0x10

	movw    %ax, %dx        /* REAL_TO_PROT destroys %eax.  */

	popw    %es

	REAL_TO_PROT
	.code32

	movl    %edx, %eax
	andl    $0x0FFFF, %eax  /* Return value in %eax.  */

	popl    %edi
	popl    %ebp
	ret

/*
 * grub_vbe_status_t grub_vbe_bios_set_mode (grub_uint32_t mode,
 *					     struct grub_vbe_crtc_info_block *crtc_info)
 *
 * Register allocations for parameters:
 * %eax		mode
 * %edx		*crtc_info
 */
FUNCTION(grub_vbe_bios_set_mode)
	pushl	%ebp
	pushl	%ebx
	pushl	%edi

	movl	%eax, %ebx	/* Store mode in %ebx.  */

	movw    %dx, %di	/* Store *crtc_info to %edx:%di.  */
	xorw    %dx, %dx
	shrl    $4, %edx

	PROT_TO_REAL
	.code16

	pushw   %es

	movw    %dx, %es	/* *crtc_info is now on %es:%di.  */

	movw	$0x4f02, %ax
	int	$0x10

	movw	%ax, %dx	/* REAL_TO_PROT destroys %eax.  */

	popw	%es

	REAL_TO_PROT
	.code32

	movw	%dx, %ax
	andl	$0xFFFF, %eax	/* Return value in %eax.  */

	popl	%edi
	popl	%ebx
	popl	%ebp
	ret

/*
 * grub_vbe_status_t grub_vbe_bios_get_mode (grub_uint32_t *mode)
 *
 * Register allocations for parameters:
 * %eax		*mode
 */
FUNCTION(grub_vbe_bios_get_mode)
	pushl   %ebp
	pushl   %ebx
	pushl	%edi
	pushl	%edx
	pushl	%eax		/* Push *mode to stack.  */

	PROT_TO_REAL
	.code16

	movw    $0x4f03, %ax
	int     $0x10

	movw	%ax, %dx	/* REAL_TO_PROT destroys %eax.  */

	REAL_TO_PROT
	.code32

	popl	%edi		/* Pops *mode from stack to %edi.  */
	andl	$0xFFFF, %ebx
	movl	%ebx, (%edi)

	movw	%dx, %ax
	andl	$0xFFFF, %eax	/* Return value in %eax.  */

	popl	%edx
	popl	%edi
	popl    %ebx
	popl    %ebp
	ret

/*
 * grub_vbe_status_t grub_vbe_bios_getset_dac_palette_width (int set, int *dac_mask_size)
 *
 * Register allocations for parameters:
 * %eax		set
 * %edx		*dac_mask_size
 */
FUNCTION(grub_vbe_bios_getset_dac_palette_width)
	pushl	%ebp
	pushl	%ebx

	xorl	%ebx, %ebx

	/* If we only want to fetch the value, set %bl to 1.  */
	testl	%eax, %eax
	jne	1f
	incb	%bl
1:

	/* Put desired width in %bh.  */
	movl	(%edx), %eax
	movb	%al, %bh

	PROT_TO_REAL
	.code16

	movw	$0x4f08, %ax
	int	$0x10

	movw	%ax, %cx	/* REAL_TO_PROT destroys %eax.  */

	REAL_TO_PROT
	.code32

	/* Move result back to *dac_mask_size.  */
	xor	%eax, %eax
	movb	%bh, %al
	movl	%eax, (%edx)

	movw	%cx, %ax

	popl	%ebx
	popl	%ebp
	ret

/*
 * grub_vbe_status_t grub_vbe_bios_set_memory_window (grub_uint32_t window,
 *						      grub_uint32_t position);
 *
 * Register allocations for parameters:
 * %eax		window
 * %edx		position
 */
FUNCTION(grub_vbe_bios_set_memory_window)
	pushl	%ebp
	pushl	%ebx

	movl	%eax, %ebx

	PROT_TO_REAL
	.code16

	movw	$0x4f05, %ax
	andw	$0x00ff, %bx	/* BL = window, BH = 0, Set memory window.  */
	int	$0x10

	movw	%ax, %dx	/* REAL_TO_PROT destroys %eax.  */

	REAL_TO_PROT
	.code32

	movw	%dx, %ax
	andl	$0xFFFF, %eax	/* Return value in %eax.  */

	popl	%ebx
	popl	%ebp
	ret

/*
 * grub_vbe_status_t grub_vbe_bios_get_memory_window (grub_uint32_t window,
 * 						      grub_uint32_t *position);
 *
 * Register allocations for parameters:
 * %eax		window
 * %edx		*position
 */
FUNCTION(grub_vbe_bios_get_memory_window)
	pushl   %ebp
	pushl   %ebx
	pushl	%edi
	pushl	%edx		/* Push *position to stack.  */

	movl	%eax, %ebx	/* Store window in %ebx.  */

	PROT_TO_REAL
	.code16

	movw    $0x4f05, %ax
	andw	$0x00ff, %bx	/* BL = window.  */
	orw	$0x0100, %bx	/* BH = 1, Get memory window.  */
	int     $0x10

	movw	%ax, %bx	/* REAL_TO_PROT destroys %eax.  */

	REAL_TO_PROT
	.code32

	popl	%edi		/* pops *position from stack to %edi.  */
	andl	$0xFFFF, %edx
	movl	%edx, (%edi)	/* Return position to caller.  */

	movw	%bx, %ax
	andl	$0xFFFF, %eax	/* Return value in %eax.  */

	popl	%edi
	popl    %ebx
	popl    %ebp
	ret

/*
 * grub_vbe_status_t grub_vbe_bios_set_scanline_length (grub_uint32_t length)
 *
 * Register allocations for parameters:
 * %eax		length
 */
FUNCTION(grub_vbe_bios_set_scanline_length)
	pushl	%ebp
	pushl	%ebx
	pushl	%edx

	movl	%eax, %ecx	/* Store length in %ecx.  */

	PROT_TO_REAL
	.code16

	movw	$0x4f06, %ax
	movw	$0x0002, %bx	/* BL = 2, Set Scan Line in Bytes.  */
	int	$0x10

	movw	%ax, %dx	/* REAL_TO_PROT destroys %eax.  */

	REAL_TO_PROT
	.code32

	movw	%dx, %ax
	andl	$0xFFFF, %eax	/* Return value in %eax.  */

	popl	%edx
	popl	%ebx
	popl	%ebp
	ret

/*
 * grub_vbe_status_t grub_vbe_bios_get_scanline_length (grub_uint32_t *length)
 *
 * Register allocations for parameters:
 * %eax		*length
 */
FUNCTION(grub_vbe_bios_get_scanline_length)
	pushl   %ebp
	pushl   %ebx
	pushl	%edi
	pushl	%edx		/* Push *length to stack.  */

	PROT_TO_REAL
	.code16

	movw    $0x4f06, %ax
	movw	$0x0001, %bx	/* BL = 1, Get Scan Line Length (in bytes).  */
	int     $0x10

	movw	%ax, %dx	/* REAL_TO_PROT destroys %eax.  */

	REAL_TO_PROT
	.code32

	popl	%edi		/* Pops *length from stack to %edi.  */
	andl	$0xFFFF, %ebx
	movl	%ebx, (%edi)	/* Return length to caller.  */

	movw	%dx, %ax
	andl	$0xFFFF, %eax	/* Return value in %eax.  */

	popl	%edi
	popl    %ebx
	popl    %ebp
	ret

/*
 * grub_vbe_status_t grub_vbe_bios_set_display_start (grub_uint32_t x,
 *						      grub_uint32_t y)
 *
 * Register allocations for parameters:
 * %eax		x
 * %edx		y
 */
FUNCTION(grub_vbe_bios_set_display_start)
	pushl	%ebp
	pushl	%ebx

	movl	%eax, %ecx	/* Store x in %ecx.  */

	PROT_TO_REAL
	.code16

	movw	$0x4f07, %ax
	movw	$0x0080, %bx	/* BL = 80h, Set Display Start
				   during Vertical Retrace.  */
	int	$0x10

	movw	%ax, %dx	/* REAL_TO_PROT destroys %eax.  */

	REAL_TO_PROT
	.code32

	movw	%dx, %ax
	andl	$0xFFFF, %eax	/* Return value in %eax.  */

	popl	%ebx
	popl	%ebp
	ret

/*
 * grub_vbe_status_t grub_vbe_bios_get_display_start (grub_uint32_t *x,
 *						      grub_uint32_t *y)
 *
 * Register allocations for parameters:
 * %eax		*x
 * %edx		*y
 */
FUNCTION(grub_vbe_bios_get_display_start)
	pushl   %ebp
	pushl   %ebx
	pushl	%edi
	pushl	%eax		/* Push *x to stack.  */
	pushl	%edx		/* Push *y to stack.  */

	PROT_TO_REAL
	.code16

	movw    $0x4f07, %ax
	movw	$0x0001, %bx	/* BL = 1, Get Display Start.  */
	int     $0x10

	movw	%ax, %bx	/* REAL_TO_PROT destroys %eax.  */

	REAL_TO_PROT
	.code32

	popl	%edi		/* Pops *y from stack to %edi.  */
	andl	$0xFFFF, %edx
	movl	%edx, (%edi)	/* Return y-position to caller.  */

	popl	%edi		/* Pops *x from stack to %edi.  */
	andl	$0xFFFF, %ecx
	movl	%ecx, (%edi)	/* Return x-position to caller.  */

	movw	%bx, %ax
	andl	$0xFFFF, %eax	/* Return value in %eax.  */

	popl	%edi
	popl    %ebx
	popl    %ebp
	ret

/*
 * grub_vbe_status_t grub_vbe_bios_set_palette_data (grub_uint32_t color_count,
 *						     grub_uint32_t start_index,
 *						     struct grub_vbe_palette_data *palette_data)
 *
 * Register allocations for parameters:
 * %eax		color_count
 * %edx		start_index
 * %ecx		*palette_data
 */
FUNCTION(grub_vbe_bios_set_palette_data)
	pushl	%ebp
	pushl	%ebx
	pushl	%edi

	movl	%eax, %ebx	/* Store color_count in %ebx.  */

	movw    %cx, %di	/* Store *palette_data to %ecx:%di.  */
	xorw    %cx, %cx
	shrl    $4, %ecx

	PROT_TO_REAL
	.code16

	pushw   %es

	movw    %cx, %es	/* *palette_data is now on %es:%di.  */
	movw	%bx, %cx	/* color_count is now on %cx.  */

	movw	$0x4f09, %ax
	xorw	%bx, %bx	/* BL = 0, Set Palette Data.  */
	int	$0x10

	movw	%ax, %dx	/* REAL_TO_PROT destroys %eax.  */

	popw	%es

	REAL_TO_PROT
	.code32

	movw	%dx, %ax
	andl	$0xFFFF, %eax	/* Return value in %eax.  */

	popl	%edi
	popl	%ebx
	popl	%ebp
	ret
