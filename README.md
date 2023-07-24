# ntrip-proxy-docker

This Dockerfile builds a docker image running the NTRIP proxy.

The proxy is useful if you are trying to configure a base station, a rover
and an NTRIP caster to work together,
and something is misbehaving.
You can use the proxy to see what's going on.

The proxy looks to a GNSS device like an NTRIP caster.  In 
fact it just acts as a go-between.  Whenever it receives a request, it 
passes it on to a caster running on a remote host machine and then
relays any response back to the sender.  The requests contain RTCM
messages.  The proxy keeps a copy of the last few messages that 
passed through it and offers a web interface that displays them.  It
can also keep complete logs of all messages passed each day.  Each
days log file is named for that day, for example the log for the 
14th of February 2023 is called "data.2023-02-14.rtcm".  These logs
can be used for purposes such as Precise Point Positioning
https://en.wikipedia.org/wiki/Precise_Point_Positioning/.

## Building the Proxy

The proxy is run within the docker container by a user with a user
ID.  To receive configuration information and to create log files, 
that user must be able to read and write files in the outside world. 
If you are running Docker on a Linux machine, you achieve that by 
ensuring that the user ID of the docker user is the same as the user 
ID of the user running the image.  When you build the image you must 
pass build-arg parameters specifying the name and ID of the user.
For example, this command builds the image and supplies the name and 
ID of the user who is running the build command:

```
   docker build --rm -t ntrip-proxy --build-arg user=${USER} --build-arg uid=${UID} .
```

(Note the dot at the end of the line, which tells docker in which
directory it should run, in this case "." the current directory.)


## Running the Proxy

When the docker image is run, a docker container is created and within it the
defined user runs the proxy.  The current directory is that user's 
home directory within the container, for example /home/simon.

The design assumes that you will create a 
directory in the filestore of your computer
containing a file called proxy.json and map the directory onto the 
home directory of the user running the proxy in the container.
That produces a directory which exists both in the filestore
of your computer and within the docker container,
potentially with a different name in each context.

For example,
I connect my computer to my home network
and see its IP address is 192.168.0.10.
I create a directory proxy.home
and within that a text file proxy.config containing:

```
{
    "local_host": "192.168.0.10",
    "local_port": 2101,
    "remote_host": "example.com:2101",
    "control_port": 5001,
    "record_messages": true,
    "message_log_directory": "./logs"
}
```

In a command window I change directory to proxy.home and run the
proxy like so:

```
    docker run -it -v "$(pwd)":/home/simon --network=host ntrip-proxy
```

By default a docker container has its own IP address.
So that a GNSS device can connect to the
proxy, the docker container must use the host machine's IP address instead.
The --network=host option does that.

The -v option takes the
full path name of the file in the outside world
and the name within the docker container that it's to be mapped on to.
My computer runs the Linux operating system.
The sequence "$(pwd)" is replaced on the command
line by the full path name of my current directory, which is proxy.home.

So proxy.home in the outside world and /home/simon in the container
become the same.
Anything created in one appears in the other.
I've already created a file proxy.json.

Within the docker container
the current directory is /home/simon,
which is where
the proxy expects to find a config file called proxy.json.
It finds the one that I set up in proxy.home.

In the config file record_messages
is set to true
and message_log_directory is set to "./logs"
meaning that the proxy should capture any messages that it receives
and store them in a file in 
the directory called logs in the current directory.
If that directory doesn't already exist,
the proxy creates it.
In the outside world the log directory appears as
proxy.home/logs.

The proxy is now running
and waiting for messages.
I can now connect my base station to port 2101 of 192.168.0.10
and it will start to issue RTCM messages.
The proxy passes them on to the NTRIP caster defined by the remote_host
value in the config file.
It also captures them and stores them in a file in the logs directory.
In the outside world, that's logs in my current directory proxy.home:

```
    ls logs
    data.2023-07-15.rtcm  data.2023-07-17.rtcm
```

The proxy creates a log file named after this day's date.
As you can see,
I ran the proxy on the 15th July.  Now I'm running it again on the 17th
and it's writing messages to data.2023-07-17.rtcm as they come in.

If I leave it running
then at midnight UTC
it will create a new log file named after the new day
and write the day's messages in there.  The next night it will do the same.

The proxy also offers a web interface that displays the last few messages.
In the config, control_port is set to 5001
so the proxy is waiting on that port for a status report request.
To send one I navigate my web browser to http://localhost:5001/status/report/.
The resulting report shows:

* the data from the last request received and forwarded to the caster
* the response from the caster
* a list of recent RTCM messages, broken out into plain text where possible.

There may be more messages in the list than are in the last request. Also, the report can only interpret complete messages, so if the data in the request includes part of a message at the end, that will not be shown in the list of messages.

If you're just trying to get a base, rover and caster
to talk to each other,
this report contains far more information than you need,
but if you work through it
you can see first of all
that the base is sending batches of messages
to the caster.
If the two are linking up properly you should see an "OK" response from the caster.
If not, then either your base station is not configured properly
or your caster is not working.

Looking further down the report you can see
what messages the base is sending and
the number of satellites it's receiving signals from.
The message types should match the types that the base is expecting.

If you want to understand the report completely, see https://github.com/goblimey/go-ntrip.


## Proxy and Caster on the Same Machine
In the example above I ran the proxy
on one machine and the caster on another.
You can run both on the same machine
as long as they run on different ports.
In that case, from the point of view
of the proxy,
the caster is running on port 2001 of localhost,
so the config file would be something like

```
{
    "local_host": "example.com",
    "local_port": 2102,
    "remote_host": "localhost:2101",
    "control_port": 5001,
    "record_messages": true,
    "message_log_directory": "./logs"
}
```

With that configuration,
the proxy runs on the server example.com on port 2102,
takes any messages it receives
and passes them to the caster running on the same server on port 2101.

Configure the base station to send messages to example.com port 2102.
Display the status report
using this URL: http://example.com:5001/status/report/.

## Shutting Down the Proxy

Once you have everything working
you can shut down the proxy.
First, find the ID of the container using "docker ps" like so:

```
    docker ps
    CONTAINER ID IMAGE       COMMAND                CREATED        STATUS        PORTS  NAMES
    d9a95b135b88 ntrip-proxy "/bin/sh -c '/ntrip/…" 11 seconds ago Up 10 seconds     compassionate_mclaren
```

The container ID is d9a95b135b88.  Shut the container down like so:

```
    docker kill d9a95b135b88
```

Now configure your base station
to connect directly to your real caster.

When you shut down the docker container, any files that it created are lost except for those that are mapped onto files in the outside world.
So it only makes sense to create log files in a mapped directory.

You certainly don't want to run a proxy running
for longer than you need
if it's configured to create log files.
The files are VERY big.


## Precise Point Positioning (PPP)

To set up a base station
you need to know its position
very precisely. 

The base can find its position approximately.
You can then use the proxy to collect messages from the base
for a few days and send the files off for PPP processing 
to get a more accurate botion of the position.
You will probably need to convert the files to RINEX
format, but there are free tools available to do that.

Use your favourite search engine to find PPP processing services.

## The Config Settings

The local_host and local_port settings specify the name and port that the proxy responds to.
You should set local_host to the IP address or name of the
machine on which you are running the docker container, in double quotes - 
in the example, "192.168.0.10".
Set local_port to be any spare port -
2101 is the default for NTRIP
so it's the obvious choice.

If your machine is running a firewall
you will need to open up that port.

The remote_host setting is the 
name and port number where the proxy will send requests to - in the 
example, port 2101 of example.com.

The control_port value defines the port
that the reporting interface runs on - 
port 5001 in the example.
By default the host name of the 
reporting interface is the same as the
host name of the proxy.
You can set it to some other name using the control_host value. 
(It must be a name that the host machine
responds to,
so setting it to a different name
from that of the proxy
only makes sense if the
host machine responds to both 
of those names.)

If record_messages is true then logs of
messages are created in the directory 
given by the
message_log_directory value - ",/logs"
in the example,
meaning the directory "logs" within the container in the current
directory.
When the proxy runs, the current directory is the user's home directory.



