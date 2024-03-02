#!/bin/bash

# remote_nodes=("109" "167" "103" "093" "177" "176" "107" "166")
# remote_nodes=("093" "177" "176" "107" "166")
remote_nodes=("109" "167" "103")
PASSLESS_ENTRY="/users/JiyuHu23/.ssh/dassl_rsa"
SSH_USER="JiyuHu23"

# Check if the local script path is provided as a command line argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 <local_script_path>"
    exit 1
fi

local_script="$1"

# Iterate over remote nodes and execute the script
for node in "${remote_nodes[@]}"; do
    echo "Executing script on $node..."
    ssh -i ${PASSLESS_ENTRY} "${SSH_USER}@hp$node.utah.cloudlab.us" "sudo bash -s" < "$local_script"
    echo "Script execution on $node completed."
done