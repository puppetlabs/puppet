.. contents:: Table of Contents

How to Use This Guide
=====================
This guide is largely a pointer to smaller, more focused guides, although it
includes unique information when no appropriate smaller guide exists.

Introduction to Puppet
=======================

Puppet is a declarative *language* for expressing system configuration, a
*client and server* for distributing it, and a *library* for realizing the
configuration.

The Puppet Introduction_ covers the basic architecture and design goals,
including whether and why you should be using Puppet on your network.

.. _Introduction: intro


Installation
===============
There is an `Installation Guide`_ meant for installation of Puppet across a
network.

There are also complete examples that can be used as a starting point.
`Project WWW`_ is a complete example of a single-node manifest that builds a
web service, and `Project SOHO`_ is a complete example of a networked web
service creator.

There is also a guide for `using Puppet from source`_, and one for
`testing Puppet`_, to get an idea of what you can do without making a full
deployment.

.. _installation guide: installation
.. _Project WWW: /svn/manifests/project-www
.. _Project SOHO: /svn/manifests/project-soho
.. _using puppet from source: fromsvn
.. _testing puppet: testing

The Big Picture
===============

It is still somewhat incomplete, there is a `Big Picture`_ document describing
Puppet's general philosophy without focusing on the specific.  This is a great
place to start if you're wondering why Puppet exists and what separates it
from other `Configuration Management`_ tools.

.. _Big Picture: big-picture
.. _Configuration Management: http://config.sage.org

Command Line Executables
==========================

This section will eventually have links to full man-pages for each executable,
but for now the man pages can be found by running the respective executable
with the '--help' flag (this requires the Rdoc::usage module, which is
often missing).

However, most arguments for the executables are in the form of configuration
parameters used internally in the library.  All of the executables are
written to accept any of these configuration parameters, and they
are all defined in the `Puppet Executable Reference`_.

puppet
    Stand alone Puppet Site Manifest Script evaluator. Parses, evaluates,
    and implements a Site Manifest locally.

puppetmasterd
    Puppet Site Manifest Server Daemon. Runs on each host
    serving/providing configurations to Puppet client hosts.

puppetd
    Puppet Client Host Configuration Daemon. Runs on each host whose
    configuration is managed by Puppet. Requests a Host Specific Manifest
    from a Puppet Manifest Server and implements it locally.

puppetca
    SSL Certificate Authority Server used for receiving cerification
    requests from puppet clients. Puppet Client Hosts are required to have
    their SSL certs signed by their Puppet Manifest Server's Authority
    before they can be authenticated and authorized to recieve
    configurations.

puppetdoc
    Command line tool for printing Puppet Default and Local Type Library
    reference documentation.  This is really only used internally.

.. _Puppet Executable Reference: puppet-executable-reference

Type and Language Reference
==============================
The Puppet reference is split into two pieces:

* `Language Tutorial`_

  A simple description of how the Puppet language functions, with multiple
  examples.

* `Type Reference`_

  A reference of all available Puppet Types.  The types defined in this
  reference represent the total ability of Puppet to manage your system -- if
  an object is not in this reference, then Puppet cannot currently manage it.

* `Language Reference`_

  A reference to all available language structures within Puppet.  This
  reference presents the limits of and options for expressibility within
  Puppet.

.. _Language Tutorial: languagetutorial
.. _Type Reference: typedocs
.. _Language Reference: structures

API Documentation
=================
Until I have time to write tutorials on how to extend Puppet, you might find
some benefit in perusing the `API docs`_.  They're woefully incomplete as of
the end of 2005, but I'll be updating them over time.

.. _api docs: /downloads/puppet/apidocs

Configuration
================
Most Puppet configuration is currently done directly through the executables
through the use of command-line flags, although this should largely migrate to
configuration files before 1.0.  As such, the man pages for the respective
executables is the appropriate place to look for documentation on
configuration (e.g., ``puppetmasterd`` for serving and ``puppetd`` for the
client).

There are some guides already, though:

* `File Serving Configuration`_

* `Puppet Certificates and Security`_

.. _File Serving Configuration: fsconfigref
.. _Puppet Certificates and Security: security

Additional Documentation
========================
While the above links represent the standard, recommended documentation, there
is additional information available for those who are interested:

* `Example Manifests`_

* `Puppet Internals`_

* `How Cfengine compares to Puppet`_

.. _Example Manifests: /svn/manifests
.. _Puppet Internals: howitworks
.. _How Cfengine compares to Puppet: notcfengine
