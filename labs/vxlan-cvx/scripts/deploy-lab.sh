#!/bin/bash

# Usage: ./deploy-lab.sh lab1-completed

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <lab-name> (e.g., lab1-completed)"
  exit 1
fi

lab_name="$1"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$script_dir/.."
topo_src="$base_dir/vxlan-cvx.clab.yaml"
topo_tmp="$base_dir/vxlan-cvx.clab.${lab_name}.yaml"

echo "⚙️  Creating temporary topology file: $topo_tmp"

cat "$topo_src" | \
  yq -r ".topology.nodes |= with_entries(.value[\"startup-config\"] = \"configs/\" + .key + \"/${lab_name}.cfg\") | ." \
  > "$topo_tmp"

echo "🚀 Deploying lab using: $topo_tmp"
containerlab deploy -t "$topo_tmp"
