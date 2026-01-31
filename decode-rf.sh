#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  # print "Usage: cd path/to/rf_capture.flac, $0 <rf_capture.flac>"
  return 1 2>/dev/null || exit 1
fi

# print -n "Is there > 380GB available space on the drive ? If yes press Enter to continue"
# read

# print -n "all read/writes should happen in the same disk the OS uses, otherwise there is timebase droppout risk"
# read

RF="$1"
# os ssd needs to be used
OS_PATH="/home/iason1/temp/test-capture"

RF_BASENAME="$(basename -- "$RF")"
STEM="${RF_BASENAME%.flac}"          # remove one .flac suffix if present

OUT_BASE="${OS_PATH}/${STEM}"        # base path for vhs-decode outputs
HIFI_BASE="${OS_PATH}/hifi_audio_${STEM}"   # base name for hifi-decode outputs (no .flac)
ALIGNED_FLAC="${OS_PATH}/aligned_hifi_audio_${STEM}.flac"

[[ -f "$RF" ]] || { echo "RF not found: $RF" >&2; exit 1; }
[[ -w "$OS_PATH" ]] || { echo "OS_PATH not writable: $OS_PATH" >&2; exit 1; }

# -------------------------------------------------------------------
# 1. VIDEO DECODE --> FAST
# --use_saved_levels avoids redoing level detection when you rerun.
# --no_resample saves time (quality tradeoff depends on capture).
# --level_detect_divisor is a known speed and behavior lever.
# Drop --recheck_phase unless you have a specific reason. It is extra wor
# -------------------------------------------------------------------
# vhs-decode --tape_format video8 --frequency 40 --system pal --no_resample --use_saved_levels --level_detect_divisor 6 --ire0_adjust "$RF" "$OUT_BASE"
vhs-decode --debug --tape_format video8 --frequency 40 --system pal --ire0_adjust --recheck_phase --recheck_phase "$RF" "$OUT_BASE"

# old
# vhs-decode --debug --tape_format video8 --frequency 40 --system pal --ire0_adjust --recheck_phase "$RF" "$OUT_PATH"

# -------------------------------------------------------------------
# 2. HIFI AUDIO DECODE (hard timeout: 3 hours = 10800 s)
# -------------------------------------------------------------------
# hifi-decode -p -f 40 --audio_rate 48000 --8mm "$OUT_PATH.flac" "hifi_audio_$OUT_PATH.flac"
# hifi-decode does not return --> timeout is used

TIMEOUT_SEC=10800

set +e
timeout --signal=TERM --kill-after=30s "${TIMEOUT_SEC}s" hifi-decode -p -f 40 --audio_rate 48000 --8mm "$RF" "$HIFI_BASE.flac"
rc=$?
set -e

case "$rc" in
    0)   echo "hifi-decode finished normally" ;;
    124) echo "hifi-decode timed out (expected)" ;;
    137) echo "hifi-decode killed (SIGKILL)" ;;
    *)   echo "hifi-decode failed with exit code $rc" >&2; exit "$rc" ;;
esac


# -------------------------------------------------------------------
# 3. AUDIO ALIGN
# -------------------------------------------------------------------
ffmpeg -hide_banner -loglevel error -i "${HIFI_BASE}.flac" -af "pan=mono|c0=FL" -f s24le -ac 1 - | mono ~/bin/vhs-decode-auto-audio-align_1.0.0/VhsDecodeAutoAudioAlign.exe stream-align --sample-size-bytes 3 --stream-sample-rate-hz 48000 --json "$OUT_BASE.tbc.json" --rf-video-sample-rate-hz 40000000 | ffmpeg -hide_banner -loglevel error -fflags +bitexact -f s24le -ar 48000 -ac 1 -i - -sample_fmt s32 "$ALIGNED_FLAC"

# -------------------------------------------------------------------
# 4. VIDEO + AUDIO EXPORT
# -------------------------------------------------------------------
# ~60GB / 1 hour
tbc-video-export --audio-track "$ALIGNED_FLAC" "${OUT_BASE}.tbc"

echo
echo "Workflow finished. Press Enter to exit."
read -r
