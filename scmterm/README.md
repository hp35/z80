# SCMTERM - Small Computer Monitor TERMinal for RC2014 and related platforms
<em>Fredrik Jonsson, August 7, 2026</em></br>
Location: https://github.com/hp35/z80/tree/main/scmterm

Bash script `SCMTERM` for interfacing the Small Computer Monitor (SCM) [^1]
running on the RC2014 Z80 single card computer [^2] from a standard terminal
in any Linux-based system like Debian, Fedora, Ubuntu or Raspbian (Raspberry
Pi).

The idea behind the `SCMTERM` script is to provide an extremely light-weight
alternative to the standard `GTKTerm` [^3] option of communication, which
requires a separate window for the operation. Using the `SCMTERM` script,
everything can be run directly from a single command line, operating via
any port connected to the `UART` interface [^4], like `/dev/ttyUSB0`,
`/dev/ttyACM0` or `/dev/ttyACM1`. In some sense, one may consider the present
`SCMTERM` script as being a sort-of "mini-miniterm".

[^1]: Small Computer Monitor by Stephen C. Cousins, www.scc.me.uk.
      For documentation and source, see https://smallcomputercentral.com/small-computer-monitor/small-computer-monitor-v1-0/
[^2]: RC2014 Mini II, https://z80kits.com/shop/rc2014-mini-ii/
[^3]: Willem van den Akker, GTKTerm: A GTK+ Serial Port Terminal,
      https://github.com/wvdakker/gtkterm.
[^4]: Waveshare USB to UART/I2C/SPI/JTAG interface,
      https://www.waveshare.com/wiki/USB_TO_UART/I2C/SPI/JTAG
[^5]: Wikipedia, <em>Intel HEX</em>, https://en.wikipedia.org/wiki/Intel_HEX

## What is SCM in the first place?
In the context of the Z80, SCM stands for <em>Small Computer Monitor.</em>
SCM is a compact monitor program (firmware) stored in ROM that provides a
command-line interface for interacting directly with the Z80 system.
We may think of SCM as a very small operating environment that helps us
develop, test, and debug machine code without requiring a full operating
system like, say, CP/M.

Typical features of SCM include:
 * Memory examination and editing – View and modify RAM contents.
 * Register inspection and editing – Read or change the Z80 CPU registers.
 * Program execution – Start execution from any memory address.
 * Breakpoints and single-stepping – Useful for debugging.
 * Assembler and disassembler – Many versions include built-in tools
   for assembling and disassembling Z80 instructions.
 * Loading of Intel HEX [^5] files – Upload programs over a serial connection.
 * ROM extensions – Some implementations support additional commands stored
   in expansion ROMs.

SCM is widely used on homebrew and hobbyist Z80 computers, including systems
based on the RC2014 bus and similar projects. It provides a convenient
development environment for writing and testing Z80 assembly programs before
(or instead of) running a full operating system.

For example, an SCM session might look like this:
```
> D 9000      ; Display memory starting at address 9000h
> M 9100      ; Modify memory at address 9100h
> R           ; Show registers
> G 9000      ; Go (execute) at address 9000h
```
The point of the `SCMTERM` program is to enable a simple and straightforward
connection to the SCM firmware straight from a standard terminal in Linux,
without having to use separate programs like `GTKTerm` or similar.

## Workflow
The idea is to use `SCMTERM` in a natural workflow from a Linux station over
to SCM running on the RC2014 Z80 platform (or any similar platform running SCM)
as
```
Linux workstation
        |
        |  SCMTERM
        |
USB-UART (/dev/ttyUSB0)
        |
        |
RC2014 UART
        |
        |
SCM R4 monitor
        |
        +--> assemble / inspect memory / run programs
```
The overall design decisions for `SCMTERM` are as follows:
  * Keeping SCMTERM in Bash rather than immediately rewriting it in, say, C
    or Python.
  * Eliminating the need for running (the otherwise excellent) `GTKTerm`
    in a separate window; everything should be possible to do via a plain
    terminal under Linux.
  * Keeping the RC2014 side untouched, that is to say with no changes to SCM
    whatsoever.
  * Logging is optional.
  * Using command mode as a local terminal escape layer.
  * Avoiding unnecessary dependencies. ("Keep it simple, stupid!")

## Usage
```
Usage:
     scmterm [options]

Options:
         -d device       Serial device
                         Default: /dev/ttyUSB0
         -b baud         Baud rate
                         Default: 115200
         -p parity       Parity
                         N = none (default)
                         E = even
                         O = odd
         -s stopbits     Stop bits
                         1 (default)
                         2
         -f              Enable RTS/CTS hardware flow control
         -l <logdir>     Record the entire SCMTERM session to log file
                         located in the <logdir> directory.
                         If no -l command-line option is present, then
                         SCMTERM will check if there is a ./log/ directory
                         in the current working directory where SCMTERM
                         was invoked; if found to exist logging will be
                         done to this directory regardless of a missing
                         -l option.
         -h              Display this help message

Default serial configuration:
         115200 baud
         8 data bits
         No parity
         1 stop bit
         No flow control

SCMTERM operation:
         Normal mode:
             Keys are sent directly to the RC2014 SCM monitor.
         Enter:
             Sends CR (0x0D) to SCM.
         Ctrl-T:
             Enter SCMTERM command mode.
         Ctrl-C:
             Exit SCMTERM.

Command mode:
         send <file.hex>
             Send Intel HEX file to SCM.
         info
             Display the SCMTERM communication settings."
         quit
             Return to SCM terminal mode.
```

## Default SCMTERM communication parameters
The default initialization of the `SCMTERM` communication parameters for the
port is as follows.
```
  DEVICE="/dev/ttyUSB0"
  BAUD=115200
  PARITY="N"
  STOPBITS=1
  FLOWCONTROL=0
  HEX_DELAY=0.02
```
Common ports for UART interfaces are `/dev/ttyUSB0`, `/dev/ttyACM0` and
`/dev/ttyACM1`.

## Example of usage
Below follows a typical session in which we use `SCMTERM` to transfer an Intel
HEX file `life.hex` over to a connected RC2014 single-board computer running
SCM. Notice that if either (i) a subdirectory `./log/` is present in the
current directory from which `SCMTERM` is launched, or if (ii) the command
line option `-l <logdir>` is present at startup, then `SCMTERM` will produce
verbatim logs of the session, named using the system date and time in the
format `scmterm-YYYYMMDD_hhmm.log`.

1. Connect the RC2014 card via your UART of choice and check that the
serial device (typically `ttyUSB0`, `ttyACM0` or `ttyACM0`) is up and running:
```
me@mycomputer:life$ ls -al /dev/ttyUSB0 
crw-rw---- 1 root dialout 188, 0 Aug  7 15:57 /dev/ttyUSB0
```
2. Launch `SCMTERM` using this device:
```
me@mycomputer:life$ scmterm -d /dev/ttyUSB0 
This is SCMTERM v.1.0. Copyright (C) 2026 Fredrik Jonsson under GPL 3.0
Logging session to ./log/scmterm-20260807_1607.log
    Use 'Ctrl-T' to enter SCMTERM command mode.
    Use 'Ctrl-X' or ']' to exit SCMTERM.
*
```
3. Check out what SCM supports when it comes to commands, by typing `?` followed
by `ENTER`:
```
*?
Small Computer Monitor by Stephen C Cousins (www.scc.me.uk)
Version 1.0.0 configuration R4 for Z80 based RC2014 systems

Monitor commands:
A [<address>]  = Assemble        |  D [<address>]   = Disassemble
M [<address>]  = Memory display  |  E [<address>]   = Edit memory
R [<name>]     = Registers/edit  |  F [<name>]      = Flags/edit
B [<address>]  = Breakpoint      |  S [<address>]   = Single step
I <port>       = Input from port |  O <port> <data> = Output to port
G [<address>]  = Go to program
BAUD <device> <rate>             |  CONSOLE <device>
FILL <start> <end> <byte>        |  API <function> [<A>] [<DE>]
DEVICES, DIR, HELP, RESET
*
```
4. In order to make use of `SCMTERM` for transferring an Intel HEX file over
to the RC2014 card, enter command mode by typing `Ctrl-T`:
```
*----------------------------------------
Entering SCMTERM terminal command mode
----------------------------------------
Valid commands within command mode:
    send <file.hex>  Send Intel HEX file.
    info             Display the SCMTERM communication settings.
    quit             Exit command mode and return to SCM.

cmd> 
```
5. Check out the settings of `SCMTERM`:
```
cmd> info
----------------------------------------------------
SCMTERM communication settings
----------------------------------------------------
Device       : /dev/ttyUSB0
Baud rate    : 115200
Data bits    : 8
Parity       : N
Stop bits    : 1
Flow control : disabled
----------------------------------------------------
Available SCMTERM commands in command mode (Ctrl-T):
  send <file.hex>   Send Intel HEX file.
  info              Display SCMTERM configuration.
  quit              Exit command mode and return to SCM.
cmd> 
```
6. Transfer the file `life.hex` over to the RAM of the RC2014 (the primary
memory of the Z80), by:
```
cmd> send life.hex
----------------------------------------------------
Intel HEX file analysis
----------------------------------------------------
File               : life.hex
Total records      : 14
Data records       : 13
EOF records        : 1
Data bytes         : 197
Lowest address     : 9000H
Highest address    : 90C4H

Uploading Intel HEX file life.hex to device ...

Ready
----------------------------------------------------
Transfer of life.hex completed successfully.
----------------------------------------------------
cmd> 
```
7. Exit the `SCMTERM` command mode, to enter the communication mode with SCM
again:
```
cmd> quit
----------------------------------------
Leaving command mode of the SCMTERM terminal
----------------------------------------
*
```
8. Execute the program, stored at address `0x9000` in the memory:
```
*G9000
     ... ... ... ... ... ... ... ...
     ...  [output from the Z80]  ...
     ... ... ... ... ... ... ... ...
```
9. Quit the `SCMTERM` terminal and return to the Linux terminal by `Ctrl-X`
or `Ctrl-C`:
```
*
Leaving SCMTERM.

me@mycomputer:life$ 
```

## Installation
Installation in a Linux/OSX/Unix machine is simple. In order to install the
script and a symbolic link in the default location `/usr/local/bin/`, simply
exectute the following in a terminal:
```bash
cd scmterm; sudo make install
```
If you wish the script to be installed elsewhere, simply edit the `TARGET`
field in the enclosed `Makefile`.

## Copyright
Copyright (C) 2026, Fredrik Jonsson, under GPL 3.0.
