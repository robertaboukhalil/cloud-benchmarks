#!/bin/bash

# ==============================================================================
# Launch benchmarks for VM boot times
# Currently only supports GCP
# ==============================================================================

# ------------------------------------------------------------------------------
# Config
# ------------------------------------------------------------------------------

# General
JQ=jq
JQ_NULL="null"
DIR_SETTINGS="${1?Usage: ./run.sh ./path/to/config.json}"


# ------------------------------------------------------------------------------
# Utility functions
# ------------------------------------------------------------------------------

# Check for and install dependencies
function init()
{
    # Install jq for parsing JSON
    jq --version > /dev/null 2>&1
    if [[ "$?" != "0" ]]; then
        read -rp "This tool needs the <jq> utility. Install it now? (y/n) " yesno
        [[ "$yesno" != "y" ]] && exit
        echo "Installing jq..."
        sudo apt-get install jq
    fi

    # Install uuidgen to generate UUIDs as VM names
    uuidgen > /dev/null 2>&1
    if [[ "$?" != "0" ]]; then
        read -rp "This tool needs the <uuidgen> utility. Install it now? (y/n) " yesno
        [[ "$yesno" != "y" ]] && exit
        echo "Installing uuidgen..."
        sudo apt-get install uuid-runtime
    fi
}

# Find out which environment we're in
function getEnv()
{
    ping -c 1 metadata.google.internal >/dev/null 2>/dev/null
    if [[ "$?" == "0" ]]; then
        echo "gcp"
    elif [[ "$(head -c 3 /sys/hypervisor/uuid 2>/dev/null)" == "ec2" ]]; then
        echo "aws"
    else
        echo ""
    fi
}

# Call jq on config file, and return compressed output
function json()
{
    local usage="  USAGE: json '.'"
    local expression="${1?$usage}"
    local jsonStr="${2:-}"
    local flags="-r -c"

    # Run jq on file or directly on a JSON string
    if [[ "$jsonStr" == "" ]]; then
        $JQ $flags "$expression" "$DIR_SETTINGS"
    else
        $JQ $flags "$expression" <<< "$jsonStr"
    fi
}


# ------------------------------------------------------------------------------
# Currently only support GCP
# ------------------------------------------------------------------------------
if [[ "$(getEnv)" != "gcp" ]]; then
    echo "Error: Currently only supports Google Cloud environment."
    exit
fi


# ------------------------------------------------------------------------------
# Benchmark
# ------------------------------------------------------------------------------
N=$(json '.N')
nbTests=$(json '.tests | length')

# Install dependencies
init

# General settings
CLOUD=$(getEnv)
tImage=$(json '.'$CLOUD'.image')
tImageProject=$(json '.'$CLOUD'.image_project')
tZone=$(json '.'$CLOUD'.zone')
tMachines=$(json '.'$CLOUD'.machines')
tSSHKey=$(json '.'$CLOUD'.ssh_key')
tScopes=$(json '.'$CLOUD'.scopes')

# Loop through tests
for((i = 0; i < nbTests; i++));
do
    for((j = 0; j < N; j++));
    do
        # Fetch JSON info for current test
        jsonTest=$(json ".tests[$i]")
        tName=$(json '.name' "$jsonTest")$(uuidgen)
        tDiskSize=$(json '.disk' "$jsonTest")
        tMachineID=$(json '.machine' "$jsonTest")
        tMachine=$(json '.['$tMachineID']' "$tMachines")
        tFlags=$(json '.flags' "$jsonTest")

        # Process inputs
        [[ "${tFlags}" == "${JQ_NULL}" ]] && tFlags=""

        # Launch test
        echo -ne "Launching test <$tName> run $((j+1))/${N}..."
        time_start=$SECONDS

        # Running GCP test
        if [[ "$CLOUD" == "gcp" ]];
        then
            # Machine type can either be a VM type (e.g. n1-standard), or the #CPUs/RAM directly
            if [[ "$(json '.type' "${tMachine}")" != "${JQ_NULL}" ]]; then
                machineType="--machine-type "$(json '.type' "${tMachine}")
            else
                nbCPUs=$(json '.cpu' "${tMachine}")
                nbMem=$(json '.mem' "${tMachine}")
                if [[ "${nbCPUs}" != "${JQ_NULL}" ]] && [[ "${nbMem}" != "${JQ_NULL}" ]]; then
                    machineType=" --custom-cpu ${nbCPUs} --custom-memory ${nbMem} "
                fi
            fi

            # Default VM scope
            [[ "${tScopes}" == "${JQ_NULL}" ]] && tScopes="default"

            gcloud compute instances create "${tName}" \
                ${tFlags} --async --no-restart-on-failure \
                --min-cpu-platform "Intel Skylake" \
                --boot-disk-device-name "${tName}" \
                --boot-disk-size "${tDiskSize}" \
                --boot-disk-type "pd-ssd" \
                --image-family "$tImage" \
                --image-project "$tImageProject" \
                ${machineType} \
                --zone "${tZone}" \
                --scopes "${tScopes}" \
                --metadata-from-file startup-script=startup_gcp.sh >/dev/null 2>&1

        # TODO: Running AWS test
        elif [[ "$CLOUD" == "aws" ]];
        then
            :
        fi

        # In case of errors, e.g. exceeded CPU quota or can't reserve VM
        if [[ "$?" != "0" ]];
        then
            echo "Error: couldn't launch VM..."
            sleep 10
            continue
        fi

        # Define IP to use to SSH
        IP=${tName}

        # Keep trying to SSH until can get in
        while true;
        do
            echo -ne "."
            ssh -i "${tSSHKey}" "$IP" \
                -o StrictHostKeyChecking=no \
                -o ConnectTimeout=1 \
                'echo -n " done"' 2>/dev/null
            [[ "$?" == "0" ]] && break
            sleep 0.2
        done

        time_end=$SECONDS
        echo -e "\t"$((time_end - time_start))

        sleep 600  # run once every 10 mins
    done
done
