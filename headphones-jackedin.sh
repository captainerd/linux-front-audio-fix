#!/bin/bash

VIRTUAL_SINK="fake_headphones"
HEADPHONES_PORT="analog-output-headphones"

# Auto-detect the real sink (first analog-stereo sink from ALSA)
REAL_SINK=$(pactl list short sinks | grep 'alsa_output.*analog-stereo' | head -n1 | awk '{print $2}')

if [[ -z "$REAL_SINK" ]]; then
  echo "❌ No analog-stereo sink found!"
  exit 1
fi

echo "🎯 Using real sink: $REAL_SINK"

# 🧹 Cleanup old virtual sinks and loopbacks
echo "🧽 Cleaning up old modules..."

# Unload loopbacks feeding from our virtual sink
for module_id in $(pactl list short modules | grep "module-loopback" | grep "$VIRTUAL_SINK.monitor" | awk '{print $1}'); do
  echo "🔻 Unloading old loopback module: $module_id"
  pactl unload-module "$module_id"
done

# Unload previous null sink if exists
for module_id in $(pactl list short modules | grep "module-null-sink" | grep "sink_name=$VIRTUAL_SINK" | awk '{print $1}'); do
  echo "🔻 Unloading old null-sink module: $module_id"
  pactl unload-module "$module_id"
done

# Create virtual sink with loopback
echo "🔧 Creating virtual sink and loopback..."

pactl load-module module-null-sink sink_name="$VIRTUAL_SINK" sink_properties="device.description='Headphones',device.icon_name=audio-headphones"
pactl load-module module-loopback source="${VIRTUAL_SINK}.monitor" sink="$REAL_SINK"

if [[ $? -eq 0 ]]; then
  echo "✅ Virtual sink '$VIRTUAL_SINK' created."
else
  echo "❌ Failed to create virtual sink."
  exit 1
fi

# 🔄 Functions
get_default_sink() {
  pactl info | awk -F': ' '/Default Sink/ {print $2}'
}

switch_real_sink_to_headphones() {
  echo "🎧 Switching real sink '$REAL_SINK' port to headphones..."
  pactl set-sink-port "$REAL_SINK" "$HEADPHONES_PORT"
  pactl set-default-sink "$REAL_SINK"
}

last_default=""

# 👂 Watch for default sink changes
pactl subscribe | while read -r event; do
  if echo "$event" | grep -q "Event 'change' on server"; then
    current_default=$(get_default_sink)
    if [[ "$current_default" != "$last_default" ]]; then
      echo "🔄 Default sink changed to $current_default"
      last_default="$current_default"
      if [[ "$current_default" == "$VIRTUAL_SINK" ]]; then
        switch_real_sink_to_headphones
      fi
    fi
  fi
done

