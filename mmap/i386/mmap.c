/* Mmap management. */
/*
 *  GRUB  --  GRand Unified Bootloader
 *  Copyright (C) 2009  Free Software Foundation, Inc.
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

#include <grub/machine/memory.h>
#include <grub/cpu/memory.h>
#include <grub/memory.h>
#include <grub/err.h>
#include <grub/misc.h>
#include <grub/mm.h>


#ifndef GRUB_MMAP_REGISTER_BY_FIRMWARE

void *
grub_mmap_malign_and_register (grub_uint64_t align, grub_uint64_t size,
			       int *handle, int type, int flags)
{
  void *ret;

  ret = grub_memalign_policy (align, size,
			      (flags & GRUB_MMAP_MALLOC_LOW)
			      ? GRUB_MM_MALLOC_LOW_END
			      : GRUB_MM_MALLOC_DEFAULT);

  if (! ret)
    {
      *handle = 0;
      return 0;
    }

  *handle = grub_mmap_register (PTR_TO_UINT64 (ret), size, type);
  if (! *handle)
    {
      grub_free (ret);
      return 0;
    }

  return ret;
}

void
grub_mmap_free_and_unregister (int handle)
{
  struct grub_mmap_region *cur;
  grub_uint64_t addr;

  for (cur = grub_mmap_overlays; cur; cur = cur->next)
    if (cur->handle == handle)
      break;

  if (! cur)
    return;

  addr = cur->start;

  grub_mmap_unregister (handle);

  grub_free (UINT_TO_PTR (addr));
}

#endif
