#!/bin/bash
#------------------------------------------------
# Process CLI arguments
#
#------------------------------------------------
if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: $0 <MINER_ID> <Path to store cars>"
    exit 1
fi
#check that path exists, remove trailing slash if present
if [ -d "$2" ]; then
    echo "$2 is valid path"
    downloadDirectory="${2%/}"
    echo "using $downloadDirectory as download directory."
else
    echo "$2 is not a valid path"
    exit 1
fi
#handle errors 
set -eu
set -o pipefail
#------------------------------------------------
# VARIABLES
#
#------------------------------------------------
miner=$1
maxLotusSealingJobs=32
currentLotusJobs=0
SLEEPJOBCHECK=15
SEALINGJOBSTYPES="PC1\|RU\|GET\|FRU\|AP"
concurrent_downloads=5
downloads=()
# future account for piece sizes
# set max for this run to 1TiB
#maxLotusSealingBytes=1000000000000
#currentSealingBytes=0
#------------------------------------------------
# functions
#
#------------------------------------------------
countLotusJobs() {
    echo Checking these Lotus Job Types: "$SEALINGJOBSTYPES"
    currentLotusJobs=$(lotus-miner sealing jobs | grep -c "$SEALINGJOBSTYPES")
    echo "Counting Sealing jobs! Found $currentLotusJobs, Max set to $maxLotusSealingJobs ."
    while [ "$currentLotusJobs" -gt $maxLotusSealingJobs ]; do
        echo "to many Sealing Jobs to contintue... sleeping for $SLEEPJOBCHECK seconds..."
        sleep $SLEEPJOBCHECK
        currentLotusJobs=$(lotus-miner sealing jobs | grep -c "$SEALINGJOBSTYPES")
        echo "Counting $SEALINGJOBSTYPES jobs! Found $currentLotusJobs, Max set to $maxLotusSealingJobs."
    done
}
download_and_run_command() {
    echo "Executing command: $1"
    eval "$1"
    echo "Command execution completed!"
}
#------------------------------------------------
# main
# 
#------------------------------------------------
pending_response=$(echo curl -sLH \"Authorization: $(./fil-spid.bash "$miner")\" https://api.spade.storage/sp/pending_proposals | sh)
# get response code from JSON output
pending_response_code=$(echo "$pending_response" | jq -r '.response_code')
pending_proposals=$(echo "$pending_response" | jq -r '.response.pending_proposals')
pending_count=$(echo "$pending_proposals" | grep -c "sample_import_cmd")
echo "$pending_response"
echo "API response code found: $pending_response_code"
echo "API pending proposals found: $pending_proposals"
echo "Pending Proposals count :$pending_count"
# if response code is 200 build array of download and imports. 
if [ "$pending_response_code" -eq 200 ]; then
    for ((i = 0; i < "$pending_count"; i++)); do
        echo "Processing entry: $i"
        dl=$(echo "$pending_response" | jq -r --argjson idx "$i" '.response.pending_proposals[$idx].data_sources[0]')
        deal_proposal_cid=$(echo "$pending_response" | jq -r --argjson idx "$i" '.response.pending_proposals[$idx].deal_proposal_cid')
        piece_cid=$(echo "$pending_response" | jq -r --argjson idx "$i" '.response.pending_proposals[$idx].piece_cid')
        piece_size=$(echo "$pending_response" | jq -r --argjson idx "$i" '.response.pending_proposals[$idx].piece_size')
        f=$(basename -- "$dl")
        echo "found Deal: $deal_proposal_cid"
        echo "found Download URL: $dl"
        echo "found Piece CID: $piece_cid"
        echo "found Piece size: $piece_size"
        echo "found carfile: $f"
        if [ -e "$downloadDirectory/""$f".aria2 ]; then
            echo "Parital File exist resume download it..."
            downloads+=("aria2c -d $downloadDirectory $dl -x5 --auto-file-renaming=false && boostd import-data $deal_proposal_cid $downloadDirectory/$f")
            # echo "boostd import-data "$deal_proposal_cid" "$downloadDirectory/""$f""
        elif [ -e "$downloadDirectory/""$f" ]; then
            echo "$f File already exists, assuming it has already been imported! copy and paste the next line if you need to import."
            echo "boostd import-data $deal_proposal_cid $downloadDirectory/$f"
        else
            echo "File does not exist download it..."
            downloads+=("aria2c -d $downloadDirectory $dl -x5 --auto-file-renaming=false && boostd import-data $deal_proposal_cid $downloadDirectory/$f")
        fi
    done
    echo Begin download and boostd import, concurrency set to $concurrent_downloads
    for i in "${downloads[@]}"; do
        while [ "$(jobs -p | wc -l)" -ge "$concurrent_downloads" ]; do
            # Wait for any background job to finish
            wait -n
        done
	#countLotusJobs
        # Execute the command in the background
        download_and_run_command "$i" &
    done
    # Wait for all background jobs to complete
    wait
    echo "All downloads and imports completed!"
else
    echo "Error: response code $pending_response_code"
fi