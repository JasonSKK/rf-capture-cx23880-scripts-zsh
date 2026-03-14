#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    print "Usage: $0 /path/to/output.flac <tape_length_minutes>"
    print "Example: $0 capture.flac 90"
    print "Timeout equals tape length in minutes."
    exit 1
fi

OUT="$1"
TAPE_LENGTH_MIN="$2"

# Basic numeric validation
if [[ ! "$TAPE_LENGTH_MIN" =~ '^[0-9]+$' ]]; then
    print "Error: tape_length_minutes must be an integer number of minutes."
    exit 1
fi

TIMEOUT_LENGTH=$(( TAPE_LENGTH_MIN * 60 ))
print "Timeout: ${TIMEOUT_LENGTH}s"

# 1.5 hours = 5400 seconds
timeout "${TIMEOUT_LENGTH}" cat /dev/cxadc0 | flac --compression-level-6 --threads=8 -16 --sample-rate=40000 --sign=unsigned --channels=1 --endian=little --bps=8 --blocksize=65535 --lax -f - -o "$OUT"

# OLD version, harry updated the flac commands 5462e62158de4764d7e11bffcc7c8169012fe2e6
# https://github.com/happycube/cxadc-linux3/wiki/FLAC-Compression-Guide#post-capture-flac-compression
# Pin capture to one core
# timeout "${TIMEOUT_LENGTH}" taskset -c 2 cat /dev/cxadc0 | flac --fast -16 --sample-rate=40000 --sign=unsigned --channels=1 --endian=little --bps=8 --blocksize=65535 --lax -f - -o "$OUT"
