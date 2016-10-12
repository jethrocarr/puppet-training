# Puppet Training

This module provides a stack for launching Puppet training environments for
teaching people about Puppet module development.

It provides a stack that can be launched per-user to give them a Puppet master
and a Puppet client for learning the Puppet DSL, the r10k workflow and other
good Puppet skills.

We specifically consider the setup of a Puppet master/server and PuppetDB
out-of-scope, this topic is better covered by the Puppetlabs documentation as
the configuration can be complex and varies a lot per environment.


# Features

* Fully automatic provisioning.
* Support for AWS via CloudFormation.
* Ubuntu 16.04 with Puppet 4.
* Creates Puppet master plus node for testing Puppet modules on.
* Sets up r10k workflow.


# Expected Knowledge

Staff under taking this training must be:

1. Reasonably comfortable with a command line Linux environment.

2. Understand how to use tools like Git and text editors.


# Training Materials

All the training materials are located inside the `modules` directory. The
various modules are numbered sequentially and should be followed in that order.

Before starting the modules, make sure you have provisioned a stack per-user
and validated correct operation of the environment.


# Can I use this for provisioning a real production environment?

No. In order to meet the requirements of a simple, easy to setup and use
training environment we've made certain design decisions that would be stupid
in a real world environment. Use this project for what is is, a chance to learn
Puppet's DSL and how a master-full Puppet environment behaves like, but once
done move on and build some proper infrastructure.


# Stack Provisioning

For all users:

1. Setup an Amazon Web Services (AWS) account if you have not already.

2. Provision a VPC. This can be a NAT-based VPC, where the instances will remain
   hidden from the public internet, or you can use a VPC with IGW as long as the
   subnet you provide is set to auto-assign public IP space. Note that this will
   expose the training VMs to the public web, which means port `22` and port
   `80` could be reached by untrustworthy parties.


For each member taking part in training:

1. Create a Key Pair for each user taking part in the training.

2. Launch the environment using the `stack.yaml` file. For example:
    ```
    aws --profile sandbox \
    cloudformation \
    create-stack \
    --stack-name "puppet-training-bob" \
    --template-body file://resources/stack.yaml \
    --capabilities CAPABILITY_IAM \
    --parameters \
    ParameterKey=KeyName,ParameterValue=MyKey \
    ParameterKey=VpcId,ParameterValue=vpc-xyz123 \
    ParameterKey=SubnetId,ParameterValue=subnet-xyz
    ```
    The stack launches the servers used for training and pulls down user data
    located inside this repo to provision the servers.


# Troubleshooting



# Contributions

Contributions are always welcome. Note that the scope of this project is Puppet
training and PRs are evaluated on whether or not they meet that goal.


# License

The content in this repo is licensed under the Apache License, Version 2.0
(the "License"). See the LICENSE.txt or http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
