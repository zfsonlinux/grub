/*
 *  GRUB  --  GRand Unified Bootloader
 *  Copyright (C) 2000,2001,2002,2003,2004,2005,2007,2008,2009,2010  Free Software Foundation, Inc.
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
#include <grub/serial.h>
#include <grub/ns8250.h>
#include <grub/types.h>
#include <grub/dl.h>
#include <grub/misc.h>
#include <grub/cpu/io.h>
#include <grub/mm.h>

#ifdef GRUB_MACHINE_PCBIOS
static const unsigned short *serial_hw_io_addr = (const unsigned short *) GRUB_MEMORY_MACHINE_BIOS_DATA_AREA_ADDR;
#define GRUB_SERIAL_PORT_NUM 4
#else
#include <grub/machine/serial.h>
static const grub_port_t serial_hw_io_addr[] = GRUB_MACHINE_SERIAL_PORTS;
#define GRUB_SERIAL_PORT_NUM (ARRAY_SIZE(serial_hw_io_addr))
#endif

/* Convert speed to divisor.  */
static unsigned short
serial_get_divisor (unsigned int speed)
{
  unsigned int i;

  /* The structure for speed vs. divisor.  */
  struct divisor
  {
    unsigned int speed;
    unsigned short div;
  };

  /* The table which lists common configurations.  */
  /* 1843200 / (speed * 16)  */
  static struct divisor divisor_tab[] =
    {
      { 2400,   0x0030 },
      { 4800,   0x0018 },
      { 9600,   0x000C },
      { 19200,  0x0006 },
      { 38400,  0x0003 },
      { 57600,  0x0002 },
      { 115200, 0x0001 }
    };

  /* Set the baud rate.  */
  for (i = 0; i < ARRAY_SIZE (divisor_tab); i++)
    if (divisor_tab[i].speed == speed)
  /* UART in Yeeloong runs twice the usual rate.  */
#ifdef GRUB_MACHINE_MIPS_YEELOONG
      return 2 * divisor_tab[i].div;
#else
      return divisor_tab[i].div;
#endif
  return 0;
}

static void
do_real_config (struct grub_serial_port *port)
{
  int divisor;
  unsigned char status = 0;
  const unsigned char parities[] = {
    [GRUB_SERIAL_PARITY_NONE] = UART_NO_PARITY,
    [GRUB_SERIAL_PARITY_ODD] = UART_ODD_PARITY,
    [GRUB_SERIAL_PARITY_EVEN] = UART_EVEN_PARITY
  };
  const unsigned char stop_bits[] = {
    [GRUB_SERIAL_STOP_BITS_1] = UART_1_STOP_BIT,
    [GRUB_SERIAL_STOP_BITS_2] = UART_2_STOP_BITS,
  };

  if (port->configured)
    return;

  divisor = serial_get_divisor (port->config.speed);

  /* Turn off the interrupt.  */
  grub_outb (0, port->port + UART_IER);

  /* Set DLAB.  */
  grub_outb (UART_DLAB, port->port + UART_LCR);

  /* Set the baud rate.  */
  grub_outb (divisor & 0xFF, port->port + UART_DLL);
  grub_outb (divisor >> 8, port->port + UART_DLH);

  /* Set the line status.  */
  status |= (parities[port->config.parity]
	     | port->config.word_len | stop_bits[port->config.stop_bits]);
  grub_outb (status, port->port + UART_LCR);

  /* In Yeeloong serial port has only 3 wires.  */
#ifndef GRUB_MACHINE_MIPS_YEELOONG
  /* Enable the FIFO.  */
  grub_outb (UART_ENABLE_FIFO_TRIGGER1, port->port + UART_FCR);

  /* Turn on DTR and RTS.  */
  grub_outb (UART_ENABLE_DTRRTS, port->port + UART_MCR);
#else
  /* Enable the FIFO.  */
  grub_outb (UART_ENABLE_FIFO_TRIGGER14, port->port + UART_FCR);

  /* Turn on DTR, RTS, and OUT2.  */
  grub_outb (UART_ENABLE_DTRRTS | UART_ENABLE_OUT2, port->port + UART_MCR);
#endif

  /* Drain the input buffer.  */
  while (grub_inb (port->port + UART_LSR) & UART_DATA_READY)
    grub_inb (port->port + UART_RX);

  port->configured = 1;
}

/* Fetch a key.  */
static int
serial_hw_fetch (struct grub_serial_port *port)
{
  do_real_config (port);
  if (grub_inb (port->port + UART_LSR) & UART_DATA_READY)
    return grub_inb (port->port + UART_RX);

  return -1;
}

/* Put a character.  */
static void
serial_hw_put (struct grub_serial_port *port, const int c)
{
  unsigned int timeout = 100000;

  do_real_config (port);

  /* Wait until the transmitter holding register is empty.  */
  while ((grub_inb (port->port + UART_LSR) & UART_EMPTY_TRANSMITTER) == 0)
    {
      if (--timeout == 0)
        /* There is something wrong. But what can I do?  */
        return;
    }

  grub_outb (c, port->port + UART_TX);
}

/* Initialize a serial device. PORT is the port number for a serial device.
   SPEED is a DTE-DTE speed which must be one of these: 2400, 4800, 9600,
   19200, 38400, 57600 and 115200. WORD_LEN is the word length to be used
   for the device. Likewise, PARITY is the type of the parity and
   STOP_BIT_LEN is the length of the stop bit. The possible values for
   WORD_LEN, PARITY and STOP_BIT_LEN are defined in the header file as
   macros.  */
static grub_err_t
serial_hw_configure (struct grub_serial_port *port,
		     struct grub_serial_config *config)
{
  unsigned short divisor;

  divisor = serial_get_divisor (config->speed);
  if (divisor == 0)
    return grub_error (GRUB_ERR_BAD_ARGUMENT, "bad speed");

  if (config->parity != GRUB_SERIAL_PARITY_NONE
      && config->parity != GRUB_SERIAL_PARITY_ODD
      && config->parity != GRUB_SERIAL_PARITY_EVEN)
    return grub_error (GRUB_ERR_BAD_ARGUMENT, "unsupported parity");

  if (config->stop_bits != GRUB_SERIAL_STOP_BITS_1
      && config->stop_bits != GRUB_SERIAL_STOP_BITS_2)
    return grub_error (GRUB_ERR_BAD_ARGUMENT, "unsupported stop bits");

  port->config = *config;
  port->configured = 0;

  /*  FIXME: should check if the serial terminal was found.  */

  return GRUB_ERR_NONE;
}

static struct grub_serial_driver grub_ns8250_driver =
  {
    .configure = serial_hw_configure,
    .fetch = serial_hw_fetch,
    .put = serial_hw_put
  };

static char com_names[GRUB_SERIAL_PORT_NUM][20];
static struct grub_serial_port com_ports[GRUB_SERIAL_PORT_NUM];

void
grub_ns8250_init (void)
{
  int i;
  for (i = 0; i < GRUB_SERIAL_PORT_NUM; i++)
    if (serial_hw_io_addr[i])
      {
	grub_err_t err;
	grub_snprintf (com_names[i], sizeof (com_names[i]), "com%d", i);
	com_ports[i].name = com_names[i];
	com_ports[i].driver = &grub_ns8250_driver;
	com_ports[i].port = serial_hw_io_addr[i];
	err = grub_serial_config_defaults (&com_ports[i]);
	if (err)
	  grub_print_error ();

	grub_serial_register (&com_ports[i]);
      }
}

char *
grub_serial_ns8250_add_port (grub_port_t port)
{
  struct grub_serial_port *p;
  int i;
  for (i = 0; i < GRUB_SERIAL_PORT_NUM; i++)
    if (com_ports[i].port == port)
      return com_names[i];
  p = grub_malloc (sizeof (*p));
  if (!p)
    return NULL;
  p->name = grub_xasprintf ("port%lx", (unsigned long) port);
  if (!p->name)
    {
      grub_free (p);
      return NULL;
    }
  p->driver = &grub_ns8250_driver;
  grub_serial_config_defaults (p);
  p->port = port;
  grub_serial_register (p);  

  return p->name;
}
