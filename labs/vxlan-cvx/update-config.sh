#!/bin/bash

nodes=(leaf1 leaf2 leaf3 leaf4 leaf5 spine1 spine2 cvx1 cvx2 cvx3 host-a host-b host-c host-d)

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src_base="$script_dir/clab-vxlan-cvx"
dst_base="$script_dir/configs"

for node in "${nodes[@]}"; do
  src="$src_base/$node/flash/startup-config"
  dst_dir="$dst_base/$node"
  dst="$dst_dir/startup-config"

  mkdir -p "$dst_dir"

  if [[ -f "$src" ]]; then
    if cp "$src" "$dst"; then
      echo "Copied $src to $dst"
    else
      echo "Error: Failed to copy $src to $dst"
    fi
  else
    echo "Warning: Source config not found for $node at $src"
  fi
done
