/*
 *  GRUB  --  GRand Unified Bootloader
 *  Copyright (C) 2002,2003,2004,2006  Free Software Foundation, Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#ifndef GRUB_LOADER_MACHINE_HEADER
#define GRUB_LOADER_MACHINE_HEADER	1

/* It is necessary to export these functions, because normal mode commands
   reuse rescue mode commands.  */
void grub_rescue_cmd_linux (int argc, char *argv[]);
void grub_rescue_cmd_initrd (int argc, char *argv[]);

#endif /* ! GRUB_LOADER_MACHINE_HEADER */
