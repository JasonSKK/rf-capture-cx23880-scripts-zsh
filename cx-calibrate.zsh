# MUST BE SOURCED
[[ "${ZSH_EVAL_CONTEXT}" != *:file ]] && {
    print "ERROR: source this script, do not execute it"
    return 1
}

set -u

print -n "Is the Video8 player producing valid RF? Press Enter to continue: "
read

# Defaults
VMUX="${1:-1}"
LEVEL_INIT="${2:-0}"

print "Selected vmux=$VMUX initial_level=$LEVEL_INIT"

# Apply base configuration
echo "$VMUX"        | sudo tee /sys/class/cxadc/cxadc0/device/parameters/vmux > /dev/null
echo "$LEVEL_INIT"  | sudo tee /sys/class/cxadc/cxadc0/device/parameters/level > /dev/null
echo 0              | sudo tee /sys/class/cxadc/cxadc0/device/parameters/sixdb > /dev/null

# Run leveladj and capture output
LEVELADJ_OUT="$(sudo /home/iason1/.local/bin/leveladj | tee /dev/stderr)"

# Extract last tested level
SUGGESTED_LEVEL="$(print -r -- "$LEVELADJ_OUT" \
  | grep -Eo 'testing level [0-9]+' \
  | tail -n1 \
  | awk '{print $3}')"

if [[ -z "$SUGGESTED_LEVEL" ]]; then
  print "ERROR: could not parse leveladj output"
  return 1
fi

FINAL_LEVEL=$(( SUGGESTED_LEVEL - 1 ))
(( FINAL_LEVEL < 0 )) && FINAL_LEVEL=0

print "leveladj suggested=$SUGGESTED_LEVEL → applying=$FINAL_LEVEL"

echo "$FINAL_LEVEL" | sudo tee /sys/class/cxadc/cxadc0/device/parameters/level > /dev/null

# Export for current shell use
export CXADC_VMUX="$VMUX"
export CXADC_LEVEL="$FINAL_LEVEL"

print "Calibration complete"
print "CXADC_VMUX=$CXADC_VMUX"
print "CXADC_LEVEL=$CXADC_LEVEL"

echo "Preview RF signal with ffplay ..."

ffplay -hide_banner -async 1 -f rawvideo -pixel_format gray8 -video_size 1832x625 -i /dev/cxadc0 -vf scale=1135x625,eq=gamma=0.5:contrast=1.5


# old version
# #!/bin/bash
# set -euo pipefail

# printf "%s " "Is the video8 player producing an RF signal valid for calibration? If yes press enter to continue:"
# read ans

# # Defaults
# VMUX_DEFAULT=1
# LEVEL_DEFAULT=0

# VMUX="${1:-$VMUX_DEFAULT}"
# LEVEL="${2:-$LEVEL_DEFAULT}"

# echo "Selected vmux=$VMUX level=$LEVEL"

# # Show current parameters
# ls /dev | grep cxadc | sed -e 's/dev//g' | xargs -I % bash -c '
#     find /sys/class/cxadc/%/device/parameters | grep -v parameters$' \
#         | xargs -I % bash -c 'echo -n "% " && cat %'

# # Apply configuration using tee to avoid redirection issues under sudo
# echo "$VMUX"  | sudo tee /sys/class/cxadc/cxadc0/device/parameters/vmux
# echo "$LEVEL" | sudo tee /sys/class/cxadc/cxadc0/device/parameters/level
# echo 0        | sudo tee /sys/class/cxadc/cxadc0/device/parameters/sixdb

# # Adjust gain interactively
# /home/iason1/.local/bin/leveladj

# # Live view
# ffplay -hide_banner -async 1 \
#      -f rawvideo -pixel_format gray8 -video_size 1832x625 \
#      -i /dev/cxadc0 \
#      -vf scale=1135x625,eq=gamma=0.5:contrast=1.5
