#!/bin/zsh

# Usage: ./capture-rf-vhs-flac.sh output_base_name

if [[ $# -ne 2 ]]; then
    print "Usage: $0 /path/to/output.flac <tape_length_minutes>"
    print "Example: $0 capture.flac 90"
    print "Timeout equals tape length in minutes."
    exit 1
fi

BASE="$1"
VID_OUT="${BASE}.flac"
AUD_OUT="${BASE}.wav"

TAPE_LENGTH_MIN="$2"

# Basic numeric validation
if [[ ! "$TAPE_LENGTH_MIN" =~ '^[0-9]+$' ]]; then
    print "Error: tape_length_minutes must be an integer number of minutes."
    exit 1
fi

TIMEOUT_LENGTH=$(( TAPE_LENGTH_MIN * 60 ))
print "Timeout: ${TIMEOUT_LENGTH}s"

# Find the EDIROL UA-5 card index
CARD_INDEX=$(arecord -l | grep -B1 "UA-5" | grep card | awk -F ':' '{print $1}' | awk '{print $2}')

if [ -z "$CARD_INDEX" ]; then
    echo "EDIROL UA-5 not found."
    exit 1
fi

echo "Using ALSA card index: $CARD_INDEX"
echo "Recording to: $VID_OUT and $AUD_OUT"
echo "⚠️ UA-5 hardware gain must be adjusted manually on the unit."

# Start video capture
timeout "${TIMEOUT_LENGTH}" cat /dev/cxadc0 | flac --compression-level-6 --threads=8 -16 --sample-rate=40000 --sign=unsigned --channels=1 --endian=little --bps=8 --blocksize=65535 --lax -f - -o "$VID_OUT" &
VID_PID=$!

# Start audio capture: record mono and duplicate to stereo
timeout "${TIMEOUT_LENGTH}" arecord -D plughw:$CARD_INDEX,0 -f S16_LE -r 48000 -c 1 | sox -t wav - -c 2 "$AUD_OUT" remix 1 1 &
AUD_PID=$!

# Trap SIGINT to kill both processes cleanly
trap "echo; echo 'Stopping capture...'; kill $VID_PID $AUD_PID" SIGINT
wait

# decode
# vhs-decode --debug --tape_format vhs --frequency 40 --system pal --ire0_adjust --recheck_phase --threads 4 --recheck_phase
