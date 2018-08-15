#!/bin/bash

# Utility function to fetch metadata
function getMetadata()
{
    local usage="  USAGE: getMetadata zone"
    local query="${1?$usage}"

    curl \
        -H "Metadata-Flavor: Google" \
        "http://metadata.google.internal/computeMetadata/v1/instance/${query}" 2>/dev/null
}

# Wait around for a few seconds to make sure have enough time to time performance
sleep 2

# Delete current VM
tName=$(getMetadata "name")
tZone=$(getMetadata "zone")
gcloud compute instances delete --quiet "${tName}" --zone "${tZone}"
