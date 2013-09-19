A working demo of Hiera with YAML and Puppet backends.
======================================================

This demo consists of:

 * A NTP module that has defaults for pool.ntp.org servers
 * A common data module where module users can create override data in pp files
 * A YAML data source in etc/hieradb where users can override data in yaml files
 * A couple of users modules that just notify the fact that they are being included
 * In Hiera data files a key called _classes_ that decides what to include on a node

Below various usage scenarios can be tested using this module.

The examples below assume you have Hiera already installed and that you have
hiera-puppet cloned from github and running these commands in _hiera-puppet/example_ as cwd.

Module from forge with module defaults
--------------------------------------

 * Move the _modules/data_ directory to _modules/data.bak_ to avoid overrides
   used further in the example
 * Run puppet, creates _/etc/ntp.conf_ with ntp.org addresses
 * The _hiera\_include()_ function includes just _users::common_

<pre>
$ mv modules/data modules/data.bak
$ puppet apply --config etc/puppet.conf site.pp
notice: /Stage[main]/Ntp::Config/File[/tmp/ntp.conf]/ensure: defined content as '{md5}7045121976147a932a66c7671939a9ad'
notice: /Stage[main]/Users::Common/Notify[Adding users::common]/message: defined 'message' as 'Adding users::common'
$ cat /tmp/ntp.conf
server 1.pool.ntp.org
server 2.pool.ntp.org
</pre>

Site wide override data in _data::common_
-----------------------------------------

 * Restore the _modules/data_ directory that has a class _data::common_ that declares site wide overrides
 * The _hiera_include()_ function includes just _users::common_

<pre>
$ mv modules/data.bak modules/data
$ puppet apply --config etc/puppet.conf site.pp
notice: /Stage[main]/Ntp::Config/File[/tmp/ntp.conf]/content: content changed '{md5}7045121976147a932a66c7671939a9addc2' to '{md5}8f9039fe1989a278a0a8e1836acb8d23'
notice: /Stage[main]/Users::Common/Notify[Adding users::common]/message: defined 'message' as 'Adding users::common'
$ cat /tmp/ntp.conf
server ntp1.example.com
server ntp2.example.com
</pre>

Fact driven overrides for location=dc1
--------------------------------------

 * Set a fact location=dc1 that uses the YAML data in _etc/hieradb/dc1.yaml_ to override
 * Show that machines in dc2 would use site-wide defaults
 * The _hiera_include()_ function includes _users::common_ and _users::dc1_ as the data file for dc1 adds that

<pre>
$ FACTER_location=dc1 puppet apply --config etc/puppet.conf site.pp
notice: /Stage[main]/Ntp::Config/File[/tmp/ntp.conf]/content: content changed '{md5}8f9039fe1989a278a0a8e1836acb8d23' to '{md5}074d0e2ac727f6cb9afe3345d574b578'
notice: /Stage[main]/Users::Common/Notify[Adding users::common]/message: defined 'message' as 'Adding users::common'
notice: /Stage[main]/Users::Dc1/Notify[Adding users::dc1]/message: defined 'message' as 'Adding users::dc1'
$ cat /tmp/ntp.conf
server ntp1.dc1.example.com
server ntp2.dc1.example.com
</pre>

Now simulate a machine in _dc2_, because there is no data for dc2 it uses the site wide defaults and
does not include the _users::dc1_ class anymore

<pre>
$ FACTER_location=dc2 puppet apply --config etc/puppet.conf site.pp
warning: Could not find class data::dc2 for nephilim.ml.org
notice: /Stage[main]/Ntp::Config/File[/tmp/ntp.conf]/content: content changed '{md5}074d0e2ac727f6cb9afe3345d574b578' to '{md5}8f9039fe1989a278a0a8e1836acb8d23'
notice: /Stage[main]/Users::Common/Notify[Adding users::common]/message: defined 'message' as 'Adding users::common'
$ cat /tmp/ntp.conf
server ntp1.example.com
server ntp2.example.com
</pre>

You could create override data in the following places for a machine in _location=dc2_, they will be searched in this order and the first one with data will match.

 * file etc/hieradb/dc2.yaml
 * file etc/hieradb/common.yaml
 * class data::dc2
 * class data::production
 * class data::common
 * class ntp::config::data
 * class ntp::data

In this example due to the presence of _common.yaml_ that declares _ntpservers_ the classes will never be searched, it will have precedence.
