FROM debian:bullseye-slim
LABEL "maintainer"="nadigo@gmail.com" "appname"="airspot"
LABEL "Desciption" "Dockerized implementation of the librespot library with direct Airplay output"
LABEL "Project" "airspot"

USER root
RUN cd /root 

RUN apt update \
    && apt-get install -y bash ntp dbus avahi-daemon procps sox 
    
RUN apt-get install -y git build-essential cargo \
    && git clone https://github.com/nadigo/librespot 

RUN cd librespot \
    && cargo build --release ---no-default-features \
    && cp target/release/librespot /usr/bin/ \
    && chmod +x /usr/bin/librespot 


ARG NAME
ENV NAME=${NAME:-airspot}
#ARG USER ENV USER # future use
#ARG PASS ENV PASS # future use
ARG BITRATE  
ENV BITRATE=${BITRATE:-320}
ARG PIPENAME
ENV PIPENAME=${PIPENAME:-$NAME.fifo}
ARG STREAMFOLDER
ENV STREAMFOLDER=${STREAMFOLDER:-/$NAME}


COPY raop_play /usr/bin/raop_play
RUN chmod +x /usr/bin/raop_play

WORKDIR $NAME

COPY spk.conf ./spk.conf
COPY file_example_WAV_10MG.wav ./file_example_WAV_10MG.wav

COPY monitorPipe.sh ./monitorPipe.sh
RUN chmod +x ./monitorPipe.sh

COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

#ENTRYPOINT ["./entrypoint.sh"]

CMD sh -c 'trap "exit" TERM; while true; do sleep 1; done'



