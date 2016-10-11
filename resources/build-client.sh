#!/bin/bash
#
# Build a client server capable of connecting to the Puppet master
#

# Update operating system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade
