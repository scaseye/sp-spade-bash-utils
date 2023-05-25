#!/bin/bash
#------------------------------------------------
# Process CLI arguments
#
#------------------------------------------------
usage()
{
    echo "usage: $0 -a fxxxxx.." >&2
}
if [ -z "$1" ]; then 
	usage 
	exit 1
fi
while getopts "a:" f
do
  case "$f" in
    a) echo "Monitoring publish address: ${OPTARG}";publishAddress=${OPTARG} ;;
    *) usage
       exit 1 ;;
  esac
done
#------------------------------------------------
# VARIABLES
# publishAddress set from cli
#------------------------------------------------
basefeeLimit=1000000000
#------------------------------------------------
# functions
#
#------------------------------------------------
replacePublishMsgIfNeeded() {
    publishPendingMsgGasFeeCap=$(lotus mpool pending --local | grep "$publishAddress" -A5 | grep GasFeeCap | awk '{print $2'} | awk '{print substr($0, 2, length($0) - 3)}'  | head -n1)
    publishPendingMsgNonce=$(lotus mpool pending --local | grep "$publishAddress" -A5 | grep Nonce | awk '{print $2'} | awk '{ print substr( $0, 1, length($0)-1 ) }'  | head -n1)
    basefee=$(lotus chain head | awk 'NR==1{print; exit}' | xargs lotus chain getblock | jq -r .ParentBaseFee)
    echo The basefee is: "$basefee"
    echo The GasFeeCap is: "$publishPendingMsgGasFeeCap"
    if [ -n "$publishPendingMsgGasFeeCap" ] && [ $(("$publishPendingMsgGasFeeCap")) -le $(("$basefee")) ]; then
        echo GasFeeCap is too low
        if [ "$(("$basefee"))" -le "$basefeeLimit" ]; then
            echo "lotus mpool replace --auto --fee-limit 0.${basefee:0:1} $publishAddress $publishPendingMsgNonce"
	        replaceMsg=$(lotus mpool replace --auto --fee-limit 0."${basefee:0:1}" "$publishAddress" "$publishPendingMsgNonce")
            echo sleep 5 mins
            sleep 300
        fi
        sleep 5
    fi
}
check_mpool() {
    mps=$(lotus mpool pending --local | grep -c "$publishAddress")
    #echo checking mpool for msgs, found "$mps"
    while [ "$mps" -gt 0 ]; do
        echo "Found publish msgs in mpool sleep 5 seconds... "
        sleep 5
        replacePublishMsgIfNeeded
    	mps=$(lotus mpool pending --local | grep -c "$publishAddress")
        echo checking mpool for msgs, found "$mps"
    done
}
#------------------------------------------------
# main
# 
#------------------------------------------------
echo Will manage Publish messages when BaseFee is less than $basefeeLimit
while :; do
    check_mpool
    sleep 60
done