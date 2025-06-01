#!/bin/bash
#
# Headphones/Speakers Auto-Switch Fix Script v4.1
# Author: captainerd (github.com/captainerd/linux-front-audio-fix)
# Maintainer: natsos@velecron.net
#
# Purpose:
#   - Auto-detects headphones and line-out ports.
#   - Creates virtual sinks and mirror loopbacks.
#   - Switches audio based on default sink changes.
#   - Designed for desktops/laptops with broken jack sensing.

VIRTUAL_SINK="headphones_fix"
REAL_SINK=""
HEADPHONES_PORT=""
LINEOUT_PORT=""
SPEAKER_PORT=""

notify_fail() {
  DISPLAY=:0 notify-send -u critical "Headphones Fix Script Error" "$1"
}

get_ports() {
 eval "$(
    pactl list sinks | awk '
    BEGIN { RS = "Sink #"; FS="\n" }

    /pci/ {
      sink_name = "";
      HEADPHONES_PORT = "";
      LINEOUT_PORT = "";
      SPEAKER_PORT = "";

      for (i = 1; i <= NF; i++) {
        if ($i ~ /Name:/) {
          split($i, a, " ");
          sink_name = a[2];
        }
        # Headphones port (always assign)
        if ($i ~ /-headphones:/) {
          match($i, /^[[:space:]]*[^:]*-headphones:/);
          if (RSTART) {
            split($i, p, ":");
            gsub(/^[ \t]+/, "", p[1]);
            HEADPHONES_PORT = p[1];
          }
        }
        # Lineout port, check availability
        if ($i ~ /-lineout:/) {
          if ($i !~ /not available/) {
            match($i, /^[[:space:]]*[^:]*-lineout:/);
            if (RSTART) {
              split($i, p, ":");
              gsub(/^[ \t]+/, "", p[1]);
              LINEOUT_PORT = p[1];
            }
          }
        }
        # Speaker port, check availability
        if ($i ~ /-speaker:/) {
          if ($i !~ /not available/) {
            match($i, /^[[:space:]]*[^:]*-speaker:/);
            if (RSTART) {
              split($i, p, ":");
              gsub(/^[ \t]+/, "", p[1]);
              SPEAKER_PORT = p[1];
            }
          }
        }
      }

      if (sink_name && HEADPHONES_PORT) {
        printf "REAL_SINK=\"%s\"\n", sink_name;
        printf "HEADPHONES_PORT=\"%s\"\n", HEADPHONES_PORT;
        printf "LINEOUT_PORT=\"%s\"\n", LINEOUT_PORT;
        printf "SPEAKER_PORT=\"%s\"\n", SPEAKER_PORT;
        exit;
      }
    }
    '
  )"

 if [[ -z "$REAL_SINK" || ( -z "$HEADPHONES_PORT" && -z "$LINEOUT_PORT" && -z "$SPEAKER_PORT" ) ]]; then
  msg="Required ports not detected:
  Real sink: ${REAL_SINK:-not found}
  Headphones port: ${HEADPHONES_PORT:-not found}
  Line-out port: ${LINEOUT_PORT:-not found}
  Speaker port: ${SPEAKER_PORT:-not found}"
  notify_fail "$msg"
  exit 1
fi
}

switch_audio() {
  local mode="$1"
  local target_sink=""

    

  if [[ "$mode" == "headphones" ]]; then

    amixer set Headphone 100% unmute
      pactl set-sink-volume "$REAL_SINK" 100%
    pactl set-sink-port "$REAL_SINK" "$HEADPHONES_PORT"
      pactl set-default-sink "$REAL_SINK"
            for input in $(pactl list short sink-inputs | awk '{print $1}'); do
    pactl move-sink-input "$input" "$REAL_SINK"
done

elif [[ "$mode" == "lineout" ]]; then
    pactl set-sink-port "$REAL_SINK" "$LINEOUT_PORT"
     pactl set-default-sink "$REAL_SINK"
                 for input in $(pactl list short sink-inputs | awk '{print $1}'); do
    pactl move-sink-input "$input" "$REAL_SINK"
done
  else
    echo "Unknown mode: $mode"
    return 1
  fi


  


  amixer set Master unmute
  pactl set-sink-mute "$REAL_SINK" false

   
}


 

start_service() {
  echo "Cleaning old modules..."
   
  stop_service
  
  get_ports

  echo "Creating virtual sinks..."
  pactl load-module module-null-sink  sink_name="uplug_headphones"   sink_properties="'device.description=\"LineOut - Speakers\" device.class=\"sound\"'"
  pactl load-module module-null-sink  sink_name="$VIRTUAL_SINK"   sink_properties="'device.description=\"HeadPhones / Fix\" device.class=\"sound\"'"
 
 current_default=$(pactl info | awk -F": " '/Default Sink/ {print $2}')
  echo "Current default sink: $current_default"

 
  echo "Listening for default sink changes..."
  pactl subscribe | while read -r event; do
    if echo "$event" | grep -q "Event 'change' on server"; then
      current_default=$(pactl info | awk -F': ' '/Default Sink/ {print $2}')
      echo "Default sink changed to $current_default"

      if [[ "$current_default" == "$VIRTUAL_SINK" ]]; then
        switch_audio headphones
      elif [[ "$current_default" == "uplug_headphones" ]]; then
        switch_audio lineout
      fi
    fi
  done


  
}

stop_service() {
  echo "Stopping and cleaning modules..."

for module_id in $(pactl list short modules | grep module-null-sink | grep -E "$VIRTUAL_SINK|uplug_headphones" | awk '{print $1}'); do
    pactl unload-module "$module_id"
done

}

case "$1" in
  --stop)
    stop_service
    ;;
  *)
    start_service
    ;;
esac
