#!/bin/bash
#
# Headphones/Speakers Auto-Switch Fix Script v4
# Author: captainerd (github.com/captainerd/linux-front-audio-fix)
# Email: natsos@velecron.net
#
# Purpose:
#   This script provides a workaround for desktops/laptops where the 3.5mm front panel 
#   jack does not correctly trigger automatic port switching between speakers and headphones.
#   Common causes: broken fsense pin on motherboard, bad case wiring, or incorrect layout support.
#
# How it works:
#   - Creates a virtual sink ("Headphones / Fix") that always outputs to the real sink.
#   - Listens for default sink changes.
#   - Redirects audio appropriately based on user-set sinks.
#   - Includes a virtual "Speakers" option to restore automatic switching.
#


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
  pactl load-module module-virtual-sink sink_name="uplug_headphones" sink_properties="'device.description=\"Speakers\" device.class=\"sound\"   device.subsystem=\"sound\"   alsa.id=\"speakers-fix\" device.name=\"${VIRTUAL_SINK}\"     audio.channels=\"2\" audio.position=\"FL,FR\"   device.nick=\"speakers\" device.icon_name=\"audio-speakers\"'"
 
  pactl load-module module-null-sink sink_name="$VIRTUAL_SINK" sink_properties="'device.description=\"HeadPhones / Fix\" device.class=\"sound\"   device.subsystem=\"sound\"   alsa.id=\"HeadPhones-fix\" device.name=\"${VIRTUAL_SINK}\"     audio.channels=\"2\" audio.position=\"FL,FR\"   device.nick=\"headphones\" device.icon_name=\"audio-headphones\"'"
  pactl load-module module-loopback source="${VIRTUAL_SINK}.monitor" sink="$REAL_SINK"

  echo "Virtual sink '$VIRTUAL_SINK' created."

  # Switch real sink to headphones port
  switch_real_sink_to_headphones() {
 

    echo "Switching onboard sink '$REAL_SINK' port to headphones..."
    echo  " ---> set-sink-port $REAL_SINK $HEADPHONES_PORT"
    pactl set-sink-port "$REAL_SINK" "$HEADPHONES_PORT"
    pactl set-sink-volume "$REAL_SINK" 100%
    # "Keeping virtual sink ($VIRTUAL_SINK) as default to avoid UI confusion"
    pactl set-default-sink "$VIRTUAL_SINK"
    amixer set Master 100% unmute
    amixer set Headphone 100% unmute
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
       if [[ "$current_default" == "uplug_headphones" ]]; then
        pactl unload-module module-switch-on-port-available 2>/dev/null
        sleep 0.2
        pactl load-module module-switch-on-port-available
           pactl set-default-sink "$REAL_SINK"
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

  # Unload null sink (headphones_fix)
  for module_id in $(pactl list short modules | grep "module-null-sink" | grep "sink_name=$VIRTUAL_SINK" | awk '{print $1}'); do
    echo "Unloading null sink module: $module_id"
    pactl unload-module "$module_id"
  done

  # Unload virtual sink (uplug_headphones)
  for module_id in $(pactl list short modules | grep "module-virtual-sink" | grep "sink_name=uplug_headphones" | awk '{print $1}'); do
    echo "Unloading virtual sink module (uplug_headphones): $module_id"
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
