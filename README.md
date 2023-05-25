# sp-spade-bash-utils

Bash scripts for Storage Providers to automate the onboarding of Spade deals. 

Open terminal and run the following:

./spade-make-reservation.sh <miner_id> <num_of_deals>
sleep 300
./spade-process-pending-jobs.sh <miner_id> <path_to_download_cars>

Open 2nd terminal and run the following to push publish messages through.

./spade-manage-publish-mpool.sh -a <publish_address>
