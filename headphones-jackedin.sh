#!/bin/bash

VIRTUAL_SINK="headphones_fix"
REAL_SINK=""
HEADPHONES_PORT=""
start_service() {
  echo "Cleaning up old modules before start..."
  stop_service

  echo "Starting headphones-jackedin service..."

  # Function to get default sink
  get_default_sink() {
    pactl info | awk -F': ' '/Default Sink/ {print $2}'
  }

  eval "$(
    pactl list sinks | awk '
    BEGIN { RS = "Sink #"; FS="\n" }

    /pci/ && /-headphones:/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /Name:/) {
          split($i, a, " ");
          sink_name = a[2];
        }
        if ($i ~ /-headphones:/) {
          match($i, /^[[:space:]]*[^:]*-headphones:/);
          if (RSTART) {
            split($i, p, ":");
            gsub(/^[ \t]+/, "", p[1]); # trim leading whitespace
            hp_port = p[1];
          }
        }
      }

      if (sink_name && hp_port) {
        printf "REAL_SINK=\"%s\"\n", sink_name;
        printf "HEADPHONES_PORT=\"%s\"\n", hp_port;
        exit;
      }
    }
  '
  )"

  if [[ -z "$REAL_SINK" ]]; then
    echo "No analog-stereo sink found!"
    exit 1
  fi
 
  echo "Using real sink: $REAL_SINK"

  # Create virtual sink
  pactl load-module module-virtual-sink sink_name="$VIRTUAL_SINK" sink_properties="'device.description=\"HeadPhones / Fix\" device.class=\"sound\"   device.subsystem=\"sound\"   alsa.id=\"HeadPhones-fix\" device.name=\"${VIRTUAL_SINK}\"     audio.channels=\"2\" audio.position=\"FL,FR\"   device.nick=\"headphones\" device.icon_name=\"audio-headphones\"'"
  pactl load-module module-loopback source="${VIRTUAL_SINK}.monitor" sink="$REAL_SINK"
  echo "Virtual sink '$VIRTUAL_SINK' created."

  # Switch real sink to headphones port
  switch_real_sink_to_headphones() {

    for input in $(pactl list short sink-inputs | awk '{print $1}'); do
      pactl move-sink-input "$input" "$REAL_SINK"
    done

    echo "Switching onboard sink '$REAL_SINK' port to headphones..."
    pactl set-sink-port "$REAL_SINK" "$HEADPHONES_PORT"
    pactl set-sink-volume "$REAL_SINK" 100%
    # "Keeping virtual sink ($VIRTUAL_SINK) as default to avoid UI confusion"
    pactl set-default-sink "$VIRTUAL_SINK"
    amixer set Master 100%

  }

  current_default=$(get_default_sink)
  if [[ "$current_default" == "$VIRTUAL_SINK" ]]; then
    switch_real_sink_to_headphones
  fi

  last_default=""
  echo "Listening for default sink changes..."

  pactl subscribe | while read -r event; do
    if echo "$event" | grep -q "Event 'change' on server"; then
      current_default=$(get_default_sink)

      echo "Default sink changed to $current_default"
      last_default="$current_default"

      if [[ "$current_default" == "$VIRTUAL_SINK" ]]; then
        switch_real_sink_to_headphones
      fi
    fi
  done
}

stop_service() {
  echo "Stopping headphones-jackedin service and cleaning up..."

  # Unload loopbacks feeding from virtual sink
  for module_id in $(pactl list short modules | grep "module-loopback" | grep "$VIRTUAL_SINK.monitor" | awk '{print $1}'); do
    echo "Unloading loopback module: $module_id"
    pactl unload-module "$module_id"
  done

  # Unload null sink if exists
  for module_id in $(pactl list short modules | grep "module-virtual-sink" | grep "sink_name=$VIRTUAL_SINK" | awk '{print $1}'); do
    echo "Unloading null sink module: $module_id"
    pactl unload-module "$module_id"
  done

  echo "Cleanup complete."
}

case "$1" in
--stop)
  stop_service
  ;;
*)
  start_service
  ;;
esac
