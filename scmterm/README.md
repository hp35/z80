# SCMTERM - Small Computer Monitor TERMinal for RC2014 and related platforms
<em>Fredrik Jonsson, July 26, 2026</em></br>
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

## Installation
Installation in a Linux/OSX/Unix machine is simple. In order to install the
script and a symbolic link in the default location `/usr/local/bin/`, simply
exectute the following in a terminal:
```bash
cd bash; sudo make install
```
If you wish the script to be installed elsewhere, simply edit the `TARGET`
field in the enclosed `bash/Makefile`.

## References
[^1] Small Computer Monitor by Stephen C. Cousins, www.scc.me.uk.
     For documentation and source, see https://smallcomputercentral.com/
     /small-computer-monitor/small-computer-monitor-v1-0/
[^2] RC2014 Mini II, https://z80kits.com/shop/rc2014-mini-ii/
[^3] Willem van den Akker, GTKTerm: A GTK+ Serial Port Terminal,
     https://github.com/wvdakker/gtkterm.
[^4] Waveshare USB to UART/I2C/SPI/JTAG interface,
     https://www.waveshare.com/wiki/USB_TO_UART/I2C/SPI/JTAG

## Copyright
Copyright (C) 2026, Fredrik Jonsson, under GPL 3.0.
