#!/bin/bash

service dbus status > /dev/null || service dbus start 
sleep .5 
service avahi-daemon status > /dev/null || service avahi-daemon start 
sleep .5

# create stream folder if it dosen't exsist 
[[ ! -d $STREAMFOLDER ]] && mkdir -p -m 777 $STREAMFOLDER 
# create pipe if it dosen't exsist 
[[ ! -p $STREAMFOLDER/$PIPENAME ]] && mkfifo -m 777 $STREAMFOLDER/$PIPENAME




/usr/bin/librespot \
    --name $NAME \
    --bitrate $BITRATE \
    --backend pipe \
    --disable-audio-cache \
    --format F32 \
    --initial-volume=50 \
    --mixer softvol \
    --passthrough \
    --device $STREAMFOLDER/$PIPENAME \
    &>/dev/null & 

sleep 2

# 32-bit floating point (F32), 32-bit integer (S32)

# Run monitor pipe 
#./monitorPipe.sh &>/dev/null &

# Wait for any process to exit
wait -n
# Exit with status of process that exited first
exit $?

