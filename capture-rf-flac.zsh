#!/usr/bin zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
    print "Usage: $0 /path/to/output.flac"
    print "Timeouts after 1.5 hours"
    return 1 2>/dev/null || exit 1
fi

OUT="$1"

# 1.5 hours = 5400 seconds
# Pin capture to one core
timeout 5400 taskset -c 2  cat /dev/cxadc0 | flac --fast -16 --sample-rate=40000 --sign=unsigned --channels=1 --endian=little --bps=8 --blocksize=65535 --lax -f - -o "$OUT"
