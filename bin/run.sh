#!/bin/bash

# Fetch Containers Images
if [[ "${SKIP_FETCHING_IMAGES:-X}" == "X" ]]; then
  echo "Fetching Containers Images..."
  bin/fetch_container_images
else
  echo "Skipping fetching container images."
fi

# Start CF-Containers-Broker
echo "Starting CF-Containers-Broker..."
$@
