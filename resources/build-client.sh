#!/bin/bash
#
# Build a client server capable of connecting to the Puppet master
#

# Set hostname
hostname client

# Update operating system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade
