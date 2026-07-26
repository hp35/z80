#!/bin/bash
#
# SCMTERM - Small Computer Monitor TERMinal for RC2014 and related platforms
#
# Bash script for interfacing the Small Computer Monitor (SCM) [1] running
# on the RC2014 Z80 single card computer [2] from a standard terminal in any
# Linux-based system like Debian, Fedora, Ubuntu or Raspbian (Raspberry Pi).
#
# The idea behind the SCMTERM script is to provide an extremely light-weight
# alternative to the standard GTKTerm [3] option of communication, which
# requires a separate window for the operation. Using the SCMTERM script,
# everything can be run directly from a single command line, operating via
# any port connected to the UART interface [4], like /dev/ttyUSB0, /dev/ttyACM0
# or /dev/ttyACM1.
#
# Usage:
#     scmterm [options]
#
#     Options:
#         -d device       Serial device
#                         Default: /dev/ttyUSB0
#         -b baud         Baud rate
#                         Default: 115200
#         -p parity       Parity
#                         N = none (default)
#                         E = even
#                         O = odd
#         -s stopbits     Stop bits
#                         1 (default)
#                         2
#         -f              Enable RTS/CTS hardware flow control
#         -h              Display this help message
#
#     Default serial configuration:
#         115200 baud
#         8 data bits
#         No parity
#         1 stop bit
#         No flow control
#
#     SCMTERM operation:
#         Normal mode:
#             Keys are sent directly to the RC2014 SCM monitor.
#         Enter:
#             Sends CR (0x0D) to SCM.
#         Ctrl-T:
#             Enter SCMTERM command mode.
#         Ctrl-C:
#             Exit SCMTERM.
#
#     Command mode:
#         send <file.hex>
#             Send Intel HEX file to SCM.
#         info
#             Display the SCMTERM communication settings."
#         quit
#             Return to SCM terminal mode.
#
# References
#
#     [1] Small Computer Monitor by Stephen C. Cousins, www.scc.me.uk.
#         For documentation and source, see https://smallcomputercentral.com/
#         /small-computer-monitor/small-computer-monitor-v1-0/
#     [2] RC2014 Mini II, https://z80kits.com/shop/rc2014-mini-ii/
#     [3] Willem van den Akker, GTKTerm: A GTK+ Serial Port Terminal,
#         https://github.com/wvdakker/gtkterm.
#     [4] Waveshare USB to UART/I2C/SPI/JTAG interface,
#         https://www.waveshare.com/wiki/USB_TO_UART/I2C/SPI/JTAG
#
# Copyright (C) 2026, Fredrik Jonsson, under Gnu General Public License
# (GPL) v3. See the enclosed LICENSE for details.
#
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
#
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

#
# Default initialization of SCMTERM communication parameters for the port.
# Common ports for UART interfaces are /dev/ttyUSB0, /dev/ttyACM0 and
# /dev/ttyACM1.
#
DEVICE="/dev/ttyUSB0"
BAUD=115200
PARITY="N"
STOPBITS=1
FLOWCONTROL=0
HEX_DELAY=0.02

#
# Startup banner of the SCMTERM script.
#
scmterm_banner() {
    echo -n "This is SCMTERM v.1.0. "
    echo "Copyright (C) 2026 Fredrik Jonsson under GPL 3.0"
    echo "    Use 'Ctrl-T' to enter command mode."
    echo "    Use 'Ctrl-X' or ']' to exit SCMTERM."
}

#
# Usage message, direction on options.
#
usage() {
cat << EOF
SCMTERM - Small Computer Monitor TERMinal for RC2014 and related platforms

Usage:
    $0 [options]

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
EOF
}

#
# Configuration of the serial interface
#
configure_serial_interface() {
    STTY_PARITY=""
    STTY_STOP=""
    case "$PARITY" in
        N)
            STTY_PARITY="-parenb";;
        E)
            STTY_PARITY="parenb -parodd";;
        O)
            STTY_PARITY="parenb parodd";;
        *)
            echo "Invalid parity: $PARITY"
            exit 1;;
    esac

    case "$STOPBITS" in
        1)
            STTY_STOP="-cstopb";;
        2)
            STTY_STOP="cstopb";;
        *)
            echo "Invalid stop bits: $STOPBITS"
            exit 1;;
    esac

    if [[ "$FLOWCONTROL" -eq 1 ]]
    then
        FLOW="crtscts"
    else
        FLOW="-crtscts"
    fi

    stty -F "$DEVICE" "$BAUD" cs8 $STTY_PARITY $STTY_STOP raw -echo $FLOW
}

#
# Save the original terminal state before proceeding.
#
save_terminal_state () {
    OLDTTY=$(stty -g)
}

#
# Restore the original terminal state after finishing.
#
cleanup() {
    stty "$OLDTTY"

    kill "$RX_PID" 2>/dev/null

    wait "$RX_PID" 2>/dev/null

    exec 3>&-
    exec 4<&-

    echo
}

#
# Open UART for communication and enter "raw" keyboard mode.
#
open_uart() {
    exec 3> "$DEVICE"
    exec 4< "$DEVICE"
    stty -icanon -echo min 1 time 0
}

#
# Open the serial receiver of text from the SCM interface.
#
receiver() {
    while true
    do
        # dd bs=1 count=1 <&3 2>/dev/null
	dd bs=1 count=1 <&4 2>/dev/null
    done
}

#
# Intel HEX code sender. For details on the Intel HEX code format, see
# https://en.wikipedia.org/wiki/Intel_HEX or
# https://developer.arm.com/documentation/ka003292/1-0/
#
send_hex() {
    local FILE="$1"
    local LINE
    if [[ -z "$FILE" ]]
    then
        echo "Usage: send <file.hex>"
        return
    fi
    if [[ ! -f "$FILE" ]]
    then
        echo "File not found: $FILE"
        return
    fi
    echo
    echo "Sending $FILE"
    echo
    while IFS= read -r LINE
    do
        #
        # SCM expects CR terminated lines
        #
        printf "%s\r" "$LINE" >&3
        sleep "$HEX_DELAY"
    done < "$FILE"
    echo "----------------------------------------"
    echo "Transfer complete of hex file $FILE"
    echo "----------------------------------------"
}

#
# Display the communication parameters of the SCMTERM.
#
scmterm_info()
{
    echo "----------------------------------------"
    echo "SCMTERM communication settings"
    echo "----------------------------------------"
    echo "Device       : $DEVICE"
    echo "Baud rate    : $BAUD"
    echo "Data bits    : 8"
    echo "Parity       : $PARITY"
    echo "Stop bits    : $STOPBITS"

    if [[ "$FLOWCONTROL" -eq 1 ]]
    then
        echo "Flow control : RTS/CTS enabled"
    else
        echo "Flow control : disabled"
    fi

    echo "----------------------------------------"
    echo "Available commands in command mode:"
    echo "  send <file.hex>   Send Intel HEX file"
    echo "  info              Display SCMTERM configuration"
    echo "  quit              Exit command mode and return to SCM.\n"
    echo
}

#
# Invoke the "command mode" of the SCMTERM terminal, after Ctrl-T has been
# entered.
#
command_mode() {
    local CMD
    local ARG

    #
    # Stop the "raw" keyboard mode.
    #
    stty echo icanon
    echo "----------------------------------------"
    echo "Entering SCMTERM terminal command mode"
    echo "----------------------------------------"
    echo "Valid commands within command mode:"
    echo "    send <file.hex>  Send Intel HEX file."
    echo "    info             Display the SCMTERM communication settings."
    echo "    quit             Exit command mode and return to SCM.\n"
    while true
    do
        printf "cmd> "
        read -r CMD ARG
        case "$CMD" in
            send)
                send_hex "$ARG";;
            info)
                scmterm_info;;
            quit)
                echo "Leaving command mode of the SCMTERM terminal"
                break;;
            "")
                ;;
            *)
                echo "Unknown command: $CMD";;
        esac
    done

    #
    # Restore the SCM terminal mode.
    #
    stty -icanon -echo min 1 time 0
    echo
}


#
# Enter the main keyboard loop of SCMTERM.
#
main_loop() {
    scmterm_banner
    while true
    do
        IFS= read -r -N1 KEY

        if [[ "$KEY" == $'\003' ]]
        then
            echo
            echo "Leaving RC2014 terminal"
            break
        fi
    
        if [[ $(printf '%d' "'$KEY") -eq 3 ]]
        then
            echo
            echo "Leaving RC2014 terminal"
            break
        fi

        case "$KEY" in

            $'\003'|$'\030'|$'\035')
                echo
                echo "Leaving RC2014 terminal"
                break;;

            $'\024')
                command_mode;;

            $'\012'|$'\015')
                printf '\r' >&3;;

            *)
                printf '%s' "$KEY" >&3;;
        esac
    done
}

#
# Parse any present command-line options.
#
while getopts ":d:b:p:s:fh" opt; do
    case "$opt" in
        d)
            DEVICE="$OPTARG";;
        b)
            BAUD="$OPTARG";;
        p)
            PARITY=$(echo "$OPTARG" | tr '[:lower:]' '[:upper:]');;
        s)
            STOPBITS="$OPTARG";;
        f)
            FLOWCONTROL=1;;
        h)
            usage
            exit 0;;
        :)
            echo "Option -$OPTARG requires an argument"
            echo "Use -h for help"
            exit 1;;
        \?)
            echo "Unknown option: -$OPTARG"
            echo "Use -h for help"
            exit 1;;
    esac
done

#
# The 'main()' of the SCMTERM script. This is where we start as well as end.
#
configure_serial_interface
save_terminal_state
trap cleanup EXIT
open_uart
receiver &
RX_PID=$!
main_loop
