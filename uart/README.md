# Configuration of GTKTerm and Waveshare USB to UART/I2C/SPI/JTAG

**Fredrik Jonsson**
July 2, 2026
[https://github.com/hp48/z80/waveshare/README.md](https://github.com/hp48/z80/waveshare/README.md)

In this tutorial, we will use GTKTerm [1] together with the Waveshare USB to
UART/I2C/SPI/JTAG interface [2] to show how a simple UART communication channel
is setup. In particular, we will show how we with the Waveshare interface,
which internally contains two independently operated UART interfaces, can
check the communication by simply having the two interfaces communicating
with each other.

   [1] Willem van den Akker, "GTKTerm: A GTK+ Serial Port Terminal",
       https://github.com/wvdakker/gtkterm
   [2] Waveshare USB to UART/I2C/SPI/JTAG interface,
       https://www.waveshare.com/wiki/USB_TO_UART/I2C/SPI/JTAG

## Default settings

   For the UART side in GTKTerm, the correct settings depend mostly on the
   device you connect to, not the Waveshare interface itself. The adapter
   is usually transparent to these settings.

   That said, the most common/default settings for the classic "115200 8N1"
   setup are:

        Baud rate: 115200
        Data bits: 8
        Parity: None
        Stop bits: 1
        Flow control: None

## Basic setup

### Connect your computer with a USB cable (USB-A to USB-B) to the
        Waveshare USB to UART/I2C/SPI/JTAG module, with switches set to
        5V and S1 and S2 both to OFF (in order to use the UART ports).
	Check that the red power light (PWR) is lit.

### Make sure that the two UARTs of the Waveshare interface shows up
        at your computer as the two devices /dev/ttyACM0 and /dev/ttyACM1:

    ```bash
            ls /dev/ttyACM*
    ```
    ```
                crw-rw---- 1 root dialout 166, 0 Jul  2 10:39 /dev/ttyACM0
                crw-rw---- 1 root dialout 166, 1 Jul  2 10:23 /dev/ttyACM1
    ```

   2.3. For simplicity, we CAN make the device accessible to all users, not
        only root. I personally find it inconvenient and not kosher to every
        now and then use "sudo" for the most basic things. Check that the
        permissions have been changed.

            sudo chmod a+rw /dev/ttyACM*
            ls -l /dev/tty*
    
                crw-rw-rw- 1 root dialout 166, 0 Jul  2 10:39 /dev/ttyACM0
                crw-rw-rw- 1 root dialout 166, 1 Jul  2 10:23 /dev/ttyACM1

   2.4. However, devices in /dev/tty (and related ports like /dev/ttyUSB0
        or /dev/ttyACM0) do not keep permissions set by chmod because they
	are virtual files which are created dynamically by the kernel and
	udev every time the system boots, a user logs in, or a device is
	reconnected. Therefore, a more permanent fix of the issue of
	permissions is to instead permanently add your user name to the
	system group that owns the device rather than changing the device's
	permissions.
	
	Do this by the following by noting the name of the group obtained
	by "ls /dev/ttyACM*", in this case "dialout". Add your current user
	(or a specific username) to the group that controls the device using
	the usermod command:

            sudo usermod -a -G dialout $USER

        Where $USER is your user name as returned by the shell. Apply the
	changes by fully logging out of your session and log back in (or
	restart your system) for the group assignment to take effect.

   2.5. Launch GTKTerm without any RTS/CTS control, just using the TX and RX
        pins. We do this either "as is" or with options explicitly stated at
        startup:

            sudo gtkterm --port /dev/ttyACM0 ..speed 115200 --bits 8 \
                         --stopbits 1 --parity none --flow none

        Alternatively, we can launch with RTS/CTS control enabled, by changing
        the flow switch to "--flow CTS", instead using
    
           sudo gtkterm --port /dev/ttyACM0 ..speed 115200 --bits 8 \
                        --stopbits 1 --parity none --flow CTS

        Even with nothing connected to the UART, you should see the TXD0 LED
        flicker whenever you type anything in the GTKTerm terminal.

3. Checking loopback without flow control

   Just for the sake of it, disconnect the Waveshare interface from USB to
   avoid accidentally shorting against live pins.

   3.1. Connect the TXD pin of UART0 with the RXD pin of UART1.
        Connect the RXD pin of UART0 with the TXD pin of UART1.
        Connect the GND pin of UART0 with the GND pin of UART1.
   
        In principle, this connection of ground is not needed as the two UARTs
	in the Waveshare interface share the same griynd, but just for the sake
	of illustrating how two different UARTs should be communicating, they
	should have a ground line interconnecting them, determining the base
	voltage of the signal levels.
	
   3.2. Power up the Waveshare interface by connecting it with the USB cable
        to the computer again.
	
   3.3. Start two (2) GTKTerm terminals as two separate processes, each one
        connecting to a separate UART, by

           gtkterm --port /dev/ttyACM0 ..speed 115200 --bits 8 \
	           --stopbits 1 --parity none --flow none &
           gtkterm --port /dev/ttyACM1 ..speed 115200 --bits 8 \
	           --stopbits 1 --parity none --flow none &

        We here state the parameters to use explicitly; however, this is in
	most cases completely unneccessary, and we may most often just use
	"gtkterm --port /dev/ttyACM0".

  3.4. When typing in text in the first terminal, the typed text should be
       received and displayed by the second terminal (which is operating
       independent of the first one), and vice versa.

       When typing in the first terminal (associated with UART0), the green
       TXD0 LED (for the transmission of data from UART0) of the Waveshare
       interface should flicker together with the blue RXD1 LED (for the
       reception of data by UART1).

       Also, when typing in the second terminal (associated with UART1),
       the green TXD1 LED (for the transmission of data from UART1) of
       the Waveshare interface should flicker together with the blue RXD0
       LED (for the reception of data by UART0).

4. Checking loopback with CTS/RTS flow control

   We will now carry out the same test with loopback of the signals, but
   now also apply flow control, using the extra UART handshake lines

       RTS = Request To Send
       CTS = Clear To Send

   What CTS/RTS actually does is to enable hardware flow control, for example
   used for preventing buffer overruns and throttling fast transfers.
   The CTS/RTS flow control is not required for ordinary UART communication,
   and most hobby/microcontroller UART setups only make use of the standard
   TX, RX and GND, ignoring the CTS and RTS pins entirely.

   4.1. Connect the TXD pin of UART0 with the RXD pin of UART1.
        Connect the RXD pin of UART0 with the TXD pin of UART1.
        Connect the RTS pin of UART0 with the CTS pin of UART1.
        Connect the CTS pin of UART0 with the RTS pin of UART1.
        Connect the GND pin of UART0 with the GND pin of UART1.
   
        Conceptually, just as in the case of the TX/RX pins, we need to cross
        also the RTS/CTS pins between the two UARTs, as illustrated below.

             ----------                     ----------
             | UART 0 |                     | UART 1 |
             ----------                     ----------

                TX  ------------------------->  RX
                RX  <-------------------------  TX

                RTS -------------------------> CTS
                CTS <------------------------- RTS

                GND -------------------------- GND

   4.2. Power up the Waveshare interface by connecting it with the USB cable
        to the computer again.
	
   4.3. Start two (2) GTKTerm terminals as two separate processes, each one
        connecting to a separate UART and just as in the previous case without
        flow control, with the slight change of the --flow option, which we
        now instead set to CTS, by

           gtkterm --port /dev/ttyACM0 ..speed 115200 --bits 8 \
	           --stopbits 1 --parity none --flow CTS &
           gtkterm --port /dev/ttyACM1 ..speed 115200 --bits 8 \
	           --stopbits 1 --parity none --flow CTS &

  4.4. When typing in text in the first terminal, the typed text should be
       received and displayed by the second terminal (which is operating
       independent of the first one), and vice versa.

       When typing in the first terminal (associated with UART0), the green
       TXD0 LED (for the transmission of data from UART0) of the Waveshare
       interface should flicker together with the blue RXD1 LED (for the
       reception of data by UART1).

       Also, when typing in the second terminal (associated with UART1),
       the green TXD1 LED (for the transmission of data from UART1) of
       the Waveshare interface should flicker together with the blue RXD0
       LED (for the reception of data by UART0).

