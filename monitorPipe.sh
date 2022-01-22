#!/bin/bash

# let's log
log=$(echo $STREAMFOLDER/$PIPENAME | sed -e 's/\.[^.]*$//').log
echo "Run by $(cat /proc/$PPID/comm):$PPID  @ $(date)" > $log
#exec > >(tee -a $log) ; exec 2>&1 ; sleep .1
exec 2>&1 >> $log


### FUNCTIONS ###
trim_File () {
    local trimFile=$1
    local maxSize=$2
    if [[ $(stat -c %s $trimFile 2>/dev/null) -gt $maxSize ]] ; then
    truncate -s 1024 $trimFile
    echo "Flushed $trimFile @ $(date)" >> $log
    fi
}

isProcessRunning() { 
    pid=$(pgrep -x ${1}) ; if [[ ! -z $pid ]] ; then retval=1; else retval=0; fi; echo $retval; 
}


#   cat <$STREAMFOLDER/$PIPENAME | ffmpeg -f ogg  -i pipe:0  -ar 44100 -f aac pipe:1 | raop_play -p 7000 -v 30 192.168.4.12 - 


player() { 

    case $1 in
        'play')
                echo "--> player:play" >> $log 
                ## Load speakers config  
                source $STREAMFOLDER/spk.conf; speakers=( `echo ${speaker1[@]}` `echo ${speaker2[@]}`)
                ###
                # generate ntp file
                [[ -f $STREAMFOLDER/$ntpFile ]] &&  rm $STREAMFOLDER/$ntpFile  
                $playerCmd -ntp $STREAMFOLDER/$ntpFile 
                #wait $!
                echo "Saved nfp file $ntpFile:$(<$STREAMFOLDER/$ntpFile) @ $(date)" >> $log
                # build pipePlayer 
                pipePlayerCmd="cat <$STREAMFOLDER/$PIPENAME | dd status=none iflag=fullblock bs=1024 | tee "
                for (( i=0; i<$((${#speakers[@]}-2)) ;i+=2 )); do 
                    pipePlayerCmd+=">($playerCmd -d 0 -p $port -l $latency -w $wait -nf $STREAMFOLDER/$ntpFile -v ${speakers[$i]} ${speakers[$((i + 1))]} - ) "
                done
                pipePlayerCmd+="| $playerCmd -d 0 -p $port -l $latency -w $wait -nf $STREAMFOLDER/$ntpFile -v ${speakers[-2]} ${speakers[-1]} - &"
                # START pipePlayer
                eval "$pipePlayerCmd" 
                echo $! >$STREAMFOLDER/$playerPid 
                echo "Started pipePlayer pid=$(<$STREAMFOLDER/$playerPid) @ $(date)" >> $log ;;
        'stop') 
                printf "--> player:stop" >> $log 
                kill -9 $(<$STREAMFOLDER/$playerPid) 2> /dev/null 
                echo "killing player pid=$(<$STREAMFOLDER/$playerPid)" >> $log ;;
    esac
}
## END FUNCTIONS ####  


# Monitoring pipe for sound 
#
# cleaning things up
monitorFile=$STREAMFOLDER/monitor.wav
monitorFileMax=$(echo "1e+08" | awk '{printf("%0.0f",$0);}')  #in bytes
# new monitoring file
[[ -f $monitorFile ]] && rm $monitorFile
touch $monitorFile ; chmod 777 $monitorFile

# start sox recording for sound / silence monitoring
# make sure default alsa capturing device is 'mixed' with dsnoop for simultaneous access
# /// ToDo ////
# find better silence parameters
# silence 1 0.1 1% -1 5.0 5%


/usr/bin/sox -V2 -q \
-t raw -r 44100 -b $(($BITRATE/10)) -c 2 -L -e signed-integer $STREAMFOLDER/$PIPENAME \
-t raw - silence 1 0.1 0.1% -1 5.0 -85d \
| cat >> $monitorFile &
sleep 1
echo "Starting sox monitoring SOX pid=$(($!-1)) monitorFile=$monitorFile @ $(date)" >> $log

while [ true ]; do

    until [ "$var1" != "$var2" ]; do
        var1=$(stat -c %s $monitorFile)
        sleep .5
        var2=$(stat -c %s $monitorFile)
    done
    # sound detected --> player:play
    echo "Sound Detected starting player @ $(date)" >> $log
    player play

    until [ "$var1" == "$var2" ]; do
        trim_File $monitorFile $monitorFileMax
        var1=$(stat -c %s $monitorFile)
        sleep .5
        var2=$(stat -c %s $monitorFile)
    done
    # silence detected --> player:stop
    echo "Silence Detected stopping player @ $(date)" >> $log
    player stop

done
