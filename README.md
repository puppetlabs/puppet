What?
=====

A data backend for Hiera that can query the internal Puppet
scope for data.  The data structure and approach is heavily
based on work by Nigel Kersten but made more configurable and
with full hierarchy.

It also includes a Puppet function that works like extlookup()
but uses the Hiera backends.

Usage?
======

Hiera supports the concept of chaining backends together in order,
using this we can create a very solid module author/module user
experience.

Module Author
-------------

A module author wants to create a configurable module that has sane
defaults but want to retain the ability for users to configure it.

We'll use a simple NTP config class as an example.

<pre>
class ntp::config($ntpservers = hiera("ntpservers")) {
   file{"/etc/ntp.conf":
       content => template("ntp.conf.erb")
   }
}
</pre>

We create a class that takes as parameters a list of NTP servers.

The module author wants to create a works-out-of-the-box experience
so creates a data class for the NTP module:

<pre>
class ntp::data {
   $ntpservers = ["1.pool.ntp.org", "2.pool.ntp.org"]
}
</pre>

Together this creates a default sane setup.

Module User
-----------

The module user has a complex multi data center setup, he wants to use
the NTP module from the forge and configure it for his needs.

The user creates a set of default data for his organization, he can do
this in data files or in Puppet.  We'll show a Puppet example.

<pre>
class data::common {
   $ntpservers = ["ntp1.example.com", "ntp2.example.com"]
}
</pre>

Being part of the actual code this data is subject to strict change
control.  This is needed as its data that can potentially affect all
machines in all locations.

The user has a fact called _location_ that contains, for example, a name
of the data center.

He decides to create JSON based data for the data centers, being just data
that applies to one data center this data is not subject to as strict
change controls and so does not live with the code:

He creates _/var/lib/hiera/dc1.json_ with the following:

<pre>
{"ntpservers" : ["ntp1.dc1.example.com", "ntp2.dc1.example.com"]}
</pre>

Machines in dc1 will now use specific NTP servers while all the rest will
use the data in _data::common_

The module user can now just declare the class on his nodes:

<pre>
node "web1" {
   include ntp::config
}
</pre>

For true one-off changes, the user can use the full paramterized class approach
that will completely disable the Hiera handling of this data item.  He could
also use an ENC to supply this data.

<pre>
node "web2" {
   class{"ntp::config": ntpservers => ["another.example.com"]}
}
</pre>

This behavior is thanks to Hiera's ability to search through multiple backends
for data picking the first match.  We can have the JSON searched before the internal
Puppet data.

To achieve this setup the module user needs to configure Hiera in _/etc/puppet/hiera.yaml_:

<pre>
---
:backends: - json
           - puppet
:hierarchy: - %{location}
            - common
:json:
        :datadir: /var/lib/hiera

:puppet:
	:datasource: data
</pre>

Converting from extlookup?
==========================

A simple converter is included called _extlookup2hiera_ and it can convert from CSV to JSON or YAML:

<pre>
$ extlookup2hiera --in common.csv --out common.json --json
</pre>

Installation?
=============

It's not 100% ready for prime time, shortly a simple _gem install hiera-puppet_ on your master will do it.

For the moment the Gem install will place the Puppet Parser Function where Puppet cannot find it, you should
copy it out and distribute it to your master using Pluginsync or something similar

Who?
====

R.I.Pienaar / rip@devco.net / @ripienaar / www.devco.net
