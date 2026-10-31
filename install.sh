#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
plugin_id="io.github.mohiitp.essentials"
plugin_dir="$HOME/.config/omarchy/plugins/$plugin_id"
state_dir="$HOME/.local/state/omarchy"
state_file="$state_dir/$plugin_id.json"
legacy_state_file="$state_dir/information-holder.json"

mkdir -p "$plugin_dir" "$state_dir"
install -m 0644 "$script_dir/manifest.json" "$script_dir/BarWidget.qml" "$script_dir/Panel.qml" "$script_dir/icon.svg" "$plugin_dir/"

# Carry over data from the pre-marketplace install, if present.
if [[ ! -e $state_file && -e $legacy_state_file ]]; then
  mv "$legacy_state_file" "$state_file"
fi
if [[ ! -e $state_file ]]; then
  (umask 077 && printf '{\n  "version": 1,\n  "entries": []\n}\n' > "$state_file")
fi
chmod 600 "$state_file"

omarchy-shell shell rescanPlugins
omarchy plugin enable "$plugin_id"
omarchy bar put "$plugin_id" --section right
printf 'Essentials is installed. Click its new bar icon to add entries.\n'
