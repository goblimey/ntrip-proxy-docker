#! /bin/sh

# Download and build the proxy.  Copy the binary to the bin directory.

uid=$1
user=$2

# Set up the container ready to build the application.
                     
apt update
apt -y install ssh
apt -y install git
apt -y install golang

# rm -fr /home/${user}

# Create a user with the provided name and uid to run the proxy.
useradd --user-group --create-home --uid ${uid} ${user} # Create the user in a group of the same name
usermod --lock ${user}  # Lock (disable) the user's password.

# Download and build the proxy.
git clone https://github.com/goblimey/go-ntrip.git go-ntrip

cd go-ntrip/apps/proxy
go build
mkdir /ntrip
cp proxy /ntrip
chmod +x /ntrip/proxy
