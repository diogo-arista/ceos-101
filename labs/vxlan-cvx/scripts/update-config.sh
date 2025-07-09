#!/bin/bash

set -euo pipefail

nodes=(leaf1 leaf2 leaf3 leaf4 leaf5 spine1 spine2 cvx1 cvx2 cvx3 host-a host-b host-c host-d)

# Get script location and base directories
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(dirname "$script_dir")"
default_src_base="$base_dir/clab-vxlan-cvx"
dst_base="$base_dir/configs"

# Usage
usage() {
  echo "Usage:"
  echo "  $0 --base"
  echo "  $0 --lab <lab_number> [--src <path_to_alt_clab_dir>]"
  exit 1
}

# Parse arguments
mode=""
lab_number=""
src_base="$default_src_base"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      mode="base"
      shift
      ;;
    --lab)
      mode="lab"
      lab_number="$2"
      shift 2
      ;;
    --src)
      src_base="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Validate
if [[ "$mode" == "" ]]; then
  usage
fi

if [[ "$mode" == "lab" && ! "$lab_number" =~ ^[0-9]+$ ]]; then
  echo "Error: Lab number must be a valid integer."
  usage
fi

# Expand relative --src to full path
src_base="$(realpath "$src_base")"

# Perform copy
for node in "${nodes[@]}"; do
  src="$src_base/$node/flash/startup-config"
  dst_dir="$dst_base/$node"

  mkdir -p "$dst_dir"

  if [[ ! -f "$src" ]]; then
    echo "Warning: Source config not found for $node at $src"
    continue
  fi

  if [[ "$mode" == "base" ]]; then
    dst="$dst_dir/startup-config"
  elif [[ "$mode" == "lab" ]]; then
    dst="$dst_dir/lab${lab_number}-completed.cfg"
  fi

  if cp "$src" "$dst"; then
    echo "Copied $src to $dst"
  else
    echo "Error: Failed to copy $src to $dst"
  fi
done
