# Module 02: Puppet Key Concepts


## Task 01: Instructor Session

This task is instructor led.

### Fundamentals

* Declarative / Non-impertive
* Configuration applied as Puppet sees fit, but it also features dependency
  chains.
* Classes can be defined once per server. A defined resource can be defined
  multiple times. A good example of this would be that `apache` would be a class
  as you can only have one apache server on the machine, but each `vhost` would
  be a defined resource, since you can have multiple vhosts.
* Should create a module per technology and a module per service. `apache` and
  `mysql` are technology modules, but `s_myblog` is a service that consumes both
  technology modules in order to launch an application.
* We use the convention of prefixing module names with `s_` to indicate when a
  module is a service module, rather than a technology module.


### Terminology

| Key              | Value                                                     |
|------------------|-----------------------------------------------------------|
| Puppet Agent     | The client application that runs on each server.          |
| Puppet Master    | The master source of all Puppet manifests/config.         |
| manifest         | Puppet language files (end in `.pp`)                      |
| template         | An ERB format files that has variables completed by Puppet|
| module           | A collection of manifests and files                       |
| catalog          | A complete set of configuration for a server.             |


## Task 02: Creating a service module

We're going to use some of what we learnt to create a new service module for
our Ubuntu client server.

    ubuntu@master:~$ cd /home/myrepos
    ubuntu@master:/home/myrepos$ puppet module generate clickbait-s_client
    # Defaults are fine
    ubuntu@master:/home/myrepos$ cd s_client
    ubuntu@master:/home/myrepos/s_client$ git init && git add -A && git commit -am "initial commit"
    ubuntu@master:/home/myrepos$ addcommithook

From the above:

* We use `puppet module generate` to generate a new Puppet module with all the
  boilerplate that goes with them. Note the `clickbait-s_client` syntax - all
  modules need an author in the namespace, in our case we are using `clickbait`
  for ClickBait Enterprises Ltd.
* As we use an `r10k` workflow we create a git repo and use `addcommithook` to
  create hooks for running `r10k` upon commit. In a production environment, you
  would probably integrate with something like Github or Bitbucket's webhooks.

We now have a nice new module that does... exactly nothing. Let's add a message
to the module so we can validate it actually working.

    ubuntu@master:/home/myrepos/s_client# cat manifests/init.pp
    # ...
    class s_client {
      notify { 'My s_client module is loading!': }
    }

Once changed, save the file and commit with `git commit`. You don't need to do
`git push` during this training as we are not using an upstream repository
service.

We've now got a module that does something. But we need to tell `r10k` to deploy
this module onto the Puppet master, so let's go edit our `environments` module
and add this new `s_client` module to the Puppet file.

    ubuntu@master:/home/myrepos/s_client$ cd /home/myrepos/environments/
    ubuntu@master:/home/myrepos/environments$
    ubuntu@master:/home/myrepos/environments$ cat Puppetfile
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

    # My awesome service module!
    mod 's_client',
      :git    => '/home/myrepos/s_client/',
      :branch => 'master'

This will make the `s_client` module available from manifests, but by itself
it will do nothing. We should edit our `site.pp` file and specifically set our
server to use this module.

    ubuntu@master:/home/myrepos/environments$ cat manifests/site.pp
    # Default Node configuration
    node default {
      notify { 'Hello World!': }
    }

    # Our awesome Ubuntu client
    node client {
      include s_client
    }

Note that we have left the default node entry, but added a exact match for any
nodes called `client`. For that node, we include the `s_client` module, which
essentially results in us invoking the `s_client/manifests/init.pp` manifest.

Let's commit both the `Puppetfile` and the `manifests/site.pp` changes:

    ubuntu@master:/home/myrepos/environments$ git commit -am "Added my new service module"
    INFO   	 -> Deploying environment /etc/puppetlabs/code/environments/master
    INFO   	 -> Environment master is now at 152f2096e7ce8c46f87557af7de4c684db38c97b
    INFO   	 -> Deploying environment /etc/puppetlabs/code/environments/production
    INFO   	 -> Environment production is now at 12408db94266e58796b7de2d40b44e8df89ada6d
    INFO   	 -> Deploying environment /etc/puppetlabs/code/environments/training
    INFO   	 -> Environment training is now at 64cb3a5040e568f3212c0a4673515da0c1dd3910
    [training 64cb3a5] Added my new service module
    1 file changed, 1 insertion(+)

We should now see Puppet run on the client and produce our latest message:

    ubuntu@client:~$ sudo puppet agent --test
    Info: Using configured environment 'training'
    Info: Retrieving pluginfacts
    Info: Retrieving plugin
    Info: Loading facts
    Info: Caching catalog for client
    Info: Applying configuration version '1476244640'
    Notice: My s_client module is loading!
    Notice: /Stage[main]/S_client/Notify[My s_client module is loading!]/message: defined 'message' as 'My s_client module is loading!'
    Notice: Applied catalog in 0.07 seconds



## Task 03: My Standard Operating Environment

Most Puppet environments will have the concept of an `SOE` module, aka a module
that contains configuration common to all systems. Generally you will want to
use this module to perform tasks such as:

1. Install your preferred software packages on various systems.

2. Configure your organisation's security policy such as SSH defaults, automatic
   operating system patching, etc.

3. Preload sysadmin/operations users whom need to be present on every system in
   order to manage the fleet.

It seems the administators at Clickbait Enterprises have not been as organised
as they should have been and failed to setup such a module.

Your exercise for this task is to create an SOE module following the same
process we used just before to setup the `s_client` module. This new module
should be called `soe` (lowercase).

This time, rather than writing a message, we're going to do something more
useful and install our favorite application - `htop`, a better version of `top`.

To do this, we'll use a built-in Puppet resource (Package), which will look like
the following:

    ubuntu@master:/home/myrepos/soe$ cat manifests/init.pp
    # ...
    class soe {
      # Fix terrible package selection on our servers
      package { 'htop':
        ensure => 'installed',
      }
    }

And we'll amend our `site.pp` file to include the SOE module for all servers:

    ubuntu@master:/home/myrepos/environments$ cat manifests/site.pp
    # Default Node configuration
    node default {
      notify { 'Hello World!': }
      include soe
    }

    # Our awesome Ubuntu client
    node client {
      include soe
      include s_client
    }

Note from the above that we have to define `soe` in both the `default` node
entry and the `client` node entry. This is because nodes do not inherit default
automatically.

If you manage to configure everything correctly, you should be able to run
Puppet on the client and see a new package installed:

    ubuntu@client:~$ sudo puppet agent --test
    Info: Using configured environment 'training'
    Info: Retrieving pluginfacts
    Info: Retrieving plugin
    Info: Loading facts
    Info: Caching catalog for client
    Info: Applying configuration version '1476245785'
    Notice: My s_client module is loading!
    Notice: /Stage[main]/S_client/Notify[My s_client module is loading!]/message: defined 'message' as 'My s_client module is loading!'
    Notice: /Stage[main]/Soe/Package[htop]/ensure: created
    Notice: Applied catalog in 2.91 seconds

That package will now be available if you run `htop`. (CTL+C to terminate)


## Task 04: Adding a new server to Puppet

Actually we'd like to have all the stuff in the SOE module on our Puppet master
as well - but it's not currently setup with the puppet agent, so it's unmanaged.

We can fix this simply by doing a Puppet run on the master:

    ubuntu@master:~$ sudo puppet agent --test
    Info: Creating a new SSL key for master
    Info: csr_attributes file loading from /etc/puppetlabs/puppet/csr_attributes.yaml
    Info: Creating a new SSL certificate request for master
    Info: Certificate Request fingerprint (SHA256): A9:EF:77:8B:4D:E8:A1:EF:FD:FE:14:64:F8:8A:BF:A9:B2:8D:5A:A8:6C:8A:E1:55:2C:04:DD:21:17:2A:3B:45
    Info: Caching certificate for master
    Info: Caching certificate for master
    Info: Using configured environment 'training'
    Info: Retrieving pluginfacts
    Info: Retrieving plugin
    ...
    Info: Loading facts
    Info: Caching catalog for master
    Info: Applying configuration version '1476248362'
    Notice: Hello World!
    Notice: /Stage[main]/Main/Node[default]/Notify[Hello World!]/message: defined 'message' as 'Hello World!'
    Notice: /Stage[main]/Soe/Package[htop]/ensure: created
    Notice: Applied catalog in 3.71 seconds

Wow, a lot happened there!

1. The server automatically generated an SSL key and got it signed by the Puppet
   master process. In a production environment, we'd use pre-signed keys to
   validate identity OR require manual acceptance of new hosts on the master
   server, however we've enabled auto signing to make the training easy.

2. A large number of `facts` and `functions` were loaded onto the server when
   Puppet ran for the first time. This is because Puppet automatically copies
   the various files it finds inside the Puppet modules onto a location on disk
   where they can be executed as part of the Puppet run.



## Resources

The following detail key aspects of the Puppet DSL:

* Puppet classes (which can be used once per catalog):
  https://docs.puppet.com/puppet/4.7/reference/lang_classes.html

* Puppet defined resources (which can be used many times per catalog):
  https://docs.puppet.com/puppet/4.7/reference/lang_defined_types.html


The following are very useful resources to help you in your Puppet adventures.

* List of all Puppet resource types that can be used, and their various
  parameters and limitations.
  https://docs.puppet.com/puppet/latest/reference/type.html

* List of all built-in Puppet functions that can be used:
  https://docs.puppet.com/puppet/latest/reference/function.html

* Not amused by a small list of functions? Take advantage of all the extra ones
  shipped in the `stdlib` module:
  https://forge.puppet.com/puppetlabs/stdlib

* Information about what built-in Facts are available:
  https://docs.puppet.com/puppet/latest/reference/lang_facts_and_builtin_vars.html
