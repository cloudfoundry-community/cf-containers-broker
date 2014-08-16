#!/bin/sh

# Fetch Containers Images
echo "Fetching Containers Images..."
bin/fetch_container_images

# Start CF-Containers-Broker
echo "Starting CF-Containers-Broker..."
$@
