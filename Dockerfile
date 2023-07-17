
FROM ubuntu:latest

ARG user
ARG uid

COPY build.sh /tmp

RUN chmod +x /tmp/build.sh && /tmp/build.sh ${uid} ${user}

# Switch to the non-privileged user.
USER ${user}

# It's expected that the user's home directory is mounted
# and contains the config file proxy.json.  If the config
# specifies logging then the user must be able to create
# files in the configured logging directory.
WORKDIR /home/${user}

CMD /ntrip/proxy -c ./proxy.json -v



