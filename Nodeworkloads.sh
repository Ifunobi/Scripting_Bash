#!/bin/bash

# This script counts and outputs the number of pods and containers per node in a kubernetes cluster and writes a CSV formatted output.

# Error exit function
errorExit () {
    echo -e "\nERROR: $1\n"
    exit 1
}

# Check if jq is installed, and install if necessary
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Attempting to install..."

    # Detect the package manager and install jq
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y jq || errorExit "Failed to install jq using apt"
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq || errorExit "Failed to install jq using yum"
    else
        errorExit "Unsupported package manager. Please install jq manually."
    fi
fi

# Test connection to cluster
kubectl cluster-info > /dev/null || errorExit "Connection to cluster failed"

# Get all nodes and pod data in one call for efficiency
nodes=$(kubectl get nodes -o jsonpath="{.items[*].metadata.name}") || errorExit "Failed to get node information"
pod_data=$(kubectl get pods -A -o json) || errorExit "Failed to get pod information"

# Define the output file
output_file="output.csv"

# Write the CSV header to the file
echo "Node,Pods count,Containers count" > "${output_file}"

# Loop over the nodes
for node in ${nodes}; do
    # Count the number of pods on this node
    pod_count=$(echo "${pod_data}" | jq --arg NODE "${node}" '[.items[] | select(.spec.nodeName == $NODE)] | length') || errorExit "Failed to count pods on node ${node}"

    # Count the number of containers on this node
    container_count=$(echo "${pod_data}" | jq --arg NODE "${node}" '[.items[] | select(.spec.nodeName == $NODE) | .spec.containers[]] | length') || errorExit "Failed to count containers on node ${node}"

    # Append node, pod count, and container count to the output file
    echo "${node},${pod_count},${container_count}" >> "${output_file}"
done

echo "Output saved to ${output_file}"
