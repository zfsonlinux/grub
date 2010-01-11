/* mm.c - functions for memory manager */
/*
 *  GRUB  --  GRand Unified Bootloader
 *  Copyright (C) 2002,2005,2007,2008,2009  Free Software Foundation, Inc.
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

/*
  The design of this memory manager.

  This is a simple implementation of malloc with a few extensions. These are
  the extensions:

  - memalign is implemented efficiently.

  - multiple regions may be used as free space. They may not be
  contiguous.

  Regions are managed by a singly linked list, and the meta information is
  stored in the beginning of each region. Space after the meta information
  is used to allocate memory.

  The memory space is used as cells instead of bytes for simplicity. This
  is important for some CPUs which may not access multiple bytes at a time
  when the first byte is not aligned at a certain boundary (typically,
  4-byte or 8-byte). The size of each cell is equal to the size of struct
  grub_mm_header, so the header of each allocated/free block fits into one
  cell precisely. One cell is 16 bytes on 32-bit platforms and 32 bytes
  on 64-bit platforms.

  There are two types of blocks: allocated blocks and free blocks.

  In allocated blocks, the header of each block has only its size. Note that
  this size is based on cells but not on bytes. The header is located right
  before the returned pointer, that is, the header resides at the previous
  cell.

  Free blocks constitutes a ring, using a singly linked list. The first free
  block is pointed to by the meta information of a region. The allocator
  attempts to pick up the second block instead of the first one. This is
  a typical optimization against defragmentation, and makes the
  implementation a bit easier.

  For safety, both allocated blocks and free ones are marked by magic
  numbers. Whenever anything unexpected is detected, GRUB aborts the
  operation.
 */

#include <config.h>
#include <grub/mm.h>
#include <grub/misc.h>
#include <grub/err.h>
#include <grub/types.h>
#include <grub/disk.h>
#include <grub/dl.h>

#ifdef MM_DEBUG
# undef grub_malloc
# undef grub_zalloc
# undef grub_realloc
# undef grub_free
# undef grub_memalign
#endif

/* Magic words.  */
#define GRUB_MM_FREE_MAGIC	0x2d3c2808
#define GRUB_MM_ALLOC_MAGIC	0x6db08fa4

typedef struct grub_mm_header
{
  struct grub_mm_header *prev;
  struct grub_mm_header *next;
  grub_size_t size;
  grub_size_t magic;
}
*grub_mm_header_t;

#if GRUB_CPU_SIZEOF_VOID_P == 4
# define GRUB_MM_ALIGN_LOG2	4
#elif GRUB_CPU_SIZEOF_VOID_P == 8
# define GRUB_MM_ALIGN_LOG2	5
#endif

#define GRUB_MM_ALIGN	(1 << GRUB_MM_ALIGN_LOG2)

typedef struct grub_mm_region
{
  struct grub_mm_header *first;
  struct grub_mm_region *next;
  grub_addr_t addr;
  grub_size_t size;
  grub_size_t policies[GRUB_MM_NPOLICIES];
}
*grub_mm_region_t;



static grub_mm_region_t base;

/* Get a header from the pointer PTR, and set *P and *R to a pointer
   to the header and a pointer to its region, respectively. PTR must
   be allocated.  */
static void
get_header_from_pointer (void *ptr, grub_mm_header_t *p, grub_mm_region_t *r)
{
  if ((grub_addr_t) ptr & (GRUB_MM_ALIGN - 1))
    grub_fatal ("unaligned pointer %p", ptr);

  for (*r = base; *r; *r = (*r)->next)
    if ((grub_addr_t) ptr > (*r)->addr
	&& (grub_addr_t) ptr <= (*r)->addr + (*r)->size)
      break;

  if (! *r)
    grub_fatal ("out of range pointer %p", ptr);

  *p = (grub_mm_header_t) ptr - 1;
  if ((*p)->magic != GRUB_MM_ALLOC_MAGIC)
    grub_fatal ("alloc magic is broken at %p", *p);
}

/* Initialize a region starting from ADDR and whose size is SIZE,
   to use it as free space.  */
void
grub_mm_init_region (void *addr, grub_size_t size, grub_size_t *policies)
{
  grub_mm_header_t h;
  grub_mm_region_t r, *p, q;

#ifdef MM_DEBUG
  grub_printf ("Using memory for heap: start=%p, end=%p\n", addr, addr + (unsigned int) size);
#endif

  /* If this region is too small, ignore it.  */
  if (size < GRUB_MM_ALIGN * 4)
    return;

  /* Allocate a region from the head.  */
  r = (grub_mm_region_t) ALIGN_UP((grub_addr_t) addr, GRUB_MM_ALIGN);
  size -= (char *) r - (char *) addr + sizeof (*r);

  h = (grub_mm_header_t) (r + 1);
  h->next = h;
  h->prev = h;
  h->magic = GRUB_MM_FREE_MAGIC;
  h->size = (size >> GRUB_MM_ALIGN_LOG2);

  r->first = h;
  r->addr = (grub_addr_t) h;
  r->size = (h->size << GRUB_MM_ALIGN_LOG2);
  grub_memcpy (&(r->policies), policies, sizeof (r->policies));

  /* Find where to insert this region. Put a smaller one before bigger ones,
     to prevent fragmentation.  */
  for (p = &base, q = *p; q; p = &(q->next), q = *p)
    if (q->size > r->size)
      break;

  *p = r;
  r->next = q;
}

static void
split_chunk (grub_mm_header_t p, grub_size_t size)
{
  grub_mm_header_t q;
  if (p->size <= size)
    return;
  q = p + size;
  q->magic = GRUB_MM_FREE_MAGIC;
  q->size = p->size - size;
  q->next = p->next;
  q->prev = p;
  p->next = q;
  q->next->prev = q;
  p->size = size;
}
/* Allocate the number of units N with the alignment ALIGN from the ring
   buffer starting from *FIRST.  ALIGN must be a power of two. Both N and
   ALIGN are in units of GRUB_MM_ALIGN.  Return a non-NULL if successful,
   otherwise return NULL.  */
static void *
grub_real_malloc (grub_size_t align, grub_size_t size,
		 grub_mm_header_t *first, int allocator)
{
  grub_mm_header_t p, last;
  grub_size_t n = ((size + GRUB_MM_ALIGN - 1) >> GRUB_MM_ALIGN_LOG2) + 1;

  align = (align >> GRUB_MM_ALIGN_LOG2);
  if (align == 0)
    align = 1;

#ifdef MM_DEBUG
  grub_printf ("Allocator %d, header %p, requested %d\n", allocator, *first,
	       size);
#endif

  /* When everything is allocated side effect is that *first will have alloc
     magic marked, meaning that there is no room in this region.  */
  if ((*first)->magic == GRUB_MM_ALLOC_MAGIC)
    return 0;

  switch (allocator)
    {
    default:
    case GRUB_MM_ALLOCATOR_FIRST:
      p = *first;
      last = (*first)->prev;
      break;
    case GRUB_MM_ALLOCATOR_SECOND:
      p = (*first)->next;
      last = *first;
      break;
    case GRUB_MM_ALLOCATOR_LAST:
      p = (*first)->prev;
      last = *first;
      break;
    }

  /* Try to search free slot for allocation in this memory region.  */
  for ( ; ; p = (allocator == GRUB_MM_ALLOCATOR_LAST) ? p->prev : p->next)
    {
      grub_size_t want;

      want = n + (((grub_addr_t) (p + 1) >> GRUB_MM_ALIGN_LOG2) & (align - 1));

      if (! p)
	grub_fatal ("null in the ring");

      if (p->magic != GRUB_MM_FREE_MAGIC)
	grub_fatal ("free magic is broken at %p: 0x%x", p, p->magic);
#ifdef MM_DEBUG
      grub_printf ("region of %d blocks\n", p->size);
#endif

      if (p->size >= want)
	{
	  if (allocator == GRUB_MM_ALLOCATOR_LAST)
	    want += ((p->size - want) / align) * align;

	  split_chunk (p, want);
	      
	  if (want == n)
	    {
	      /* There is no special alignment requirement and memory block
	         is complete match.

	         1. Just mark memory block as allocated and remove it from
	            free list.

	         Result:
	         +---------------+ previous block's next
	         | alloc, size=n |          |
	         +---------------+          v
	       */
	      if (p == *first)
		*first = p->next;
	      p->prev->next = p->next;
	      p->next->prev = p->prev;
	      p->magic = GRUB_MM_ALLOC_MAGIC;
	    }
	  else
	    {
	      /* There might be alignment requirement, when taking it into
	         account memory block fits in.

	         1. Allocate new area at end of memory block.
	         2. Reduce size of available blocks from original node.
	         3. Mark new area as allocated and "remove" it from free
	            list.

	         Result:
	         +---------------+
	         | free, size-=n | next --+
	         +---------------+        |
	         | alloc, size=n |        |
	         +---------------+        v
	       */
	      p->size -= n;
	      p += p->size;
	      p->size = n;
	      p->magic = GRUB_MM_ALLOC_MAGIC;
	    }

#ifdef MM_DEBUG
	  grub_printf ("allocated %p\n", p+1);
#endif

	  return p + 1;
	}

      /* Search was completed without result.  */
      if (p == last)
	break;
    }

  return 0;
}

void *
grub_memalign_policy (grub_size_t align, grub_size_t size, int policy)
{
  grub_mm_region_t r;
  int count = 0;

 again:

#ifdef MM_DEBUG
  grub_printf ("base %p, policy %d\n", base, policy);
#endif

  for (r = base; r; r = r->next)
    {
      void *p;

#ifdef MM_DEBUG
      grub_printf ("rpol %d, %p\n", r->policies[policy], r->first);
#endif

      if (r->policies[policy] == GRUB_MM_ALLOCATOR_SKIP)
	continue;

      p = grub_real_malloc (align, size, &(r->first), r->policies[policy]);
      if (p)
	return p;
    }

  /* If failed, increase free memory somehow.  */
  switch (count)
    {
    case 0:
      /* Invalidate disk caches.  */
      grub_disk_cache_invalidate_all ();
      count++;
      goto again;

    case 1:
      /* Unload unneeded modules.  */
      grub_dl_unload_unneeded ();
      count++;
      goto again;

    default:
      break;
    }

  grub_error (GRUB_ERR_OUT_OF_MEMORY, "out of memory");
  return 0;
}

/* Allocate SIZE bytes and return the pointer.  */
void *
grub_malloc (grub_size_t size)
{
  return grub_memalign (0, size);
}

/* Allocate SIZE bytes with the alignment ALIGN and return the pointer.  */
void *
grub_memalign (grub_size_t align, grub_size_t size)
{
  return grub_memalign_policy (align, size, GRUB_MM_MALLOC_DEFAULT);
}

/* Allocate SIZE bytes, clear them and return the pointer.  */
void *
grub_zalloc (grub_size_t size)
{
  void *ret;

  ret = grub_memalign (0, size);
  if (ret)
    grub_memset (ret, 0, size);

  return ret;
}

/* Deallocate the pointer PTR.  */
void
grub_free (void *ptr)
{
  grub_mm_header_t p;
  grub_mm_region_t r;

  if (! ptr)
    return;

  get_header_from_pointer (ptr, &p, &r);

  if (r->first->magic == GRUB_MM_ALLOC_MAGIC)
    {
      p->magic = GRUB_MM_FREE_MAGIC;
      r->first = p->next = p->prev = p;
    }
  else
    {
      grub_mm_header_t q;

#ifdef MM_DEBUG
      q = r->first;
      do
	{
	  grub_printf ("%s:%d: q=%p, q->size=0x%x, q->magic=0x%x\n",
		       __FILE__, __LINE__, q, q->size, q->magic);
	  q = q->next;
	}
      while (q != r->first);
#endif

      for (q = r->first;  p >= q && q != r->first->prev; q = q->next)
	{
	  if (q->magic != GRUB_MM_FREE_MAGIC)
	    grub_fatal ("free magic is broken at %p: 0x%x", q, q->magic);
	}
      if (p < q)
	q = q->prev;

      if (r->first == q->next && p < q->next)
	r->first = p;

      p->magic = GRUB_MM_FREE_MAGIC;
      p->next = q->next;
      p->next->prev = p;
      q->next = p;
      q->next->prev = q;

      if (p + p->size == p->next)
	{
	  p->next->magic = 0;
	  p->size += p->next->size;
	  p->next = p->next->next;
	  p->next->prev = p;
	}

      if (q + q->size == p)
	{
	  p->magic = 0;
	  q->size += p->size;
	  q->next = p->next;
	  q->next->prev = q;
	}
    }
}

/* Reallocate SIZE bytes and return the pointer. The contents will be
   the same as that of PTR.  */
void *
grub_rememalign_policy (void *ptr, grub_size_t align,
			grub_size_t size, int policy)
{
  grub_mm_region_t r;
  void *q;
  grub_size_t n;
  grub_mm_header_t p, p2;

  if (! ptr)
    return grub_memalign_policy (align, size, policy);

  if (! size)
    {
      grub_free (ptr);
      return 0;
    }

  n = ((size + GRUB_MM_ALIGN - 1) >> GRUB_MM_ALIGN_LOG2) + 1;
  get_header_from_pointer (ptr, &p, &r);

  /* Should we shrink the region?  */
  if (p->size >= n)
    return ptr;

  /* Try extend in place.  */
  p2 = p + p->size;
  if ((grub_addr_t) p2 < r->addr + (r->size << GRUB_MM_ALIGN_LOG2)
      && p2->magic == GRUB_MM_FREE_MAGIC && p->size + p2->size >= n)
    {
      split_chunk (p2, n - p->size);

      p2->next->prev = p2->prev;
      p2->prev->next = p2->next;

      if (r->first == p2)
	r->first = p2->next;

      /* Perhaps we're the last free block in this region.  */
      if (r->first == p2)
	r->first = p;
      p->size = n;
      return ptr;
    }

  q = grub_memalign_policy (align, size, policy);
  if (! q)
    return q;

  grub_memcpy (q, ptr, size);
  grub_free (ptr);
  return q;
}

void *
grub_realloc (void *ptr, grub_size_t size)
{
  return grub_rememalign_policy (ptr, 1, size, GRUB_MM_MALLOC_DEFAULT);
}

#ifdef MM_DEBUG
int grub_mm_debug = 0;

void
grub_mm_dump_free (void)
{
  grub_mm_region_t r;

  for (r = base; r; r = r->next)
    {
      grub_mm_header_t p;

      /* Follow the free list.  */
      p = r->first;
      do
	{
	  if (p->magic != GRUB_MM_FREE_MAGIC)
	    grub_fatal ("free magic is broken at %p: 0x%x", p, p->magic);

	  grub_printf ("F:%p:%u:%p\n",
		       p, (unsigned int) p->size << GRUB_MM_ALIGN_LOG2, p->next);
	  p = p->next;
	}
      while (p != r->first);
    }

  grub_printf ("\n");
}

void
grub_mm_dump (unsigned lineno)
{
  grub_mm_region_t r;

  grub_printf ("called at line %u\n", lineno);
  for (r = base; r; r = r->next)
    {
      grub_mm_header_t p;

      for (p = (grub_mm_header_t) ((r->addr + GRUB_MM_ALIGN - 1)
				   & (~(GRUB_MM_ALIGN - 1)));
	   (grub_addr_t) p < r->addr + r->size;
	   p++)
	{
	  switch (p->magic)
	    {
	    case GRUB_MM_FREE_MAGIC:
	      grub_printf ("F:%p:%u:%p\n",
			   p, (unsigned int) p->size << GRUB_MM_ALIGN_LOG2, p->next);
	      break;
	    case GRUB_MM_ALLOC_MAGIC:
	      grub_printf ("A:%p:%u\n", p, (unsigned int) p->size << GRUB_MM_ALIGN_LOG2);
	      break;
	    }
	}
    }

  grub_printf ("\n");
}

void *
grub_debug_malloc (const char *file, int line, grub_size_t size)
{
  void *ptr;

  if (grub_mm_debug)
    grub_printf ("%s:%d: malloc (0x%zx) = ", file, line, size);
  ptr = grub_malloc (size);
  if (grub_mm_debug)
    grub_printf ("%p\n", ptr);
  return ptr;
}

void *
grub_debug_zalloc (const char *file, int line, grub_size_t size)
{
  void *ptr;

  if (grub_mm_debug)
    grub_printf ("%s:%d: zalloc (0x%zx) = ", file, line, size);
  ptr = grub_zalloc (size);
  if (grub_mm_debug)
    grub_printf ("%p\n", ptr);
  return ptr;
}

void
grub_debug_free (const char *file, int line, void *ptr)
{
  if (grub_mm_debug)
    grub_printf ("%s:%d: free (%p)\n", file, line, ptr);
  grub_free (ptr);
}

void *
grub_debug_realloc (const char *file, int line, void *ptr, grub_size_t size)
{
  if (grub_mm_debug)
    grub_printf ("%s:%d: realloc (%p, 0x%zx) = ", file, line, ptr, size);
  ptr = grub_realloc (ptr, size);
  if (grub_mm_debug)
    grub_printf ("%p\n", ptr);
  return ptr;
}

void *
grub_debug_memalign (const char *file, int line, grub_size_t align,
		    grub_size_t size)
{
  void *ptr;

  if (grub_mm_debug)
    grub_printf ("%s:%d: memalign (0x%zx, 0x%zx) = ",
		 file, line, align, size);
  ptr = grub_memalign (align, size);
  if (grub_mm_debug)
    grub_printf ("%p\n", ptr);
  return ptr;
}

#endif /* MM_DEBUG */
