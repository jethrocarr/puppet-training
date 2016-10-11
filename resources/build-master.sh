#!/bin/bash
#
# Provision a Puppet master with PuppetDB for training purposes. This script
# is simplistic in nature to provide the functionality needed for training
# purposes only and is not recommended for real-world production Puppet master
# builds.
(
exec 1> >(logger -s -t user-data) 2>&1

# Set hostname
hostname master

# Update operating system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade


)
