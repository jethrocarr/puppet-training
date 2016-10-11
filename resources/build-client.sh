#!/bin/bash
#
# Build a client server capable of connecting to the Puppet master
#

# Set hostname
HOSTNAME=client
hostname ${HOSTNAME}
echo ${HOSTNAME} > /etc/hostname
echo "127.0.0.1 ${HOSTNAME}" >> /etc/hosts

# Update operating system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y dist-upgrade

# Install upstream Puppetlabs version. We want to be training on the latest
# version, Puppet 4 made life a lot easier in many ways.
wget -O /tmp/puppetlabs-release.deb https://apt.puppetlabs.com/puppetlabs-release-pc1-`lsb_release -sc`.deb
dpkg -i /tmp/puppetlabs-release.deb
apt-get update
apt-get -y install puppet-agent

# Symlink the Puppet binaries to match the OSS installation
update-alternatives --install /usr/bin/puppet puppet /opt/puppetlabs/bin/puppet 1
update-alternatives --install /usr/bin/facter facter /opt/puppetlabs/bin/facter 1
update-alternatives --install /usr/bin/hiera hiera /opt/puppetlabs/bin/hiera 1
update-alternatives --install /usr/bin/mco mco /opt/puppetlabs/bin/mco 1

# Generate the Puppet configuration for the agent. The file is empty other than
# comments by default, so we just set the overrides we care about.
cat >> /etc/puppetlabs/puppet/puppet.conf << EOF
[main]
  certname = ${HOSTNAME}
  environment = training
EOF

# Discover the IP address of the master server and write to hosts file. I hate
# how complex this is, PRs welcome... or a boot up someone's rear end at AWS
# to make it easier to discover a stack's own metadata!

# TODO: Not API timeout safe.

apt-get -y install python-pip jq
pip install awscli

REGION=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region'`
INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`

CFN_STACK_NAME=`aws ec2 describe-tags --filters \
"Name=resource-id,Values=${INSTANCE_ID}" \
"Name=key,Values=aws:cloudformation:stack-name" \
--region $REGION \
| jq -r '.Tags[].Value'`

 MASTER_IP=`aws cloudformation describe-stacks \
 --stack-name ${CFN_STACK_NAME} \
 --region $REGION \
 | jq -r '.Stacks[].Outputs[] | select(.OutputKey=="PuppetMasterAddress").OutputValue'`

 echo "${MASTER_IP} master" >> /etc/hosts
 echo "${MASTER_IP} puppet" >> /etc/hosts


# Wait for the Puppet master to become available, the EC2 servers are launched
# in parallel and it's likely the client will beat the master in launching.
while ! nc -w 5 -z puppet 8140; do
  sleep 1
  echo "Waiting for Puppet master..."
done

# We don't normally start the background agent, since this can confuse training
# staff as the Puppet run can sometimes occur in the background without them
# realising. So we leave it stopped. For reference, the command to enable the
# daemon is below:
#/opt/puppetlabs/bin/puppet resource service puppet ensure=running enable=true

# Perform a single Puppet run to get a signed certificate and perform the
# initial run with the seed Puppet data, ready for the user to take on the
# training.
puppet agent --waitforcert 300 --test

# Ensure that Puppet agent remains stopped after reboot.
systemctl disable puppet

# Reboot to ensure fully patched kernel, etc.
reboot
