#!/bin/bash

basefeeLimit=1000000000
basefeeFloor=250000000

check_basefee() {
    publishPendingMsgGasFeeCap=$(lotus mpool pending --local | grep "f1mgzeuq7h7fcqddbnxl3rufa5m5jwsidsgyoumti" -A5 | grep GasFeeCap | awk '{print $2'} | awk '{print substr($0, 2, length($0) - 3)}')
    publishPendingMsgNonce=$(lotus mpool pending --local | grep "f1mgzeuq7h7fcqddbnxl3rufa5m5jwsidsgyoumti" -A5 | grep Nonce | awk '{print $2'} | awk '{ print substr( $0, 1, length($0)-1 ) }')
    basefee=$(lotus chain head | awk 'NR==1{print; exit}' | xargs lotus chain getblock | jq -r .ParentBaseFee)
    echo The basefee is: $basefee
    echo The GasFeeCap is: $publishPendingMsgGasFeeCap
    if [ ! -z "$publishPendingMsgGasFeeCap" ] && [ $(($publishPendingMsgGasFeeCap)) -le $(($basefee)) ]; then
        echo GasFeeCap is too low
        if [ "$(($basefee))" -le 1000000000 ]; then
            echo "lotus mpool replace --auto --fee-limit 0.${basefee:0:1} f1mgzeuq7h7fcqddbnxl3rufa5m5jwsidsgyoumti $publishPendingMsgNonce"
            lotus mpool replace --auto --fee-limit 0.${basefee:0:1} f1mgzeuq7h7fcqddbnxl3rufa5m5jwsidsgyoumti $publishPendingMsgNonce
            echo sleep 5 mins
            sleep 300
        fi
        sleep 5
    fi
}
check_mpool() {
    mps=$(lotus mpool pending --local | wc -l)
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
