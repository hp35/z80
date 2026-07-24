# Configuration of GTKTerm and Waveshare USB to UART/I2C/SPI/JTAG
<em>Fredrik Jonsson, July 24, 2026</em></br>
Location: https://github.com/hp35/z80/tree/main/uart

In this tutorial, we will use GTKTerm [^1] together with the Waveshare USB to
UART/I2C/SPI/JTAG interface [^2] to show how a simple UART communication channel
is setup on a standard Linux or Raspberry Pi system. In particular, we show how
we with the Waveshare interface, which internally contains two independently
operated UART interfaces, can check the communication by simply having the two
interfaces communicating with each other.

[^1]: Willem van den Akker, <em>GTKTerm: A GTK+ Serial Port Terminal</em>,
      [https://github.com/wvdakker/gtkterm]
[^2]: <em>Waveshare USB to UART/I2C/SPI/JTAG interface</em>,
      [https://www.waveshare.com/wiki/USB_TO_UART/I2C/SPI/JTAG]

![Waveshare USB to UART/I2C/SPI/JTAG interface connected with USB, in a loop
configuration for testing purposes, in which UART0 is communicating with
UART1.](waveshare-a.jpg)</br>
<b>Figure 1.</b><i>Waveshare USB to UART/I2C/SPI/JTAG</i> interface connected
with USB, in a loop configuration for testing purposes, in which UART0 is
communicating with UART1.

## 1. Default settings
The following assumes that you are using a Linux-based system together with the
Waveshare USB to UART/I2C/SPI/JTAG interface, with `GTKTerm`  [^1] as the tool
of serial communication. Other excellent terminal emulators are for example
`tio` or `minicom` via the command line, and the procedure for establishing
the communication will be very similar.

For the UART side in GTKTerm, the correct settings depend mostly on the device
you connect to, not the Waveshare interface itself. The adapter is usually
transparent to these settings.

That said, the most common/default settings for the classic "115200 8N1" setup
are:
```
  Baud rate: 115200
  Data bits: 8
  Parity: None
  Stop bits: 1
  Flow control: None
```

## 2. Basic setup

### 2.1. Connecting the Waveshare UART interface
Connect the Waveshare USB to UART/I2C/SPI/JTAG module to your computer with a
USB cable (USB-A to USB-B), with the switches of the interface set to 5V and
`S1` and `S2` both set to `OFF` (in order to use the UART ports). Check that
the red power light (`PWR`) is lit.

![Waveshare USB to UART/I2C/SPI/JTAG interface with the switches of the
interface set to 5V and S1 and S2 both to OFF.](waveshare-b.jpg)</br>
<b>Figure 2.</b><i>Waveshare USB to UART/I2C/SPI/JTAG</i> interface with the
switches of the interface set to 5V and S1 and S2 both to OFF. The switches
should be set before powering up the interface by connecting the USB cable
to the USB-B port.

### 2.2. Check for the `/dev/ttyACM0` and `/dev/ttyACM0` devices
Make sure that the two UARTs of the Waveshare interface shows up at your
computer as the two devices /dev/ttyACM0 and /dev/ttyACM1:
```bash
ls /dev/ttyACM*

   crw-rw---- 1 root dialout 166, 0 Jul  2 10:39 /dev/ttyACM0
   crw-rw---- 1 root dialout 166, 1 Jul  2 10:23 /dev/ttyACM1
```

### 2.3. User permissions for the device drivers
For simplicity, we CAN make the device accessible to all users, not only root.
I personally find it inconvenient and not kosher to every now and then use
`sudo` for the most basic things. Check that the permissions have been changed.
```bash
sudo chmod a+rw /dev/ttyACM*
ls -l /dev/tty*

   crw-rw-rw- 1 root dialout 166, 0 Jul  2 10:39 /dev/ttyACM0
   crw-rw-rw- 1 root dialout 166, 1 Jul  2 10:23 /dev/ttyACM1
```

### 2.4. Permament fix of permission problems
However, devices in /dev/tty (and related ports like `/dev/ttyUSB0` or
`/dev/ttyACM0`) do not keep permissions set by chmod because they are
virtual files which are created dynamically by the kernel and `udev`
every time the system boots, a user logs in, or a device is reconnected.
<em>Therefore, a more permanent fix of the issue of permissions is to instead
permanently add your user name to the system group that owns the device
rather than changing the device's permissions every now and then.</em>

Do this by the following by noting the name of the group obtained by
`ls /dev/ttyACM*`, in this case `dialout`. Add your current user (or a
specific username) to the group that controls the device using the `usermod`
command:
```bash
sudo usermod -a -G dialout $USER
```
Where `$USER` is your user name as returned by the shell. Apply the changes by
fully logging out of your session and log back in (or restart your system) for
the group assignment to take effect.

### 2.5. Launching GTKTerm without hardware flow control
We now launch GTKTerm without any RTS/CTS control, just using the `TXD` and
`RXD` pins. We do this either "as is" or with options explicitly stated at
startup:
```bash
gtkterm --port /dev/ttyACM0 --flow none --speed 115200 --bits 8 --stopbits 1 --parity none
```
Alternatively, we can launch with RTS/CTS control enabled, by changing
the flow switch to `--flow CTS`, instead using
```bash
gtkterm --port /dev/ttyACM0 --flow CTS --speed 115200 --bits 8 --stopbits 1 --parity none
```
Even with nothing connected to the UART, you should see the `TXD0` LED flicker
whenever you type anything in the GTKTerm terminal.

## 3. Checking loopback without flow control

   Just for the sake of it, disconnect the Waveshare interface from USB to
   avoid accidentally shorting against live pins.

![Waveshare USB to UART/I2C/SPI/JTAG interface in which the `TXD` and `RXD`
pins of `UART0` and `UART1` are connected crosswise.](waveshare-c.jpg)</br>
<b>Figure 3.</b><i>Waveshare USB to UART/I2C/SPI/JTAG</i> interface with the
`TXD` and `RXD` pins of `UART0` and `UART1` connected crosswise. In this
configuration, also the `GND` pins are connected (which is not really necessary
in the case of the two UARTs in the same module); however, the `RTS` and `CTS`
need not be connected as in the image, as we in this case run the communication
without hardware flow control.

### 3.1. Connecting the cross-patched `TXD` and `RXD` pins of the UARTs
1. Connect the `TXD` pin of `UART0` with the `RXD` pin of `UART1`.
2. Connect the `RXD` pin of `UART0` with the `TXD` pin of `UART1`.
3. Connect the `GND` pin of `UART0` with the `GND` pin of `UART1`.
```
  ----------              ----------
  | UART 0 |              | UART 1 |
  ----------              ----------

     TX  ------------------>  RX
     RX  <------------------  TX

     GND ------------------- GND
```
In principle, this connection of ground is not needed as the two UARTs in the
Waveshare interface share the same ground, but just for the sake of illustrating
how two different UARTs should be communicating, they should have a ground line
interconnecting them, determining the base voltage of the signal levels.

### 3.2. Power up the Waveshare interface
Power up the Waveshare interface by connecting it with the USB cable to the
computer again.

### 3.3. Start the GTKTerm terminals
Start two (2) GTKTerm terminals as two separate processes, each one connecting
to a separate UART, by
```bash
gtkterm --port /dev/ttyACM0 --flow none --speed 115200 --bits 8 --stopbits 1 --parity none &
gtkterm --port /dev/ttyACM1 --flow none --speed 115200 --bits 8 --stopbits 1 --parity none &
```
We here state the parameters to use explicitly; however, this is in most
cases completely unneccessary, and we may most often just use
`gtkterm --port /dev/ttyACM0`.

### 3.4. Loopback testing without flow control
When typing in text in the first terminal, the typed text should be received
and displayed by the second terminal (which is operating independent of the
first one), and vice versa.

When typing in the first terminal (associated with UART0), the green `TXD0`
LED (for the transmission of data from UART0) of the Waveshare interface
should flicker together with the blue `RXD1` LED (for the reception of data
by `UART1`).

Also, when typing in the second terminal (associated with `UART1`), the green
`TXD1` LED (for the transmission of data from `UART1`) of the Waveshare
interface should flicker together with the blue `RXD0` LED (for the reception
of data by `UART0`).

## 4. Checking loopback with CTS/RTS flow control
We will now carry out the same test with loopback of the signals, but now also
apply flow control, using the extra UART handshake lines
```
    RTS = Request To Send
    CTS = Clear To Send
```
What CTS/RTS actually does is to enable hardware flow control, for example
used for preventing buffer overruns and throttling fast transfers.
The CTS/RTS flow control is not required for ordinary UART communication,
and most hobby/microcontroller UART setups only make use of the standard
TX, RX and GND, ignoring the CTS and RTS pins entirely.

### 4.1. Hardware wiring for flow control with the UART
1. Connect the TXD pin of UART0 with the RXD pin of UART1.
2. Connect the RXD pin of UART0 with the TXD pin of UART1.
3. Connect the RTS pin of UART0 with the CTS pin of UART1.
4. Connect the CTS pin of UART0 with the RTS pin of UART1.
5. Connect the GND pin of UART0 with the GND pin of UART1.

Conceptually, just as in the case of the TX/RX pins, we need to cross also the
RTS/CTS pins between the two UARTs, as illustrated below.
```
  ----------              ----------
  | UART 0 |              | UART 1 |
  ----------              ----------

     TX  ------------------>  RX
     RX  <------------------  TX

     RTS ------------------> CTS
     CTS <------------------ RTS

     GND ------------------- GND
```

### 4.2. Power up the Waveshare interface
Power up the Waveshare interface by connecting it with the USB cable to the
computer again.
	
### 4.3. Start the GTKTerm terminals
Start two (2) GTKTerm terminals as two separate processes, each one connecting
to a separate UART and just as in the previous case without flow control, with
the slight change of the --flow option, which we now instead set to CTS, by
```bash
gtkterm --port /dev/ttyACM0 --flow CTS --speed 115200 --bits 8 --stopbits 1 --parity none &
gtkterm --port /dev/ttyACM1 --flow CTS --speed 115200 --bits 8 --stopbits 1 --parity none &
```

### 4.4. Loopback testing with RTS/CTS flow control
When typing in text in the first terminal, the typed text should be received
and displayed by the second terminal (which is operating independent of the
first one), and vice versa.

When typing in the first terminal (associated with `UART0`), the green `TXD0`
LED (for the transmission of data from UART0) of the Waveshare interface should
flicker together with the blue `RXD1` LED (for the reception of data by
`UART1`).

Also, when typing in the second terminal (associated with `UART1`), the green
`TXD1` LED (for the transmission of data from `UART1`) of the Waveshare
interface should flicker together with the blue `RXD0` LED (for the reception
of data by `UART0`).

## 5. How much power can the Waveshare UART deliver via the VCC (+5V) pin?

One should not regard the `VCC` pin of the UART as a general-purpose power
supply, as it is intended to power small target circuits or provide a logic
reference, not to supply substantial loads. Note: `VCC` is either +3.3V or
+5V, depending on the setting of the voltage switch at the back side of the
Waveshare interface.

### 5.1. General considerations
Unfortunately, Waveshare does not specify a maximum output current for the
`VCC` pin in either the product page or the wiki. Waveshare only state that
the module is powered from the USB 5V supply, and has a resettable fuse for
overcurrent protection, and that the interface itself consumes about 55-65 mA
during normal operation. The 5 V VCC pin is essentially connected to the USB
power rail through the module's protection circuitry (resettable fuse, ESD
protection). The rating of the onboard resettable fuse is not specified by
Waveshare, and neither is the voltage drop across the protection circuitry.

Therefore, as a practical recommendation and rule of thumb, it may be
considered safe to use the Waveshare interface as power supply for small
logic circuits (tens of mA), UART interfaces, sensors, level shifters, etc.
Most probably, acceptable loads are around 100–200 mA, provided that the total
USB current remains modest. One should however clearly avoid using the
interface as the power supply of larger boards (say, an Arduino, Raspberry Pi
or the RC2014), motors, relays, displays with backlights or similar directly
from the `VCC` pin.

### 5.2. If the UART communication becomes unreliable
Interestingly, Waveshare's own troubleshooting guide says that <em>if
communication becomes unreliable because a connected device has high power
consumption, you should use an external power supply for the target device
and simply connect the grounds together.</em>
This statement is a strong indication that the `VCC` output pin of the
Waveshare interface is not intended as a high-current supply.

### 5.3. Specifically for the RC2014 Z80 computer
The RC2014 Z80 computer should not be powered by the Waveshare's `VCC` pin.
Even a minimal RC2014 can draw well over 100 mA, and larger configurations with
multiple modules can require several hundred milliamps. Measured in "idling
mode" (see Figs. 4 and 5) without any programs running, the basic RC2014
Mini II is drawing about 76 mA, which seems to be above the limit of the
<i>Waveshare USB to UART/I2C/SPI/JTAG</i> interface.

![Baseline current surge of the Waveshare USB to UART/I2C/SPI/JTAG interface
without any other device attached.](waveshare-d.jpg)</br>
<b>Figure 4.</b> Baseline current surge of the <i>Waveshare USB to
UART/I2C/SPI/JTAG</i> interface with without any other device attached,
measured to be about 43 mA, or 220 mW.](waveshare-d.jpg)</br>

![Current surge of the Waveshare USB to UART/I2C/SPI/JTAG interface
with the basic RC2014 Mini II Z80 computer connected to the UART (without the
CP/M Upgrade hardware attached).](waveshare-e.jpg)</br>
<b>Figure 5.</b> Current surge of the <i>Waveshare USB to UART/I2C/SPI/JTAG</i>
interface with the basic RC2014 Mini II Z80 computer connected to the UART
(without the CP/M Upgrade hardware attached), measured to be about 119 mA,
or 608 mW. The conclusion is that the RC2014 Mini II Z80 computer draws about
119&minus;43 mA = 76 mA, which is slightly too much to drive for the `VCC`
pin of the interface.

However, the direct integrated USB-to-TTL interface from the same company seems
to perfectly well be powering the single-board RC2014 Mini II Z80 computer
without the CP/M Upgrade hardware attached. <em>Hence, it seems like the
"industrial" variant of the Waveshare interface actually is coping less
well when it comes to power supply using the `VCC`pin of the UART.</em>

In any case, the recommentation is to always power the RC2014 Mini II computer
using a separate, regulated 5 V supply such as an iPhone charger or similar.
Here it is important that the power supply shares the same signal ground as the
FTDI connector of the UART, as the signal levels otherwise run a risk of being
corrupted.

Hence, to be on the safe side, use the following connections:
```
  ----------              ----------
  | UART 0 |              | RC2014 |
  ----------              ----------

     TX  ------------------>  RX
     RX  <------------------  TX

     RTS ------------------> CTS
     CTS <------------------ RTS

     GND ------------------- GND
```
