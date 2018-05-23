#!/bin/bash
# run 4 fixed instances
# this can be updated to 
# get the cpu core count
# and start instances for example count - 1 in order to retain some resources for your workstation.
# i run it on a dedicated raspberry pi 3
# with 4 cores, so I just implemented 4 fixed instances
##
## so this should work 
# count=$(nproc)

inputdir="/path/to/input"
outputdir="/path/to/output"

## if you want to use this dynamically, you might consider this version - UNTESTED though
# for i in {1..$count}
for i in {1..4}
do
    echo "started instance no: $i"
    ./transform.sh -i "$inputdir" -o "$outputdir" -t "$i" &
    sleep 5
done
echo "all instances started"
