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
#                         located in the <logdir> directory.
#                         If no -l command-line option is present, then
#                         SCMTERM will check if there is a ./log/ directory
#                         in the current working directory where SCMTERM
#                         was invoked; if found to exist logging will be
#                         done to this directory regardless of a missing
#                         -l option.
#         -t <file.hex>   Automatically enter command mode, send the
#                         specified Intel HEX file, and exit SCMTERM.
#         -r <file.hex>   Automatically transfer and execute the Intel
#                         HEX file at the device, then monitor the output
#                         returned from SCM and wait for the SCM prompt
#                         before exiting. This option is highly useful
#                         for a smooth development flow in which we
#                         automatically can transfer and test the finished
#                         machine code in Intel HEX format.
#                         Default execution timeout is 30 seconds.
#
#                         Important: there is no universal way for SCMTERM
#                         to identify that an arbitrary Z80 program has
#                         finished. If the program running at the Z80 never
#                         returns to SCM, there is nothing in the serial
#                         stream that intrinsically says "finished".
#                         For the present purpose, returning to SCM and
#                         producing its '*' prompt is here considered as
#                         a reasonable convention.
#
#                         In the automatic execution mode, the order of
#                         things is as follows:
#                           1. If the HEX contains an Intel HEX start
#                              address record, then use that.
#                           2. Otherwise, use the lowest data address
#                              as the execution address.
#                           3. Send the HEX file over to the device over
#                              the serial interface (UART), just as we
#                              would in command mode (Ctrl-T) when running
#                              SCMTERM interactively.
#                           4. Send G<address>\r to SCM to let SCM initiate
#                              the execution of the program, starting at
#                              the identified execution <address>.
#                           5. Continue displaying the output returned by
#                              SCM over the UART.
#                           6. Regard the return of the SCM '*' prompt as
#                              "program finished".
#                           7. We meanwhile use a timeout (default 30 s)
#                              so that an accidentally infinite program
#                              cannot leave SCMTERM hanging forever.
#                           8. Exit clean from SCMTERM.
#
#         -h              Display this help message and exit.
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
#             Transfer Intel HEX file to SCM.
#         check <file.hex>
#             Check the contents of Intel HEX file, without
#             attempting to transfer it.
#         info
#             Display the SCMTERM communication settings.
#         quit
#             Return to SCM terminal mode.
#
# Workflow
#
# The idea is to use `SCMTERM` in a natural workflow from the terminal of
# a Linux workstation over to SCM running on the RC2014 Z80 platform (or
# any similar platform running SCM), as
#
#      Linux workstation
#              |
#              |  SCMTERM
#              |
#          USB-UART       [/dev/ttyACM0, /dev/ttyUSB0, or similar]
#              |
#              |
#        RC2014 UART      [Motorola MC68B50 chip on the RC2014]
#              |
#              |
#       SCM R4 monitor    [Effectively a BIOS]
#              |
#              +--> assemble / inspect memory / run programs
#
# The overall design decisions for `SCMTERM` are as follows:
#     - Keeping SCMTERM in Bash rather than eventually rewriting it in, say,
#       C or Python.
#     - Eliminating the need for running (the otherwise excellent) `GTKTerm`
#       in a separate window; everything should be possible to do via a plain
#       terminal under Linux, even via `ssh` into, say, a Raspberry Pi Zero.
#     - Keeping the RC2014 side completely untouched, with no changes to the
#       `SCM` BIOS whatsoever.
#     - Logging as optional, to ensure that long-term sessions can be properly
#       documented.
#     - Implementation of a "command mode" of `SCMTERM` (using Ctrl-T) as a
#       local terminal escape layer for checking and sending Intel HEX files
#       over to the RC2014.
#     - Avoiding unnecessary dependencies other than the `bash` interpreter.
#       ("Keep it simple, stupid!")
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
REVISION="1.1"

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
COMMODE="communicationmode"
CMDMODE="commandmode"
LOGGING=0
LOGDIR=""
LOGFILE=""
LOGMODE=$COMMODE

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
HEX_START_ADDRESS=-1

#
# Flag for the special case when SCMTERM just is to automatically transfer
# an Intel HEX file in command mode and immediately exit clean.
#
AUTO_TRANSFER=""

#
# Flag for the special case when SCMTERM just is to automatically transfer
# and run an Intel HEX file in command mode and immediately exit clean.
# Here, RUN_TIMEOUT is the timeout measured in seconds.
#
AUTO_RUN=""
RUN_TIMEOUT=30

#
# Display and log a single line of text, with leading characters depending
# on whether SCMTERM is in communication mode or command mode.
#
ll() {
    local LINE="$1"
    printf "%s\n" "$LINE"
    if (( LOGGING ))
    then
        local PREFIX=""
        case "$LOGMODE" in
            "$COMMODE")
                PREFIX="<< "
	        ;;
            "$CMDMODE")
                PREFIX="## "
	        ;;
            "")
                PREFIX=""
	        ;;
            *)
                echo "Invalid mode: $LOGMODE"
                exit 1
	        ;;
        esac
        printf "%s%s\n" "$PREFIX" "$LINE" >> "$LOGFILE"
    fi
}

#
# Display and log a single character (or string) to the log file. Neither
# any suffix or linefeed is added, in contrary to the ll() routine.
#
lc() {
    local CHARS="$1"
    printf '%s' "$CHARS"
    if (( LOGGING ))
    then
        printf '%s\n' "$CHARS" >> "$LOGFILE"
    fi
}

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
    local TMPLINE

    if [[ -z "$FILE" ]]
    then
        ll "Usage: check <file.hex>"
        return
    fi

    if [[ ! -f "$FILE" ]]
    then
        ll "Error: Intel HEX file '$FILE' not found!"
        return
    fi

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

                #
                # Start Segment Address record.
                #
                # For the 8080/Z80 use of Intel HEX, this is not normally
                # what we use, but retain it if present.
                #
                CS=$((16#${LINE:9:4}))
                IP=$((16#${LINE:13:4}))
                HEX_START_ADDRESS=$((CS * 16 + IP))
                ;;
            4)
                ((HEX_EXTLIN_RECORDS++))
                ;;
            5)
                ((HEX_STARTLIN_RECORDS++))

                #
                # Start Linear Address record.
                #
                HEX_START_ADDRESS=$((16#${LINE:9:8}))
                ;;
        esac
    done < "$FILE"

    #
    # If the HEX file is found not to contain the statement of an explicit
    # execution address, then use the lowest available data address as the
    # default for our Z80 workflow.
    #
    if (( HEX_START_ADDRESS < 0 ))
    then
        HEX_START_ADDRESS=$HEX_LOWEST_ADDRESS
    fi

    #
    # Summarize our findings from the Intel HEX file.
    #
    ll "----------------------------------------------------------"
    ll "Intel HEX file analysis"
    ll "----------------------------------------------------------"
    ll "File               : $FILE"
    ll "Total records      : $HEX_RECORDS"
    ll "Data records       : $HEX_DATA_RECORDS"
    ll "EOF records        : $HEX_EOF_RECORDS"

    if (( HEX_EXTSEG_RECORDS ))
    then
        ll "Ext. segment recs  : $HEX_EXTSEG_RECORDS"
    fi

    if (( HEX_EXTLIN_RECORDS ))
    then
        ll "Ext. linear recs   : $HEX_EXTLIN_RECORDS"
    fi

    ll "Data bytes         : $HEX_DATA_BYTES"

    if (( HEX_LOWEST_ADDRESS >= 0 ))
    then
	printf -v TMPLINE "Lowest address     : %04XH" "$HEX_LOWEST_ADDRESS"
        ll "$TMPLINE"
	printf -v TMPLINE "Highest address    : %04XH" "$HEX_HIGHEST_ADDRESS"
        ll "$TMPLINE"
	printf -v TMPLINE "Execution address  : %04XH" "$HEX_START_ADDRESS"
        ll "$TMPLINE"
    fi
    ll "----------------------------------------------------------"
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
    -t <file.hex>   Automatically enter command mode, send the
                    specified Intel HEX file, and exit SCMTERM.
    -r <file.hex>   Automatically transfer and execute the Intel
                    HEX file at the device, then monitor the output
                    returned from SCM and wait for the SCM prompt
                    before exiting. This option is highly useful
                    for a smooth development flow in which we
                    automatically can transfer and test the finished
                    machine code in Intel HEX format.
                    Default execution timeout is 30 seconds.

                    Important: there is no universal way for SCMTERM
                    to identify that an arbitrary Z80 program has
                    finished. If the program running at the Z80 never
                    returns to SCM, there is nothing in the serial
                    stream that intrinsically says "finished".
                    For the present purpose, returning to SCM and
                    producing its '*' prompt is here considered as
                    a reasonable convention.

                    In the automatic execution mode, the order of
                    things is as follows:
                      1. If the HEX contains an Intel HEX start
                         address record, then use that.
                      2. Otherwise, use the lowest data address
                         as the execution address.
                      3. Send the HEX file over to the device over
                         the serial interface (UART), just as we
                         would in command mode (Ctrl-T) when running
                         SCMTERM interactively.
                      4. Send G<address>\r to SCM to let SCM initiate
                         the execution of the program, starting at
                         the identified execution <address>.
                      5. Continue displaying the output returned by
                         SCM over the UART.
                      6. Regard the return of the SCM '*' prompt as
                         "program finished".
                      7. We meanwhile use a timeout (default 30 s)
                         so that an accidentally infinite program
                         cannot leave SCMTERM hanging forever.
                      8. Exit clean from SCMTERM.

    -h              Display this help message and exit.

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
    LOGMODE=""
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
    ll "=========================================================="
    ll "SCMTERM session started"
    ll "Date: $(date)"
    ll "Device: $DEVICE"
    ll "Serial: ${BAUD}-8-${PARITY}-${STOPBITS}"
    ll "Logging session to $LOGFILE"
    ll "=========================================================="
}

#
# Define the "local logging" function log_local() which handles the logging
# of SCMTERM's own actions, while the receiver logs SCM's own output.
#
log_local() {
    if (( LOGGING ))
    then
        printf "%s" "$1" >> "$LOGFILE"
    fi
}

#
# Startup banner of the SCMTERM script.
#
scmterm_banner() {
    ll "This is SCMTERM v.$REVISION."
    ll "Copyright (C) 2026 Fredrik Jonsson under GPL 3.0"
    ll "Logging session to $LOGFILE"
    ll "    Use 'Ctrl-T' to enter SCMTERM command mode."
    ll "    Use 'Ctrl-X' or 'Ctrl-]' to exit SCMTERM."
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
#
#                 RC2014
#                   ↕
#             /dev/ttyUSB0
#               ↙       ↘
#           FD 3         FD 4
#            TX           RX
#            │             │
#            ▼             ▼
#         SCMTERM       receiver()
#                          │
#                   ┌──────┴──────┐
#                   ▼             ▼
#                terminal        ll()
#                                 │
#                                 ▼
#                              logfile
#
# The block 'exec 3> "$DEVICE"' essentially means "open the device named by
# $DEVICE for writing, and attach the resulting file descriptor to number 3".
# In this context, the "descriptor 3" is used due to the reason that Unix
# processes (as we designed this bash script for running under Linux or any
# Unix-compatible system) normally have three standard file descriptors:
#
#        FD      Name      Normally connected to
#        0       stdin     keyboard
#        1       stdout    terminal
#        2       stderr    terminal
#
# The file descriptors 3 and above are available for our own purposes. Hence
# the SCMTERM script creates
#
#        FD 3 ──> /dev/ttyUSB0  (write)
#        FD 4 ──> /dev/ttyUSB0  (read)
#
# through the initializationof the file descriptors ("I/O channels") as
#
#        exec 3> "$DEVICE"
#        exec 4< "$DEVICE"
#
# This is highly useful for the SCMTERM script as we then can transmit commands
# directly to the RC2014 with strings like 'printf 'G9000\r' >&3', where '>&3'
# simply means "send the output of this command to file descriptor 3".
#
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
    # At cleanup, remove the temporary file for signal completion.
    #
    if [[ -n "$RUN_DONE_FILE" ]]
    then
        rm -f "$RUN_DONE_FILE"
    fi

    #
    # Close UART.
    #
    exec 3>&-

    printf "\nLeaving SCMTERM.\n"
}

#
# Append received UART data to the SCMTERM log. This routine is logging
# everything received from SCM as complete lines of output; however notice
# that it does not write anything to the terminal.
#
log_receiver() {
    local CHAR
    local LINE=""

    while IFS= read -r -d '' -n1 CHAR
    do
        case "$CHAR" in
            $'\r')
                # SCM uses CR/LF. Ignore the CR; wait for LF.
                ;;

            $'\n')
                # Complete SCM line received.
                LOGMODE="$COMMODE"
                ll "$LINE"
                LINE=""
                ;;

            *)
                LINE+="$CHAR"
                ;;
        esac
    done
}

#
# Monitor the SCM output during automatic run mode.
#
detect_scm_prompt() {
    local DATA=""

    while IFS= read -r -n1 CHAR
    do
        DATA+="$CHAR"

        #
        # Keep only the most recent few characters.
        #
        if (( ${#DATA} > 16 ))
        then
            DATA="${DATA: -16}"
        fi

        #
        # The SCM's command prompt is always '*'.
        #
        if [[ "$CHAR" == "*" ]]
        then

            #
            # We regard a '*' following a line ending as the SCM prompt.
            #
            if [[ "$DATA" == *$'\n'*"*" ]]
            then
                touch "$RUN_DONE_FILE"
            fi

        fi
    done
}

#
# Open the serial (UART) receiver of text from the SCM interface. In the
# present scheme, the UART stream, without any parsing, buffering or
# interference with the displayed output, becomes
#
#       UART
#         │
#         ▼
#        tee
#         ├──────────────► Terminal
#         │
#         └──────────────► log_receiver()
#                               │
#                               ▼
#                           logfile
#
# Last modified: 202660809/FJ [Adding SCM prompt detection.]
#
receiver() {
    #
    # Before starting the receiver in automatic run mode, create a
    # temporary file.
    #
    if [[ -n "$AUTO_RUN" ]]
    then
        RUN_DONE_FILE=$(mktemp)
        rm -f "$RUN_DONE_FILE"
    fi

    if [[ -n "$RUN_DONE_FILE" ]]
    then
        tee >(detect_scm_prompt) <&4
    elif (( LOGGING ))
    then
        tee -a "$LOGFILE" <&4
    else
        cat <&4
    fi
}

#
# Display a linear progress bar for HEX file transfer, from 0% to 100%.
# As this progress bar is displayed character-by-character, we log the
# result by calling the lc() routine (for character-wise logging) rather
# than the otherwise used ll() routine (for line-wise logging).
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
    printf '\r['
    for ((i=0; i<FILLED; i++))
    do
        printf '='
    done
    printf '>'
    for ((i=FILLED+1; i<WIDTH; i++))
    do
        printf ' '
    done
    printf "] %3d%%" "$PERCENT"
    if (( CURRENT == TOTAL ))
    then
        printf '\n'
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
        ll "Usage: send <file.hex>"
        return
    fi

    if [[ ! -f "$FILE" ]]
    then
        ll "Error: Intel HEX file '$FILE' not found!"
        return
    fi

    kill -STOP "$RX_PID"

    #
    # Scan the file prior to submission to SCM/Z80.
    #
    analyse_hex "$FILE"
    ll "Uploading Intel HEX file $FILE to device ..."

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
    ll "----------------------------------------------------------"
    ll "Transfer of $FILE completed successfully."
    ll "----------------------------------------------------------"
    kill -CONT "$RX_PID"
}

#
# Display the valid commands in SCMTERM command mode.
#
display_valid_commands() {
    ll "----------------------------------------------------------"
    ll "Valid commands within command mode:"
    ll "    send <file.hex>   Transfer Intel HEX file to device."
    ll "    check <file.hex>  Check contents of Intel HEX file."
    ll "    info              Display communication settings."
    ll "    quit              Exit command mode and return to SCM."
    ll "----------------------------------------------------------"
}

#
# Display the communication parameters of the SCMTERM.
#
scmterm_info() {
    ll "----------------------------------------------------------"
    ll "SCMTERM communication settings"
    ll "----------------------------------------------------------"
    ll "Device       : $DEVICE"
    ll "Baud rate    : $BAUD"
    ll "Data bits    : 8"
    ll "Parity       : $PARITY"
    ll "Stop bits    : $STOPBITS"
    if [[ "$FLOWCONTROL" -eq 1 ]]
    then
        ll "Flow control : RTS/CTS enabled"
    else
        ll "Flow control : disabled"
    fi
    display_valid_commands
}

#
# Invoke the "command mode" of the SCMTERM terminal, after Ctrl-T has been
# entered.
#
command_mode() {
    local CMD
    local ARG
    LOGMODE="$CMDMODE"

    #
    # Make sure that we log the entering of command mode (if we are logging).
    #
    ll "----------------------------------------------------------"
    ll "Entering SCMTERM terminal command mode"
    ll "----------------------------------------------------------"

    #
    # Stop the "raw" keyboard mode.
    #
    stty echo icanon
    display_valid_commands
    while true
    do
        printf "scmterm> "
        read -r CMD ARG

        if (( LOGGING ))
        then
            printf "## scmterm> %s" "$CMD" >> "$LOGFILE"
            if [[ -n "$ARG" ]]
            then
                printf " %s" "$ARG" >> "$LOGFILE"
            fi
            printf "\n" >> "$LOGFILE"
        fi
	
        case "$CMD" in
            send)
                send_hex "$ARG"
		;;
	    check)
                analyse_hex "$ARG"
		;;
            info)
                scmterm_info
		;;
            quit)
                ll "----------------------------------------------------------"
                ll "Leaving command mode of the SCMTERM terminal"
                ll "----------------------------------------------------------"
                LOGMODE="$COMMODE"
                break
		;;
            "")
                ;;
            *)
                ll "Unknown command: $CMD"
		display_valid_commands
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
# Automatically enter SCMTERM command mode, send an Intel HEX file, and
# exit SCMTERM clean. In this case, we refrain from entering the command
# mode, as we otherwise would have done when running the SCMTERM program
# interactively. The automatic transmission sequence is as follows:
#
#        Linux
#          │
#          ├── start SCMTERM
#          │
#          ├── configure UART
#          │
#          ├── start receiver
#          │
#          ├── enter SCMTERM command mode
#          │
#          ├── send <file.hex>
#          │
#          ├── wait for send_hex() to finish
#          │
#          ├── cleanup
#          │
#          └── exit SCMTERM and return to Linux shell
#
# It is here important to notice that no read operation whatsoever is polled
# from the keyboard in -t mode, so there is no possibility of the script
# hanging waiting for quit.
#
automatic_transfer()
{
    local FILE="$AUTO_TRANSFER"

    if [[ -z "$FILE" ]]
    then
        echo "No Intel HEX file specified for automatic transfer."
        return 1
    fi

    if [[ ! -f "$FILE" ]]
    then
        echo "Intel HEX file not found: $FILE"
        return 1
    fi

    #
    # Display the SCMTERM banner.
    #
    scmterm_banner

    #
    # Display command-mode heading, as if Ctrl-T had been pressed.
    #
    ll "----------------------------------------"
    ll "Entering SCMTERM terminal command mode"
    ll "----------------------------------------"

    #
    # No interactive keyboard input is required in automatic mode.
    #
    send_hex "$FILE"

    #
    # Return directly to Linux.
    #
    ll "Automatic transfer completed. Now leaving SCMTERM."
}

#
# Automatically transfer and execute an Intel HEX file at the device, then
# monitor the output returned from SCM and wait for the SCM prompt before
# exiting.
#
# Important: there is no universal way for SCMTERM to identify that an
# arbitrary Z80 program has finished at the device. If the program running at
# the Z80 never returns to SCM, there is nothing in the serial stream that
# intrinsically says "finished". For the present purpose, returning to SCM
# and producing its '*' prompt is here considered as a reasonable convention.
#
# In the automatic execution mode, the order of things is as follows:
#     1. If the HEX contains an Intel HEX start
#        address record, then use that.
#     2. Otherwise, use the lowest data address as the execution address.
#     3. Send the HEX file over to the device over the serial interface
#        (UART), just as we would in command mode (Ctrl-T) when running
#        SCMTERM interactively.
#     4. Send G<address>\r to SCM to let SCM initiate the execution of the
#        program, starting at the identified execution <address>.
#     5. Continue displaying the output returned by SCM over the UART.
#     6. Regard the return of the SCM '*' prompt as "program finished".
#     7. We meanwhile use a timeout (default 30 s) so that an accidentally
#        infinite program cannot leave SCMTERM hanging forever.
#     8. Exit clean from SCMTERM.
#
# The automatic execution sequence is as follows:
#
#        Linux
#          │
#          ├── open /dev/ttyUSB0
#          │
#          ├── analyse file.hex
#          │       │
#          │       └── execution address = 9000H
#          │
#          ├── enter automatic transfer mode
#          │
#          ├── send file.hex
#          │
#          ├── wait for transfer to finish
#          │
#          ├── send G9000<CR>
#          │
#          ├── display program output
#          │
#          ├── detect SCM '*'
#          │
#          ├── "Program returned to SCM."
#          │
#          └── exit SCMTERM and return to Linux shell
#
automatic_run() {
    local FILE="$AUTO_RUN"
    local ADDRESS
    local START_HEX

    if [[ -z "$FILE" ]]
    then
        echo "No Intel HEX file specified for automatic run."
        return 1
    fi

    if [[ ! -f "$FILE" ]]
    then
        echo "Intel HEX file not found: $FILE"
        return 1
    fi

    #
    # Analyse the HEX file first.
    #
    analyse_hex "$FILE"
    if (( HEX_START_ADDRESS < 0 ))
    then
        echo "Cannot determine execution address."
        return 1
    fi

    ADDRESS=$HEX_START_ADDRESS
    START_HEX=$(printf "%04X" "$ADDRESS")
    ll "----------------------------------------------------------"
    ll "Automatic run mode for Intel HEX file as source"
    ll "----------------------------------------------------------"
    ll "File               : $FILE"
    printf -v TMPLINE "Execution address : %sH\n" "$START_HEX"
    ll "$TMPLINE"

    #
    # Transfer the program.
    #
    send_hex "$FILE"

    #
    # Give SCM a short time to process the final HEX record.
    #
    sleep 0.20

    #
    # Send the SCM G command.
    #
    echo
    printf -v TMPLINE "Starting program at %sH...\n" "$START_HEX"
    ll "$TMPLINE"
    printf -v TMPLINE "G%s\r" "$START_HEX"
    ll "$TMPLINE"
    printf "G%s\r" "$START_HEX" >&3

    if (( LOGGING ))
    then
        printf ">> G%s <ENTER>\n" "$START_HEX" >> "$LOGFILE"
    fi

    #
    # Now wait for the SCM prompt.
    #
    wait_for_scm_prompt
}

#
# Wait for the SCM prompt '*' indicating that the executed program has
# returned to SCM.
#
wait_for_scm_prompt() {
    local ELAPSED=0

    echo "Waiting for program to return to SCM..."

    while (( ELAPSED < RUN_TIMEOUT ))
    do

        if [[ -f "$RUN_DONE_FILE" ]]
        then
            echo
            echo "Program returned to SCM."
            echo "SCM prompt detected."
            return 0
        fi

        sleep 0.1
        ELAPSED=$((ELAPSED + 1))

    done

    echo
    echo "Execution timeout."
    echo "The program did not return to SCM within ${RUN_TIMEOUT} seconds."

    return 1
}

#
# Enter the main keyboard loop of SCMTERM.
#
main_loop() {
    LOGMODE="$COMMODE"
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
while getopts ":d:b:p:s:l:t:r:fh" opt; do
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
        t)
	    #
	    # Automatic transfer mode (Intel HEX file)
	    #
            AUTO_TRANSFER="$OPTARG"
            ;;
        r)
	    #
	    # Automatic execution mode (Intel HEX file)
	    #
            AUTO_RUN="$OPTARG"
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

#
# Launch the exectution in one of three distinct modes: Automatic execution,
# automatic transfer, and regular interactive mode.
#
if [[ -n "$AUTO_RUN" ]]
then

    #
    # Automatic transfer and execution mode.
    #
    automatic_run

elif [[ -n "$AUTO_TRANSFER" ]]
then

    #
    # Automatic transfer mode. (No execution.)
    #
    automatic_transfer

else

    #
    # Interactive mode. Enter command mode by Ctrl-T when in the loop.
    #
    main_loop

fi
