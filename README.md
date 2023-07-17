# ntrip-proxy-docker

This Dockerfile builds a docker image running the NTRIP proxy.
The proxy looks to an NTRIP base station like an NTRIP caster.  In 
fact it acts as a go-between.  Whenever it receives a request, it 
passes it on to a caster running on a remote host machine and then
relays any response back to the sender.  The requests contain RTCM
messages.  The proxy keeps a copy of the last few messages that 
passed through it and offers a web interface that displays them.  It
can also keep complete logs of all messages passed each day.  Each
days log file is named for that day, for example the log for the 
14th of February 2023 is called "data.2023-02-14.rtcm".  These logs
can be used for purposes such as Precise Point Positioning
https://en.wikipedia.org/wiki/Precise_Point_Positioning/.

The proxy is run within the docker container by a user with a user
ID.  To receive configuration information and to create log files, 
that user must be able to read and write files in the outside world. 
If you are running Docker on a Linux machine, you achieve that by 
ensuring that the user ID of the docker user is the same as the user 
ID of the user running the image.  When you build the image you must 
pass build-arg parameters specifying the  name and ID of the user.  
For example, this command builds the image and supplies the name and 
ID of the user who is running the build command:

```
   docker build --rm -t ntrip-proxy \
       --build-arg user=${USER} --build-arg uid=${UID} .
```

(Note the dot at the end of the line, which tells docker in which
directory it should run, in this case "." the current directory.)

When the docker image runs, a docker container is created and within it the
defined user runs the proxy.  The current directory is that user's 
home directory within the container.

The design assumes that you will create a 
directory in the filestore in the outside world containing a file called proxy.json and map the directory onto the 
home directory of the user running the proxy in the container.
The contents of proxy.json could be:

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

The local_host and local_port settings specify the name and port that the proxy responds to.
You should set local_host to the IP address or name of the
machine on which you are running the container, in double quotes - 
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

If record_messages is true then
messages are created in the directory 
given by the
message_log_directory value - ",/logs"
in the example,
meaning the directory "logs" in the current
directory
(which is the user's home directory in the container.)


You need to map the home directory in the container
to a real directory in the outside world that you own and can write to.
The user in the container has the same name and user ID as you, so it can
read and write your files.  Use -v to map the directory.  It expects full 
path names.

So that a base station can connect to the
proxy, the docker container must use the host machine's IP address as 
its IP address.  Use the --network=host option to do that.

For example, if your user name is simon and you built the image
as above, you passed your name and UID to builder, so the user
within the docker container is called simon and has the home directory 
/home/simon.  You can create a directory in the outside world
containing the config file and map that to 
the home directory in the container.
The directory in the outside world then
becomes the user's home directory in the container.
Any files that the proxy creates in there
appear in proxy.home in the outside world.

For example, on the machine that I'm going to use to run the proxy, my user name is simon.
I create a directory proxy.home in my home directory, so that's /home/simon/proxy.home.  I create my config file config.json in there and run my proxy. 

My machine runs Linux.
The sequence "$(pwd)" (with the quotes) is replaced on the command
line by the full path name of my current directory.  If I change
directory to the one containing the control file (in my case
/home/simon/proxy.home) I can run the proxy like so: 

```
    docker run -it -v "$(pwd)":/home/simon --network=host ntrip-proxy
```

The proxy is now running and /home/simon/proxy.home in the outside world is the same as
/home/simon in the container.  Any files created in one appear in the other.

The proxy creates a directory "logs"
in /home/simon
and creates log files in it.
It creates a new log file each day.
Each file is named after the date it was
created - data.{yyyy-mm-dd}.rtcm.
The log files contain a copy of all the files that passed through the proxy that day
so they are very big.

I mapped the reporting interface port onto port 5001 so I can get a 
status report showing the last few messages by navigating my web 
browser to http://localhost:5001/status/report/.  (The network name
"localhost" always means "this computer".)

You can run the proxy on the same machine as the caster but on a different port.
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

With that configuration, display the report
using this URL: http://example.com:5001/status/report/.

Once you have everything working
you can shut down the proxy
and configure your base station
to connect directly to your real caster.

