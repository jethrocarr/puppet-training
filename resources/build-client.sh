#!/bin/bash
#
# Build a client server capable of connecting to the Puppet master
#
(
exec 1> >(logger -s -t user-data) 2>&1

# Update operating system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade


)
