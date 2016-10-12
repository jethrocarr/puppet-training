# Module 04: Hiera

## Task 01: Instructor Session

This task is instructor led.


## Task 02: Setting our MOTD horoscope with hiera

In our last module we introduced the `$horoscope` parameter to our `soe` class.
We thought it was fine (works in dev?) but seems some users feel this is overly
depressing and require something more cheerful.

Let's go and create a common Hiera file that applies to all servers:

    ubuntu@master:~$ cd /home/myrepos/environments/
    ubuntu@master:/home/myrepos/environments$ mkdir hieradata
    ubuntu@master:/home/myrepos/environments$ vim hieradata/common.yaml
    ---
    soe::horoscope: 'Nobody will ever love you as much as your computer'

    ubuntu@master:/home/myrepos/environments$ git add hieradata/common.yaml
    ubuntu@master:/home/myrepos/environments$ git commit -am "Added new horoscope in Hiera override"

Let's see if that worked:

    ubuntu@client:~$ sudo puppet agent --test
    --- /etc/update-motd.d/99-puppetftw	2016-10-12 10:33:13.927984669 +0000
    +++ /tmp/puppet-file20161012-8460-ttabgo	2016-10-12 10:46:02.844391163 +0000
    @@ -1,4 +1,4 @@
     #!/bin/bash
     echo "MY SERVER IS THE BEST SERVER"
    -echo "Today's Horoscope is: You will die a horrible horrible death"
    +echo "Today's Horoscope is: Nobody will ever love you as much as your computer"
    Info: Computing checksum on file /etc/update-motd.d/99-puppetftw


## Task 03: Using the hierarachy
