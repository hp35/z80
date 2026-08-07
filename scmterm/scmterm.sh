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
# or /dev/ttyACM1. In some sense, one may consider the present SCMTERM script
# as being a sort-of "mini-miniterm".
#
# See https://github.com/hp35/z80/tree/main/scmterm for documentation and
# details on usage and installation.
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
#         -l <logdir>     Record the entire SCMTERM session to log file
#                         located in the <logdir> directory. If no -l
#                         command-line option is present, then SCMTERM
#                         will check if there is a ./log/ directory in the
#                         current working directory where SCMTERM was invoked;
#                         if found to exist logging will be done to this
#                         directory regardless of a missing -l option.
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
# Parameters for logging of the SCMTERM session.
#
LOGGING=0
LOGDIR=""
LOGFILE=""

#
# Intel HEX file information to be extracted during upload to SCM/Z80.
# Last modified: 202660806/FJ
#
HEX_RECORDS=0
HEX_DATA_RECORDS=0
HEX_EOF_RECORDS=0
HEX_EXTSEG_RECORDS=0
HEX_EXTLIN_RECORDS=0
HEX_STARTSEG_RECORDS=0
HEX_STARTLIN_RECORDS=0
HEX_DATA_BYTES=0
HEX_LOWEST_ADDRESS=-1
HEX_HIGHEST_ADDRESS=0

#
# Analyse an Intel HEX file for inherent information before upload to SCM/Z80.
# Last modified: 202660806/FJ
#
analyse_hex() {
    local FILE="$1"
    local LINE
    local LEN
    local TYPE
    local ADDR

    #
    # Reset statistics.
    #
    HEX_RECORDS=0
    HEX_DATA_RECORDS=0
    HEX_EOF_RECORDS=0
    HEX_EXTSEG_RECORDS=0
    HEX_EXTLIN_RECORDS=0
    HEX_STARTSEG_RECORDS=0
    HEX_STARTLIN_RECORDS=0
    HEX_DATA_BYTES=0
    HEX_LOWEST_ADDRESS=-1
    HEX_HIGHEST_ADDRESS=0

    while IFS= read -r LINE
    do
        [[ ${LINE:0:1} != ":" ]] && continue
        [[ ${#LINE} -lt 11 ]] && continue
        ((HEX_RECORDS++))
        LEN=$((16#${LINE:1:2}))
        ADDR=$((16#${LINE:3:4}))
        TYPE=$((16#${LINE:7:2}))

        case "$TYPE" in
            0)
                ((HEX_DATA_RECORDS++))
                ((HEX_DATA_BYTES += LEN))
                if (( HEX_LOWEST_ADDRESS < 0 || ADDR < HEX_LOWEST_ADDRESS ))
                then
                    HEX_LOWEST_ADDRESS=$ADDR
                fi

                if (( ADDR + LEN - 1 > HEX_HIGHEST_ADDRESS ))
                then
                    HEX_HIGHEST_ADDRESS=$((ADDR + LEN - 1))
                fi
                ;;
            1)
                ((HEX_EOF_RECORDS++))
                ;;
            2)
                ((HEX_EXTSEG_RECORDS++))
                ;;
            3)
                ((HEX_STARTSEG_RECORDS++))
                ;;
            4)
                ((HEX_EXTLIN_RECORDS++))
                ;;
            5)
                ((HEX_STARTLIN_RECORDS++))
                ;;
        esac
    done < "$FILE"
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
        Display the SCMTERM communication settings.
    quit
        Return to SCM terminal mode.
EOF
}

#
# Initialize any logging (recording) of the SCMTERM session.
#
init_logging() {

    #
    # Explicit directory supplied
    #
    if [[ -n "$LOGDIR" ]]
    then

        if [[ ! -d "$LOGDIR" ]]
        then
            echo "Logging directory does not exist: $LOGDIR"
            exit 1
        fi
    else
        #
        # Automatic ./log detection
        #
        if [[ -d "./log" ]]
        then
            LOGDIR="./log"
        else
            return
        fi
    fi
    LOGFILE="$LOGDIR/scmterm-$(date '+%Y%m%d_%H%M').log"
    touch "$LOGFILE"
    if [[ $? -ne 0 ]]
    then
        echo "Cannot create log file: $LOGFILE"
        exit 1
    fi
    LOGGING=1
    {
        echo "=============================================="
        echo "SCMTERM session started"
        echo "Date: $(date)"
        echo "Device: $DEVICE"
        echo "Serial: ${BAUD}-8-${PARITY}-${STOPBITS}"
        echo "=============================================="
        echo
    } >> "$LOGFILE"
}

#
# Define the "local logging" functions log_local() and log_local_line(),
# which handle the logging of SCMTERM's own actions, while the receiver
# logs SCM's own output.
#
log_local()
{
    if (( LOGGING ))
    then
        printf "%s" "$1" >> "$LOGFILE"
    fi
}

#log_local() {
#    if [[ "$LOGGING" -eq 1 ]]
#    then
#        printf "%s" "$1" >> "$LOGFILE"
#    fi
#}


#log_local_line() {
#    if [[ "$LOGGING" -eq 1 ]]
#    then
#        printf "%s\n" "$1" >> "$LOGFILE"
#    fi
#}

#
# Write one complete SCMTERM log line.
#
log_local_line()
{
    if (( LOGGING ))
    then
        printf "%s\n" "$1" >> "$LOGFILE"
    fi
}

#
# Startup banner of the SCMTERM script.
#
scmterm_banner() {
    echo -n "This is SCMTERM v.1.0. "
    echo "Copyright (C) 2026 Fredrik Jonsson under GPL 3.0"
    echo "Logging session to $LOGFILE"
    echo "    Use 'Ctrl-T' to enter SCMTERM command mode."
    echo "    Use 'Ctrl-X' or 'Ctrl-]' to exit SCMTERM."
    log_local_line "This is SCMTERM v.1.0."
    log_local_line "Copyright (C) 2026 Fredrik Jonsson under GPL 3.0"
    log_local_line "Logging session to $LOGFILE"
    log_local_line "    Use 'Ctrl-T' to enter SCMTERM command mode."
    log_local_line "    Use 'Ctrl-X' or 'Ctrl-]' to exit SCMTERM."
}

#
# Print a complete line atomically.
# Last modified: 202660806/FJ
#
term_print() {
    printf "%s\n" "$1"
    if (( LOGGING ))
    then
        printf "%s\n" "$1" >> "$LOGFILE"
    fi
}

#
# Configuration of the serial interface
#
configure_serial_interface() {
    STTY_PARITY=""
    STTY_STOP=""
    case "$PARITY" in
        N)
            STTY_PARITY="-parenb"
	    ;;
        E)
            STTY_PARITY="parenb -parodd"
	    ;;
        O)
            STTY_PARITY="parenb parodd"
	    ;;
        *)
            echo "Invalid parity: $PARITY"
            exit 1
	    ;;
    esac

    case "$STOPBITS" in
        1)
            STTY_STOP="-cstopb"
	    ;;
        2)
            STTY_STOP="cstopb"
	    ;;
        *)
            echo "Invalid stop bits: $STOPBITS"
            exit 1
	    ;;
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
# Open UART for bidirectional communication and enter "raw" keyboard mode.
# The '-opost' option would disable Linux output processing explicitly,
# avoiding the kernel doing additional translations behind the curtains.
# Last modified: 202660804/FJ
#
open_uart() {
    exec 3> "$DEVICE"
    exec 4< "$DEVICE"
    stty -icanon -echo min 1 time 0
}

#
# Restore the original terminal state after finishing.
# Last modified: 202660804/FJ
#
cleanup() {
    #
    # Restore keyboard.
    #
    stty "$OLDTTY"

    #
    # Stop receiver.
    #
    if [[ -n "$RX_PID" ]]
    then
        kill "$RX_PID" 2>/dev/null
        wait "$RX_PID" 2>/dev/null
    fi

    #
    # Close UART.
    #
    exec 3>&-

    printf "\nLeaving SCMTERM.\n"
}

#
# Append received UART data to the SCMTERM log. This routine is logging
# everything received from SCM; however notice that it does not write
# anything to the terminal.
#
log_receiver() {
    while IFS= read -r -n1 CHAR
    do
        printf "%s" "$CHAR" >> "$LOGFILE"
    done
}


#log_receiver() {
#    if (( LOGGING ))
#    then
#        cat >> "$LOGFILE"
#    else
#        cat >/dev/null
#    fi
#}

#
# Open the serial (UART) receiver of text from the SCM interface. In the
# present scheme, the UART stream, without any parsing, buffering or
# interference with the displayed output, becomes
#
#       UART
#         │
#         ▼
#        tee
#        ├──────────────► Terminal
#        │
#        └──────────────► log_receiver()
#                              │
#                              ▼
#                          logfile
#
# Last modified: 202660807/FJ [Radically simplifying the receiver.]
#
#receiver() {
#    cat <&4
#}

#receiver() {
#    if (( LOGGING ))
#    then
#        tee >(log_receiver) <&4
#    else
#        cat <&4
#    fi
#}


receiver() {
    if (( LOGGING ))
    then
        tee >(log_receiver) <&4
    else
        cat <&4
    fi
}

#
# Display a linear progress bar for HEX file transfer, from 0% to 100%.
#
progress_bar() {
    local CURRENT=$1
    local TOTAL=$2

    local WIDTH=50
    local FILLED
    local PERCENT

    (( TOTAL == 0 )) && TOTAL=1

    FILLED=$(( CURRENT * WIDTH / TOTAL ))
    PERCENT=$(( CURRENT * 100 / TOTAL ))

    printf "\r["

    for ((i=0; i<FILLED; i++))
    do
        printf "="
    done

    printf ">"

    for ((i=FILLED+1; i<WIDTH; i++))
    do
        printf " "
    done

    printf "] %3d%%" "$PERCENT"

    if (( CURRENT == TOTAL ))
    then
        printf "\n"
    fi
}

#
# Routine for sending Intel HEX code to the SCM receiver, essentially being
# machine code formatted as ASCII. For details on the Intel HEX code format,
# see the Wikipedia article at https://en.wikipedia.org/wiki/Intel_HEX or
# developer details at https://developer.arm.com/documentation/ka003292/1-0/
# Last modified: 202660806/FJ
#
send_hex() {
    local FILE="$1"
    local LINE
    local RECORDS=0
    local BYTES=0
    local LEN

    if [[ -z "$FILE" ]]
    then
        term_print "Usage: send <file.hex>"
        return
    fi

    if [[ ! -f "$FILE" ]]
    then
        term_print "Error: Intel HEX file '$FILE' not found!"
        return
    fi

    #
    # Scan the file prior to submission to SCM/Z80.
    #
    analyse_hex "$FILE"

    kill -STOP "$RX_PID"

    printf "%s\n" "----------------------------------------------------"
    printf "%s\n" "Intel HEX file analysis"
    printf "%s\n" "----------------------------------------------------"
    printf "File               : %s\n" "$FILE"
    printf "Total records      : %d\n" "$HEX_RECORDS"
    printf "Data records       : %d\n" "$HEX_DATA_RECORDS"
    printf "EOF records        : %d\n" "$HEX_EOF_RECORDS"

    if (( HEX_EXTSEG_RECORDS ))
    then
        printf "Ext. segment recs  : %d\n" "$HEX_EXTSEG_RECORDS"
    fi

    if (( HEX_EXTLIN_RECORDS ))
    then
        printf "Ext. linear recs   : %d\n" "$HEX_EXTLIN_RECORDS"
    fi

    printf "Data bytes         : %d\n" "$HEX_DATA_BYTES"

    if (( HEX_LOWEST_ADDRESS >= 0 ))
    then
        printf "Lowest address     : %04XH\n" "$HEX_LOWEST_ADDRESS"
        printf "Highest address    : %04XH\n" "$HEX_HIGHEST_ADDRESS"
    fi

    printf "\nUploading Intel HEX file $FILE to device ...\n\n"

    kill -CONT "$RX_PID"

    #
    # Transfer the Intel HEX file.
    #
    CURRENT=0

    while IFS= read -r LINE
    do
        printf "%s\r" "$LINE" >&3
        ((CURRENT++))
        progress_bar "$CURRENT" "$HEX_RECORDS"
        if (( LOGGING ))
        then
            printf ">> %s\n" "$LINE" >> "$LOGFILE"
        fi
        sleep "$HEX_DELAY"
    done < "$FILE"

    #
    # Give SCM a chance to respond.
    #
    sleep 0.20
    kill -STOP "$RX_PID"
    printf "%s\n" ""
    printf "%s\n" "----------------------------------------------------"
    printf "%s\n" "Transfer of $FILE completed successfully."
    printf "%s\n" "----------------------------------------------------"
    kill -CONT "$RX_PID"
}

#
# Display the communication parameters of the SCMTERM.
#
scmterm_info() {
    printf "%s\n" "----------------------------------------------------"
    printf "%s\n" "SCMTERM communication settings"
    printf "%s\n" "----------------------------------------------------"
    printf "%s\n" "Device       : $DEVICE"
    printf "%s\n" "Baud rate    : $BAUD"
    printf "%s\n" "Data bits    : 8"
    printf "%s\n" "Parity       : $PARITY"
    printf "%s\n" "Stop bits    : $STOPBITS"
    if [[ "$FLOWCONTROL" -eq 1 ]]
    then
        printf "%s\n" "Flow control : RTS/CTS enabled"
    else
        printf "%s\n" "Flow control : disabled"
    fi
    printf "%s\n" "----------------------------------------------------"
    printf "%s\n" "Available SCMTERM commands in command mode (Ctrl-T):"
    printf "%s\n" "  send <file.hex>   Send Intel HEX file."
    printf "%s\n" "  info              Display SCMTERM configuration."
    printf "%s\n" "  quit              Exit command mode and return to SCM."
}

#
# Invoke the "command mode" of the SCMTERM terminal, after Ctrl-T has been
# entered.
#
command_mode() {
    local CMD
    local ARG

    #
    # Make sure that we log the entering of command mode (if we are logging).
    #
    log_local_line "----------------------------------------"
    log_local_line "Entering SCMTERM terminal command mode"
    log_local_line "----------------------------------------"

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
    echo "    quit             Exit command mode and return to SCM."
    echo ""
    while true
    do
        printf "cmd> "
        read -r CMD ARG
	log_local_line "cmd> $CMD $ARG"
        case "$CMD" in
            send)
                send_hex "$ARG"
		;;
            info)
                scmterm_info
		;;
            quit)
                log_local_line "----------------------------------------"
                log_local_line "Leaving command mode of the SCMTERM terminal"
                log_local_line "----------------------------------------"
                echo "----------------------------------------"
                echo "Leaving command mode of the SCMTERM terminal"
                echo "----------------------------------------"
                break
		;;
            "")
                ;;
            *)
                echo "Unknown command: $CMD"
		;;
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
            echo "Leaving SCMTERM"
            break
        fi

        case "$KEY" in

            $'\003'|$'\030'|$'\035')
                echo "Leaving SCMTERM by Ctrl-X or Ctrl-]"
                break
		;;

            $'\024')
                command_mode
		;;

            $'\012'|$'\015')
                printf '\r' >&3
                log_local $'\r'
		;;

            *)
                printf '%s' "$KEY" >&3
                log_local "$KEY"
		;;

        esac
    done
}

#
# Parse any present command-line options.
#
while getopts ":d:b:p:s:l:fh" opt; do
    case "$opt" in
        d)
            DEVICE="$OPTARG"
	    ;;
        b)
            BAUD="$OPTARG"
	    ;;
        p)
            PARITY=$(echo "$OPTARG" | tr '[:lower:]' '[:upper:]')
	    ;;
        s)
            STOPBITS="$OPTARG"
	    ;;
        l)
            LOGDIR="$OPTARG"
	    ;;
        f)
            FLOWCONTROL=1
	    ;;
        h)
            usage
            exit 0
	    ;;
        :)
            echo "Option -$OPTARG requires an argument"
            echo "Use -h for help"
            exit 1
	    ;;
        \?)
            echo "Unknown option: -$OPTARG"
            echo "Use -h for help"
            exit 1
	    ;;
    esac
done

#
# The 'main()' of the SCMTERM script. This is where we start as well as end.
#
init_logging
configure_serial_interface
save_terminal_state
trap cleanup EXIT
open_uart
receiver &
RX_PID=$!
main_loop
