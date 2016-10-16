# Module 03: Puppet Key Concepts


## Task 01: Instructor Session

This task is instructor led.

### Fundamentals

* Declarative / Non-imperative
* Whilst a DSL ontop of Ruby, different syntax to Ruby.
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

    ssh ubuntu@$PUPPETMASTER
    
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
* As we use an `r10k` workflow we create a git repo and use a helper program we
  wrote called `addcommithook` to create hooks for running `r10k` upon commit.
  In a production environment, you would probably integrate with something like
  Github or Bitbucket's webhook, rather than hooking on a user's repo.


We now have a nice new module that does... exactly nothing. Let's add a message
to the module so we can validate it actually working.

    ubuntu@master:/home/myrepos/s_client# vim manifests/init.pp
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
    ubuntu@master:/home/myrepos/environments$ vim Puppetfile
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

    ubuntu@master:/home/myrepos/environments$ vim manifests/site.pp
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

    ssh ubuntu@$PUPPETCLIENT
    
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

    ubuntu@master:/home/myrepos/soe$ vim manifests/init.pp
    # ...
    class soe {
      # Fix terrible package selection on our servers
      package { 'htop':
        ensure => 'installed',
      }
    }

And we'll amend our `site.pp` file to include the SOE module for all servers:

    ubuntu@master:/home/myrepos/environments$ vim manifests/site.pp
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


## Task 05: Adding more packages to SOE.

Turns out we have a corporate policy at Clickbait Enterprise Ltd to ensure that
`emacs` and `vsftpd` are also installed on every server. We need to amend our
`soe` module.

Now we could be silly and do it this way:

    ubuntu@master:/home/myrepos/soe$ vim manifests/init.pp
    # ...
    class soe {
      # Fix terrible package selection on our servers
      package { 'htop':
        ensure => 'installed',
      }
      package { 'emacs':
        ensure => 'installed',
      }
      package { 'vsftpd':
        ensure => 'installed',
      }
    }

Or we can take advantage of the fact that Puppet accepts an array/list as the
name of any resource definition, and do something smarter:

    ubuntu@master:/home/myrepos/soe$ vim manifests/init.pp
    # ...
    class soe {
      # Fix terrible package selection on our servers
      package { ['htop', 'emacs', 'vsftpd']:
        ensure => 'installed',
      }
    }

Let's commit our change on the master:

    ubuntu@master:/home/myrepos/soe$ git commit -am "Added awesome extra packages"

And then run Puppet on the client:

    ubuntu@client:~$ sudo puppet agent --test

Did you notice it taking a particularly long time where it seemed to do nothing
around here?

    Notice: /Stage[main]/S_client/Notify[my s_client module is loading!]...
    <---- slowness here?
    Notice: /Stage[main]/Soe/Package[emacs]/ensure: created
    Notice: /Stage[main]/Soe/Package[vsftpd]/ensure: created
    Notice: Applied catalog in 63.42 seconds

This is because Puppet runs log the output of a task after it has been executed.
In the case of these commands, we had to wait for Ubuntu to download and install
not only the two new packages, but all their dependencies in the background.

If you `tail` the `dpkg` log, you can get an idea of the number of dependencies
that got installed:

    ubuntu@client:~$ tail -n100 /var/log/dpkg.log

Let's not leave the Puppet master itself left out - we want our nice `soe`
package everywhere!

    ubuntu@master:/home/myrepos/soe$ sudo puppet agent --test
    Info: Using configured environment 'training'
    Info: Retrieving pluginfacts
    Info: Retrieving plugin
    Info: Loading facts
    Info: Caching catalog for master
    Info: Applying configuration version '1476265258'
    Notice: Hello World
    Notice: /Stage[main]/Main/Node[default]/Notify[Hello World]/message: defined 'message' as 'Hello World'
    Notice: /Stage[main]/Soe/Package[emacs]/ensure: created
    Notice: /Stage[main]/Soe/Package[vsftpd]/ensure: created
    Notice: Applied catalog in 81.05 seconds


## Task 06: Non-native Packages

This is all well and good - but what about non-native packages? Things like
Ruby, NPM or Python packages? The good news, is that many Puppet resources
such as `package` can have different providers available for use. And in the
case of `package`, the OS package manager is just the default.

Let's install `bundler`, a Ruby package for managing dependencies inside other
Ruby packages. Bundler is available via the Ruby Gems service and we can add it
by adjusting the `manifests/init.pp` in our `soe` module.

    ubuntu@master:/home/myrepos/soe$ vim manifests/init.pp
    # ...
    class soe {
      # Fix terrible package selection on our servers
      package { ['htop', 'emacs', 'vsftpd']:
        ensure => 'installed',
      }

      # Ruby Bundler!
      package { 'bundler':
        ensure    => 'latest',
        provider => 'gem'
      }
    }

Note that we use `ensure => latest` here. As a hip cool agile company, ClickBait
Enterprises Ltd needs to adopt the latest and greatest Ruby programs as soon as
possible. This directive will ensure that Puppet will upgrade bundler if a newer
version ever becomes available.

Let's do the commit & run dance - this will get pretty routine when working with
Puppet modules.

    ubuntu@master:/home/myrepos/soe$ git commit -am "Ruby in the sky without diamonds"

    ubuntu@client:~$ sudo puppet agent --test

Oh no, it failed!

    Error: /Stage[main]/Soe/Package[bundler]: Provider gem is not functional on this host

Whilst Puppet ships with lots of providers, it can only use providers if the
software that providers that underlying functionality is installed.
Unfortunately Puppet is not smart enough to go and install everything we need
automatically.

Let's fix it by adding the `ruby` package (that provides `gem`) to our `soe`
module and trying again.

    ubuntu@master:/home/myrepos/soe$ vim manifests/init.pp
    # ...
    class soe {
      # Fix terrible package selection on our servers
      package { ['htop', 'emacs', 'vsftpd', 'ruby']:
        ensure => 'installed',
      }

      # Ruby Bundler!
      package { 'bundler':
        ensure    => 'latest',
        provider => 'gem',
        require  => Package['ruby'],
      }
    }

We've also just introduced another key bit of Puppet's DSL - dependencies.
Because of the fact that Puppet is declarative, ordering is not predictable.
However it's important that `ruby` is available before we try to use the `gem`
provider otherwise things could break - and so we tell Puppet that package
`bundler` requires package `ruby`.

Note that when defining a resource, the case is always lower - eg `file`,
`package`, `something::custom`. However when referring to a resource, the first
letter is always upper case, eg `File`, `Package`, `Something::Custom`.


And the commit dance:

    ubuntu@master:/home/myrepos/soe$ git commit -am "Guess this is the diamonds we needed?"

    ubuntu@client:~$ sudo puppet agent --test

This time, the Puppet run should succeed and we get the OS-native `ruby` package
installed, but also the Ruby/Gem based `bundler` package:

    Notice: /Stage[main]/Soe/Package[ruby]/ensure: created
    Notice: /Stage[main]/Soe/Package[bundler]/ensure: created

    ubuntu@client:~$ gem list | grep bundler
    bundler (1.13.3)


## Task 07: Removing a Resource

Whoops! Turns out some idiot wrote this tutorial whom was still stuck in 1990
and it turns out we don't use `vsftpd` for file transfers any more - we're
modern and use SSH. How embarrassing for ClickBait Enterprises Ltd! We need to
get rid of this right away before it shows up in some pentests and makes us a
laughing stock of the internet community!

We better remove it from the `soe` module:

    ubuntu@master:/home/myrepos/soe$ vim manifests/init.pp
    # ...
    class soe {
      # Fix terrible package selection on our servers
      package { ['htop', 'emacs', 'ruby']:
        ensure => 'installed',
      }

      # Ruby Bundler!
      package { 'bundler':
        ensure    => 'latest',
        provider => 'gem',
        require  => Package['ruby'],
      }
    }

Commit & Apply:

    ubuntu@master:/home/myrepos/soe$ git commit -am "Begone ye shameful daemon"

    ubuntu@client:~$ sudo puppet agent --test

Hmm that can't be right - Puppet didn't do anything?

    ubuntu@client:~$ sudo puppet agent --test
    Info: Using configured environment 'training'
    Info: Retrieving pluginfacts
    Info: Retrieving plugin
    Info: Loading facts
    Info: Caching catalog for client
    Info: Applying configuration version '1476262092'
    Notice: my s_client module is loading!
    Notice: /Stage[main]/S_client/Notify[my s_client module is loading!]/message: defined 'message' as 'my s_client module is loading!'
    Notice: Applied catalog in 0.85 seconds
    ubuntu@client:~$

This is one of the fun traps of Puppet - whilst it's DSL is essentially a
declaration of the state that you want the system to be in, it does not purge
undefined resources by default.

We need to explicitly ensure the unwanted package is purged from the server
fleet by adding an `ensure => absent`.

    ubuntu@master:/home/myrepos/soe$ vim manifests/init.pp
    # ...
    class soe {
      # Fix terrible package selection on our servers
      package { ['htop', 'emacs', 'ruby']:
        ensure => 'installed',
      }

      # Begone shameful FTP
      service { 'vsftpd':
        ensure => stopped
      } ->
      package { 'vsftpd':
        ensure => absent
      }
      ...

The above introduces some key concepts:

1. When removing a package that provides a system service (such as `vsftpd`)
   whilst the OS *should* stop the service, that isn't always the case depending
   on how well it was packaged. It's best to always ensure it's stopped first
   ourselves to avoid surprise services running in the background...

2. We use a funny arrow above (`->`) to define ordering - this can sometimes be
   cleaner than heaps of `require` or `before` statements to define a sequence
   of resources that must be applied in a specific order.

Let's try it out:

    ubuntu@master:/home/myrepos/soe$ git commit -am "I really mean it this time, get lost FTP"

    ubuntu@client:~$ ps aux | grep [v]sftpd
    root      6143  0.0  0.2  24044  2348 ?        Ss   08:21   0:00 /usr/sbin/vsftpd /etc/vsftpd.conf

    ubuntu@client:~$ sudo puppet agent --test
    Notice: /Stage[main]/Soe/Service[vsftpd]/ensure: ensure changed 'running' to 'stopped'
    Notice: /Stage[main]/Soe/Package[vsftpd]/ensure: removed

    ubuntu@client:~$ ps aux | grep [v]sftpd
    ubuntu@client:~$

Phew! The stain of the 90s is flushed from the servers and we can relax once
more.


## Task 08: Conditionals & Facts

We've been informed that the grumpy sysadmin whom maintains the Puppet master
is a bit of a `vim` fan, and uh, may not appreciate `emacs` being installed on
this machine.

We need a way to make conditional decisions inside Puppet - and fast! Based on
her slack messages, she's downstairs getting coffee right now!

Let's quickly hack a fix into our `soe` module:

    ubuntu@master:/home/myrepos/soe$ vim manifests/init.pp
    # ...
    class soe {

      # Fix terrible package selection on our servers
      package { ['htop', 'ruby']:
        ensure => 'installed',
      }

      # Treat emacs with care! The BOFH's vengeance goes far
      if ($::hostname == "master") {
        package { 'emacs':
          ensure => 'absent',
        }
      } else {
        package { 'emacs':
          ensure => 'installed',
        }
      }

      ...

What's that weird `$::hostname` syntax? This indicates the use of a variable
provided by `facter`. This is built-in with Puppet and is vital for making
intelligent per-server decisions, rather than blindly applying configuration
regardless whether or not it is appropiate.

Take a look at all the built in facts on your server by running:

    ubuntu@client:~$ sudo facter -p --show-legacy

Facts are useful for decision making inside your modules. Common uses are:

1. Adjusting the specific behavior for different distributions (eg package
   or service names). See the `os` fact.

2. Adjusting configured based on system resources (eg allocating JVM specific
   heap sizes based on the free memory of the system). See `memory` fact.

3. Determining which platform/cloud provider a system is running on and
   installing the appropiate support utilities.

The `facter` program doesn't have to be Puppet exclusive either. Sometimes it
can be handy to get values for bash scripts, eg:

    ubuntu@client:~$ PRIMARY_IP=`sudo facter -p --show-legacy ipaddress`
    ubuntu@client:~$ echo $PRIMARY_IP

Let's try it out. Let's commit on the Puppet master and also run Puppet on the
master as well.

    ubuntu@master:/home/myrepos/soe$ git commit -am "crap crap crap she has a crossbow"
    ubuntu@master:/home/myrepos/soe$ sudo puppet agent --test
    Info: Using configured environment 'training'
    Info: Retrieving pluginfacts
    Info: Retrieving plugin
    Info: Loading facts
    Info: Caching catalog for master
    Info: Applying configuration version '1476265496'
    Notice: Hello World
    Notice: /Stage[main]/Main/Node[default]/Notify[Hello World]/message: defined 'message' as 'Hello World'
    Notice: /Stage[main]/Soe/Service[vsftpd]/ensure: ensure changed 'running' to 'stopped'
    Notice: /Stage[main]/Soe/Package[vsftpd]/ensure: removed
    Notice: /Stage[main]/Soe/Package[emacs]/ensure: removed
    Notice: Applied catalog in 3.16 seconds

Wow what happened here? Well we haven't run the Puppet agent on the master in
quite a while and Puppet does not forget - it knows the server state no longer
reflects our desired state and brings it inline by purging `emacs`, as well as
applying the vsftpd changes we made in the past.

What about the client server? We still want `emacs` there...

    ubuntu@client:~$ sudo puppet agent --test
    Info: Using configured environment 'training'
    Info: Retrieving pluginfacts
    Info: Retrieving plugin
    Info: Loading facts
    Info: Caching catalog for client
    Info: Applying configuration version '1476265697'
    Notice: my s_client module is loading!
    Notice: /Stage[main]/S_client/Notify[my s_client module is loading!]/message: defined 'message' as 'my s_client module is loading!'
    Notice: Applied catalog in 0.88 seconds

Nothing happened - but that's because we already have it installed, so there's
nothing to do.

    ubuntu@client:~$ dpkg -s emacs | grep Status
    Status: install ok installed


## Task 09: Dropping Files

Currently our servers have some rather dull Ubuntu messages when we login in
the MOTD. Let's drop some additions to liven things up.

First let's create a template file. These are files that can be dropped as-is,
or can include dynamic logic to adjust the file contents based on various logic.

    ubuntu@master:/home/myrepos/soe$ mkdir templates
    ubuntu@master:/home/myrepos/soe$ vim templates/motd.erb
    #!/bin/bash
    echo "MY SERVER IS THE BEST SERVER"

Now let's define a file resource in our `soe` class that uses this template.

    ubuntu@master:/home/myrepos/soe$ vim manifests/init.pp
    # ...
    class soe {
      ...
      file { '/etc/update-motd.d/99-puppetftw':
        ensure  => file,
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        content => template("soe/motd.erb")
      }
      ...
    }

And we commit the changes- don't forget to add the new file!

    ubuntu@master:/home/myrepos/soe$ git add templates/motd.erb
    ubuntu@master:/home/myrepos/soe$ git commit -am "Added custom MOTD"

Now let's try it out on the client:

    ubuntu@client:~$ sudo puppet agent --test
    Notice: /Stage[main]/Soe/File[/etc/update-motd.d/99-puppetftw]/ensure: defined content as '{md5}af0ae8bdbce026888ce1347233a1eeab'

To validate success, try logging in with a new session:

    $ ssh ubuntu@client
    ...
    MY SERVER IS THE BEST SERVER
    Last login: Wed Oct 12 07:56:43 2016 from 203.86.201.9
    ubuntu@client:~$

Note that in the above example, we've used a Puppet `template` to drop what is
currently a static file. Puppet frowns on this and prefers that you use the file
functionality offered for static files which is higher performance. However it
is the recommendation of the author that you should only ever be dropping config
which is almost always going to be templated and instead pull purely static
files from a service like S3 or in the form of an OS package. This is especially
important for large files (eg JRE/JDK installers) which should not be living in
Git.


## Task 10: Params & ERB Templates

Let's give our MOTD template something to deploy by adding a parameter to our
`soe` class:

    ubuntu@master:/home/myrepos/soe$ vim manifests/init.pp
    ...
    class soe (
      $horoscope = 'You will die a horrible horrible death'
    ) {
    ...

We can then reference this variable inside the template, like the following:

    ubuntu@master:/home/myrepos/soe$ vim templates/motd.erb
    #!/bin/bash
    echo "MY SERVER IS THE BEST SERVER"
    echo "Today's Horoscope is: <%= @horoscope %>"

The template follows the ERB format which is annoyingly different to the style
of Puppet's DSL, the most obvious difference being the use of `@` vs `$` for
variable names.
https://docs.puppet.com/puppet/4.7/reference/lang_template_erb.html

Let's commit both the `manifest` and the `template` change with:

    ubuntu@master:/home/myrepos/soe$ git commit -am "Now 10% more clickbaity"

And execute on the client:

    ubuntu@client:~$ sudo puppet agent --test
    Notice: /Stage[main]/Soe/File[/etc/update-motd.d/99-puppetftw]/content:
    --- /etc/update-motd.d/99-puppetftw	2016-10-12 10:12:22.312925955 +0000
    +++ /tmp/puppet-file20161012-8360-1y07vh	2016-10-12 10:33:13.895985475 +0000
    @@ -1,2 +1,4 @@
     #!/bin/bash
     echo "MY SERVER IS THE BEST SERVER"
    +echo "Today's Horoscope is: You will die a horrible horrible death"
    +
    Info: Computing checksum on file /etc/update-motd.d/99-puppetftw
    Info: /Stage[main]/Soe/File[/etc/update-motd.d/99-puppetftw]: Filebucketed /etc/update-motd.d/99-puppetftw to puppet with sum af0ae8bdbce026888ce1347233a1eeab
    Notice: /Stage[main]/Soe/File[/etc/update-motd.d/99-puppetftw]/content: content changed '{md5}af0ae8bdbce026888ce1347233a1eeab' to '{md5}1f9f0ed8f8a25d8fdccadf4314843b85'

We can see here that Puppet has taken the param from the `soe` class and
inserted it into the ERB template.



## Homework

* Puppet can be configured to automatically purge resources it doesn't manage
  with some provider types. Have a look at how you can purge a directory of any
  files not explicitly managed by Puppet.
  https://docs.puppet.com/puppet/latest/reference/types/file.html#file-attribute-purge
  https://groups.google.com/forum/#!topic/puppet-users/uqL74rXdDn0   

* What other ways can dependencies be defined? Can you require an entire module?
  https://docs.puppet.com/puppet/latest/reference/lang_relationships.html

* Have a look at a public example `soe` modules - what are some things you might
  wish to consider for your own Puppet soe module?
  https://github.com/jethrocarr/puppet-soe

* How complex is it to write your own fact? Have a look at an example and some
  docs:
  https://github.com/jethrocarr/puppet-digitalocean
  https://docs.puppet.com/facter/latest/custom_facts.html



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



## Credit

The author of this tutorial would like to thank the `vsftpd` team for a really
useful daemon for all the times he has had to deal with providing FTP for legacy
platforms.
