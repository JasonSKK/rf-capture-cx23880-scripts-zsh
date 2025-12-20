# zsh
#!/usr/bin/env zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
  print "Usage: $0 <rf_capture.flac>"
  return 1 2>/dev/null || exit 1
fi

print -n "Is there > 380GB available space on the drive ? If yes press Enter to continue"
read

RF="$1"
BASENAME="${RF:r}"

# -------------------------------------------------------------------
# 1. VIDEO DECODE
# -------------------------------------------------------------------
vhs-decode --debug --tape_format video8 --frequency 40 --system pal --ire0_adjust --recheck_phase --recheck_phase "$RF" "$BASENAME"

# -------------------------------------------------------------------
# 2. HIFI AUDIO DECODE (hard timeout: 3 hours = 10800 s)
# -------------------------------------------------------------------
timeout 10800 hifi-decode -t 8 -p -f 40 --audio_rate 48000 --8mm "$BASENAME.flac" "hifi_audio_$BASENAME.flac" || true
# hifi-decode does not return --> timeout is used

# -------------------------------------------------------------------
# 3. VBI PROCESSING (for dates / teletext overlays)
# -------------------------------------------------------------------
ld-process-vbi "$BASENAME.tbc"

# -------------------------------------------------------------------
# 4. AUDIO ALIGN
# -------------------------------------------------------------------
ffmpeg -hide_banner -loglevel error -i "hifi_audio_$BASENAME.flac" -af "pan=mono|c0=FL" -f s24le -ac 1 - | mono ~/bin/vhs-decode-auto-audio-align_1.0.0/VhsDecodeAutoAudioAlign.exe stream-align --sample-size-bytes 3 --stream-sample-rate-hz 48000 --json "$BASENAME.tbc.json" --rf-video-sample-rate-hz 40000000 | ffmpeg -hide_banner -loglevel error -fflags +bitexact -f s24le -ar 48000 -ac 1 -i - -sample_fmt s32 "aligned_hifi_audio_$BASENAME.flac"

# -------------------------------------------------------------------
# 5. VIDEO + AUDIO EXPORT
# -------------------------------------------------------------------
# ~60GB / 1 hour
tbc-video-export --audio-track "aligned_hifi_audio_$BASENAME.flac" "$BASENAME.tbc"
