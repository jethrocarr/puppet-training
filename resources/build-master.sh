#!/bin/bash
#
# Provision a Puppet master with PuppetDB for training purposes. This script
# is simplistic in nature to provide the functionality needed for training
# purposes only and is not recommended for real-world production Puppet master
# builds.

# Set hostname
HOSTNAME=master
hostname ${HOSTNAME}
echo ${HOSTNAME} > /etc/hostname
echo "127.0.0.1 ${HOSTNAME}" >> /etc/hosts

# Prevent SSH timeout
echo "ClientAliveInterval 180" >> /etc/ssh/sshd_config

# Update operating system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y dist-upgrade

# Install upstream Puppetlabs version. We want to be training on the latest
# version, Puppet 4 made life a lot easier in many ways.
wget -O /tmp/puppetlabs-release.deb https://apt.puppetlabs.com/puppetlabs-release-pc1-`lsb_release -sc`.deb
dpkg -i /tmp/puppetlabs-release.deb
apt-get update
apt-get -y install puppetserver

# Symlink the Puppet binaries to match the OSS installation
update-alternatives --install /usr/bin/puppet puppet /opt/puppetlabs/bin/puppet 1
update-alternatives --install /usr/bin/facter facter /opt/puppetlabs/bin/facter 1
update-alternatives --install /usr/bin/hiera hiera /opt/puppetlabs/bin/hiera 1
update-alternatives --install /usr/bin/mco mco /opt/puppetlabs/bin/mco 1

# By default Puppet Server runs with 2GB of RAM, bit oversized for a 2-box
# training environment, so let's knock that down and allow ourselves to use
# smaller AWS instances.
sed -i 's/-Xms2g -Xmx2g/-Xms512m -Xmx512m/g' /etc/default/puppetserver

# Enable autosigning of Puppet clients. Now this can be dangerous if you aren't
# careful, but in our case only the client in our network has network access to
# request a signed cert. This is DANGEROUS in a real environment.
echo "autosign = true" >> /etc/puppetlabs/puppet/puppet.conf

# We use the r10k workflow, install the Ruby gem. Note that this will install
# on a different Ruby than the one shipped with Puppet server, but we don't
# particularly worry about that since we're not linking with it, just running
# r10k as a standalone process.
apt-get -y install ruby ruby-dev zlib1g-dev libxml2-dev gcc make patch gnupg2 git
gem install r10k

mkdir -p /etc/puppetlabs/r10k/
cat > /etc/puppetlabs/r10k/r10k.yaml << EOF
# The location to use for storing cached Git repos
:cachedir: '/opt/puppetlabs/r10k/cache'

# A list of git repositories to create
:sources:
  # This will clone the git repository and instantiate an environment per
  # branch in /etc/puppetlabs/code/environments
  :environments:
    remote: '/home/myrepos/environments'
    basedir: '/etc/puppetlabs/code/environments'
EOF

# We need to build a Puppet r10k git workflow using local repos rather than
# remotes on Github or Bitbucket to keep things simple.
mkdir -p /home/myrepos
cat > /home/myrepos/README << EOF
Normally you'd have all your Puppet code living in a git service like Github,
Bitbucket or Gitlab, however for training purposes we're using local Git repos
on disk.

Just think of each directory under /home/myrepos/ as being a seporate Github
repo, so to list all your repos, do:

    ls -1 /home/myrepos
EOF

mkdir -p /home/myrepos/environments
cd /home/myrepos/environments

# I especially love how git refuses to run without this >:-(
export HOME=/root
git config --global user.email "trainingbot@example.com"
git config --global user.name "Trainingbot 9000"

# Create new repo
git init
echo "master branch is unused, use the per env branches" > README.txt
git add .
git commit -am "Seeded master branch"

# Create a production branch otherwise Puppet server can't start up (!!)
git branch production
git checkout production
echo "Currently unused" > README.txt
git commit -am "Seeded production branch"

# Create training environment branch
git checkout master
git branch training
git checkout training
echo "Our default branch for training" > README.txt
git commit -am "Seeded training branch"

# Generate Puppetfile
cat >> Puppetfile << EOF
# This is a Puppetfile. It is used by r10k to collate multiple repos and
# dependencies together to form a single application.
# https://github.com/puppetlabs/r10k
forge 'forge.puppetlabs.com'

# Core Puppetlabs Modules needed by various dependencies
mod 'puppetlabs/stdlib'
mod 'puppetlabs/ruby'
mod 'puppetlabs/gcc'
mod 'puppetlabs/inifile'
mod 'puppetlabs/vcsrepo'
mod 'puppetlabs/git'

EOF
git add Puppetfile
git commit -am "Added the Puppetfile"

# Generate a default site.pp file
mkdir manifests
cat >> manifests/site.pp << EOF
# Default Node configuration
node default {
  notify { 'Puppet is configured and using the training environment': }
}
EOF
git add manifests
git commit -am "Seed the site.pp with a default node"


# Grant ownership to training user
chown -R ubuntu:ubuntu /home/myrepos
chmod 700 /home/myrepos

# This is some evilness - we create a tool that sets up commit hooks that
# triggers r10k for any commit in the repo.
cat > /usr/local/bin/addcommithook << EOF
#!/bin/bash
# Write commit hook for r10k
cat > .git/hooks/post-commit << END1
# Trigger an r10k run upon commit
exec sudo r10k deploy environment -p --verbose info
END1
chmod 755 .git/hooks/post-commit
EOF
chmod 755 /usr/local/bin/addcommithook

# Setup commit hook for our main environments repo (cwd)
/usr/local/bin/addcommithook

# Deploy with r10k.
r10k deploy environment -p --verbose debug

# Setup better syntax handling in Vim out-of-the-box
# TODO: Not totally happy with this, autoindent not working right for example.
apt-get -y install vim-puppet vim-tabular
vim-addons install puppet
vim-addons install tabular
cat > ~/.vimrc << EOF
set shiftwidth=2
set tabstop=2
set softtabstop=2
set expandtab
set smartindent
EOF

# Ensure that post-reboot, the Puppet server will start. As soon as that happens
# the client servers will connect in and do their first Puppet run.
systemctl enable puppetserver

# Ensure that Puppet agent remains stopped after reboot. We don't want it
# running on the master since it can lead to things breaking. Seems the agent
# creates bad certs waiting for them to be signed and the master then refuses
# to launch until the certs are signed... which naturally leads to some issues.
systemctl disable puppet

# Configure everything we need for the Puppet agent so that it's ready for us
# to enable in future as part of our exercises.
echo "127.0.0.1 puppet" >> /etc/hosts
cat >> /etc/puppetlabs/puppet/puppet.conf << EOF
[main]
  certname = ${HOSTNAME}
  environment = training
EOF

# Reboot to ensure fully patched kernel, etc.
reboot
