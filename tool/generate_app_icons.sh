#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
master="$root/assets/branding/ownyute_logo.svg"
foreground_css="$root/assets/branding/adaptive_foreground.css"
android_res="$root/android/app/src/main/res"

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "rsvg-convert is required (install librsvg2-bin)." >&2
  exit 1
fi

render() {
  local size="$1"
  local output="$2"
  mkdir -p "$(dirname "$output")"
  rsvg-convert --width "$size" --height "$size" "$master" --output "$output"
}

render_foreground() {
  local size="$1"
  local output="$2"
  mkdir -p "$(dirname "$output")"
  rsvg-convert --stylesheet "$foreground_css" \
    --width "$size" --height "$size" "$master" --output "$output"
}

# A high-resolution raster master is useful for stores and packaging systems.
render 1024 "$root/assets/branding/ownyute_logo.png"

densities=(mdpi hdpi xhdpi xxhdpi xxxhdpi)
legacy_sizes=(48 72 96 144 192)
adaptive_sizes=(108 162 216 324 432)

for index in "${!densities[@]}"; do
  density="${densities[$index]}"
  directory="$android_res/mipmap-$density"
  render "${legacy_sizes[$index]}" "$directory/ic_launcher.png"
  cp "$directory/ic_launcher.png" "$directory/ic_launcher_round.png"
  render_foreground "${adaptive_sizes[$index]}" \
    "$directory/ic_launcher_foreground.png"
done

# GTK uses this copy for the running window. The scalable master is separately
# installed into the standard hicolor icon theme by linux/CMakeLists.txt.
render 512 "$root/linux/runner/resources/ownyute_logo.png"

echo "Generated OwnYute Android and Linux icons."
