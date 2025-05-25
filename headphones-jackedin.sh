#!/bin/bash
set -e

VIRTUAL_SINK="fake_headphones"
HEADPHONES_PORT="analog-output-headphones"

start_service() {
  echo "Cleaning up old modules before start..."
  stop_service  # Clean leftovers before new start

  echo "Starting headphones-jackedin service..."

  REAL_SINK=$(pactl list short sinks | grep 'alsa_output.*analog-stereo' | head -n1 | awk '{print $2}')
  if [[ -z "$REAL_SINK" ]]; then
    echo "No analog-stereo sink found!"
    exit 1
  fi

  echo "Using real sink: $REAL_SINK"

  # Create virtual sink
  pactl load-module module-null-sink sink_name="$VIRTUAL_SINK" sink_properties="device.description='Headphones',device.icon_name=audio-headphones"
  pactl load-module module-loopback source="${VIRTUAL_SINK}.monitor" sink="$REAL_SINK"

  echo "Virtual sink '$VIRTUAL_SINK' created."

  # Function to get default sink
  get_default_sink() {
    pactl info | awk -F': ' '/Default Sink/ {print $2}'
  }
get_headphones_port() {
  pactl list sinks | grep -A20 "Name: $REAL_SINK" | grep "Ports:" -A5 | grep "headphones" | awk -F': ' '/^[[:space:]]+[a-z0-9-]+:/ {print $1; exit}'
}
  # Switch real sink to headphones port
switch_real_sink_to_headphones() {
  echo "Switching onboard sink '$REAL_SINK' port to headphones..."
  pactl set-sink-port "$REAL_SINK" "$HEADPHONES_PORT"

  echo "Moving all streams to onboard sink $REAL_SINK..."
  sink_inputs=$(pactl list short sink-inputs | awk '{print $1}')
  for input in $sink_inputs; do
    pactl move-sink-input "$input" "$REAL_SINK"
  done

  echo "Keeping virtual sink ($VIRTUAL_SINK) as default to avoid UI confusion"
  pactl set-default-sink "$VIRTUAL_SINK"
}

  last_default=""
  echo "Listening for default sink changes..."
 
pactl subscribe | while read -r event; do
  if echo "$event" | grep -q "Event 'change' on server"; then
    current_default=$(get_default_sink)
    if [[ "$current_default" != "$last_default" ]]; then
      echo "Default sink changed to $current_default"
      last_default="$current_default"

      # Only act if the virtual sink was selected
      if [[ "$current_default" == "$VIRTUAL_SINK" ]]; then
        switch_real_sink_to_headphones
      fi
      # Do nothing otherwise: allow switch to BT, HDMI, etc.
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
  for module_id in $(pactl list short modules | grep "module-null-sink" | grep "sink_name=$VIRTUAL_SINK" | awk '{print $1}'); do
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
