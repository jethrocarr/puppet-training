# Puppet Training

This module provides a stack for launching Puppet training environments for
teaching people about Puppet.

It provides a stack that should be launched per-user that gives them a
functional Puppet Master, as well as a client server that can be used to apply
the Puppet modules onto.

# Expected Knowledge

Staff under taking this training must be:

1. Reasonably comfortable with a command line Linux environment.

2. Understand how to use tools like Git and text editors.


# Stack Provisioning

For all users:

1. Setup an Amazon Web Services (AWS) account if you have not already.

2. Provision a VPC with routable networking. This is because our stack is VPC
   based and will be unreachable without a proper configured VPC. This is an
   intentional security step, to avoid building publicly reachable systems
   that could be insecurely configured by training staff.
   TODO: Ship a seed VPC stack for new users?


For each member taking part in training:

1. Create a Key Pair for each user taking part in the training.

2. launch the environment using the `stack.yaml` file. For example:


    aws --profile sandbox \
    cloudformation \
    create-stack \
    --stack-name "puppet-training-bob" \
    --template-body file://stack.yaml \
    --parameters \
    ParameterKey=KeyName,ParameterValue=MyKey \
    ParameterKey=VpcId,ParameterValue=vpc-xyz123 \
    ParameterKey=SubnetId,ParameterValue=subnet-xyz
