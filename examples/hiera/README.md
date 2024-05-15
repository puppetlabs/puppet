A working demo of Hiera with YAML backend.
======================================================

This demo consists of:

- A **NTP** module that has defaults for *pool.ntp.org* servers
- A **YAML** data source in the *data/* directory where users can override data in yaml files
- A **Users** module that has a few manifests that simply notify that they are being included
- In Hiera data files a key called **classes** that decides what to include on a node

Below various usage scenarios can be tested using this module.

The examples below assume you:
- Have the puppet-agent already installed
- You have this repository cloned from github
- Are running these commands from within the *examples/hiera* directory as cwd.

Module from forge with module defaults
--------------------------------------

- Comment out lines 6-8 of [data/common.yaml](data/common.yaml#L6-8) to avoid overrides used further in the example
- Run a `puppet apply` to create a */tmp/ntp.conf* file containing the two *pool.ntp.org* addresses
- The *users::common* class should also be present in your catalog

```shell
$ sed -i '6,8 s/^/#/' data/common.yaml
$ puppet apply site.pp --hiera_config=hiera.yaml --modulepath=modules
Notice: Compiled catalog for node.corp.com in environment production in 0.04 seconds
Notice: Adding users::common
Notice: /Stage[main]/Users::Common/Notify[Adding users::common]/message: defined 'message' as 'Adding users::common'
Notice: /Stage[main]/Ntp::Config/File[/tmp/ntp.conf]/ensure: defined content as '{sha256}949c7247dbe0870258c921418cc8b270afcc57e1aa6f9d9933f306009ede60d0'
Notice: Applied catalog in 0.02 seconds
$ cat /tmp/ntp.conf
server 1.pool.ntp.org
server 2.pool.ntp.org
```

Site wide override data in _data::common_
-----------------------------------------

- Remove the comments on lines 6-8 of [data/common.yaml](data/common.yaml#L6-8)
- Run a `puppet apply` to update */tmp/ntp.conf* to contain the two *ntp.example.com* addresses
- The *users::common* class should also be present in your catalog

```shell
$ sed -i '6,8 s/^#//' data/common.yaml
$ puppet apply site.pp --hiera_config=hiera.yaml --modulepath=modules
Notice: Compiled catalog for node.corp.com in environment production in 0.04 seconds
Notice: Adding users::common
Notice: /Stage[main]/Users::Common/Notify[Adding users::common]/message: defined 'message' as 'Adding users::common'
Notice: /Stage[main]/Ntp::Config/File[/tmp/ntp.conf]/content: content changed '{sha256}949c7247dbe0870258c921418cc8b270afcc57e1aa6f9d9933f306009ede60d0' to '{sha256}28ced955a8ed9efd7514b2364fe378ba645ab947f26e8c0b4d84e8368f1257a0'
Notice: Applied catalog in 0.02 seconds
$ cat /tmp/ntp.conf
server ntp1.example.com
server ntp2.example.com
```

Fact driven overrides for location=dc1
--------------------------------------

- Override the location fact to `dc1` to demonstrate *data/dc1.yaml* overrides the *ntp::config::ntpservers* values in *data/common.yaml*
- `dc1` nodes will
  - have the *users::common* and *users::dc1* in their catalogs
  - */tmp/ntp.conf* will contain the two *ntp.dc1.example.com* addresses
- Show that the nodes in `dc2` would use the site-wide defaults

```shell
$ FACTER_location=dc1 puppet apply site.pp --hiera_config=hiera.yaml --modulepath=modules
Notice: Compiled catalog for node.corp.com in environment production in 0.04 seconds
Notice: Adding users::dc1
Notice: /Stage[main]/Users::Dc1/Notify[Adding users::dc1]/message: defined 'message' as 'Adding users::dc1'
Notice: Adding users::common
Notice: /Stage[main]/Users::Common/Notify[Adding users::common]/message: defined 'message' as 'Adding users::common'
Notice: /Stage[main]/Ntp::Config/File[/tmp/ntp.conf]/content: content changed '{sha256}28ced955a8ed9efd7514b2364fe378ba645ab947f26e8c0b4d84e8368f1257a0' to '{sha256}39227f1cf8d09623d2e66b6622af2e8db01ab26f77a5a2e6d6e058d0977f369b'
Notice: Applied catalog in 0.02 seconds
$ cat /tmp/ntp.conf
server ntp1.dc1.example.com
server ntp2.dc1.example.com
```

Now simulate a machine in `dc2`, because there is no data for `dc2` it uses the site wide defaults and
does not include the *users::dc1* class anymore

```shell
$ FACTER_location=dc2 puppet apply site.pp --hiera_config=hiera.yaml --modulepath=modules
Notice: Compiled catalog for node.corp.com in environment production in 0.04 seconds
Notice: Adding users::common
Notice: /Stage[main]/Users::Common/Notify[Adding users::common]/message: defined 'message' as 'Adding users::common'
Notice: /Stage[main]/Ntp::Config/File[/tmp/ntp.conf]/content: content changed '{sha256}39227f1cf8d09623d2e66b6622af2e8db01ab26f77a5a2e6d6e058d0977f369b' to '{sha256}28ced955a8ed9efd7514b2364fe378ba645ab947f26e8c0b4d84e8368f1257a0'
Notice: Applied catalog in 0.02 seconds
$ cat /tmp/ntp.conf
server ntp1.example.com
server ntp2.example.com
```

You could create override data in the following places for a machine in *location=dc2*, they will be searched in this order and the first one with data will match.

- file data/dc2.yaml
- file data/&lt;environment&gt;.yaml
- file data/common.yaml

In this example due to the presence of *common.yaml* that declares *ntpservers* the classes will never be searched, it will have precedence.
