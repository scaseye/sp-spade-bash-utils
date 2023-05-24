#!/bin/bash
while getopts "a" f
do
  case "$f" in
    a) echo "Monitoring publish address: ";publishAddress=${OPTARG} ;;
    *) echo "usage: $0 [-a]" >&2
       exit 1 ;;
  esac
done
basefeeLimit=1000000000
#basefeeFloor=250000000
check_basefee() {
    publishPendingMsgGasFeeCap=$(lotus mpool pending --local | grep "$publishAddress" -A5 | grep GasFeeCap | awk '{print $2'} | awk '{print substr($0, 2, length($0) - 3)}')
    publishPendingMsgNonce=$(lotus mpool pending --local | grep "$publishAddress" -A5 | grep Nonce | awk '{print $2'} | awk '{ print substr( $0, 1, length($0)-1 ) }')
    basefee=$(lotus chain head | awk 'NR==1{print; exit}' | xargs lotus chain getblock | jq -r .ParentBaseFee)
    echo The basefee is: "$basefee"
    echo The GasFeeCap is: "$publishPendingMsgGasFeeCap"
    if [ -n "$publishPendingMsgGasFeeCap" ] && [ $(("$publishPendingMsgGasFeeCap")) -le $(("$basefee")) ]; then
        echo GasFeeCap is too low
        if [ "$(("$basefee"))" -le "$basefeeLimit" ]; then
            echo "lotus mpool replace --auto --fee-limit 0.${basefee:0:1} $publishAddress $publishPendingMsgNonce"
            lotus mpool replace --auto --fee-limit 0."${basefee:0:1}" "$publishAddress" "$publishPendingMsgNonce"
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
        echo "Found msgs in mpool sleep 15 seconds... "
        sleep 5
        check_basefee
        mps=$(lotus mpool pending --local | wc -l)
        echo checking mpool for msgs, found "$mps"
    done
}
while :; do
    check_mpool
done