# This builds a docker image running the NTRIP proxy.
#
# The proxy looks to an NTRIP base station like an NTRIP caster.  In 
# fact it acts as a go-between.  Whenever it receives a request, it 
# passes it on to a caster running on a remote host machine and then
# relays any response back to the sender.  The requests contain RTCM
# messages.  The proxy keeps a copy of the last few messages that 
# passed through it and offers a web interface that displays them.  It
# can also keep complete logs of all messages passed each day.  Each
# days log file is named for that day, for example the log for the 
# 14th of February 2023 is called "data.2023-02-14.rtcm".  These logs
# can be used for purposes such as Precise point Positioning (PPP).
#
# The proxy is run within the docker container by a user with a user
# ID.  To receive configuration information and to create log files, 
# that user must be able to read and write files in the outside world. 
# If you are running Docker on a Linux machine, you achieve that by 
# ensuring that the user ID of the docker user is the same as the user 
# ID of the user running the image.  When you build the image you must 
# pass build-arg parameters specifying the  name and ID of the user.  
# For example, this command builds the image and supplies the name and 
# ID of the user who is running the build command:
#
#    docker build --rm -t ntrip-proxy \
#        --build-arg user=${USER} --build-arg uid=${UID} .
#
# When the docker image runs, a docker container is created and the
# defined user runs the proxy.  The current directory is that user's 
# home directory within the container.
#
# The design assumes that you will create a 
# directory in the filestore in the outside world and map it onto the 
# home directory of the user running the proxy in the container.  The
# directory should contain a file proxy.json which configures the  
# proxy.  For example the contents of that file could be:
#
# {
#   "local_host": "172.20.10.6",
#	"local_port": 2101,
#	"remote_host": "example.com:2101",
#   "control_port": 4001,
#	"record_messages": true,
#	"message_log_directory": "./logs"
# }
#
# The local_host and local_port settings specify the local machine.
# You should set local_host to be the IP address or name of the 
# machine on which you are running the container, in double quotes. 
# (In the example it's "172.20.10.6").  The remote_host setting is the 
# name and port number where the proxy will send requests to (in the 
# example, port 2101 of example.com).  The reporting interface runs on 
# port 4001 of the container and logs are created in the directory 
# "logs" in the user's home directory within the container.
#
# To run the proxy, you need to map the home directory in the container
# to a real directory in the outside world that you own and can write to.
# The user in the container has the same name and user ID as you, so it can
# read and write your files.  Use -v to map the directory.  It expects full 
# path names.
#
# For example, if your user name is simon, and you built the image
# as above, you passed your name and UID to docker build, so the user
# within the docker container is called simon and has the home directory 
# /home/simon.  If you have created a directory in the outside world
# called proxy-home containing the config file, you can map that to 
# the home directory in the container.
#
# The sequence "$(pwd)" (with the quotes) is replaced on the command
# line by the full path name of the current directory.  If you change
# directory to the one containing the control file (in my case
# /home/simon/proxy.home) you can run the proxy like so: 
#
#     docker run -it -v "$(pwd)":/home/simon --network=host ntrip-proxy
#
# In the config file record_messages is true and message_log_directory is
# "./logs".  The current directory in the container is /home/simon so the 
# proxy takes the RTCM messages as they pass through and copies them to a 
# file /home/logs/data.{todays-date}.rtcm witn the container.  If the container continues to
# run then at midnight UTC a new log file will be created named using the 
# next day's date, and so on.
#
# You mapped the reporting interface port onto port 5001 so you can get a 
# status report showing the last few messages by navigating your web 
# browser to http://localhost:5001/status/report/.  (The network name
# "localhost" always means "this computer".)
#
# Accessing a git repository from docker requires some setup, which is
# described here:  https://gist.github.com/jrichardsz/5f9e45a2897ebce46f614b6172a4811f/

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



