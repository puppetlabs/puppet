Cfengine_ is currently the most widely deployed configuration management tool.
In many ways, Puppet_ can be thought of as a next-generation version of
cfengine, in that many of puppet's design goals are specifically derived from
experience with cfengine and are meant to overcome many of cfengine's
weaknesses.

This document summarizes the primary advances that Puppet makes over
cfengine's current state.

Abstraction
-----------
Cfengine is a great way to scale common administrative practices -- you can
move from using SSH and a for loop to using Cfengine pretty smoothly.
However, there is just as much complexity present in either form.  You still
have to handle file contents, and you still have to manage operating system
differences yourself -- you have to know whether it's ``useradd`` or
``adduser``, whether it's ``init`` or Sun's ``SMF``, and what the format of the
filesystem tab is.

Puppet's primary goal is to provide enough abstraction so that you do not have
to know those details.  You can speak in terms of users, services, or
filesystems, and Puppet will translate them to the appropriate commands on
each system.  Puppet administrators are free to focus on the complexity of
their networks, rather than being forced to also handle that complexity plus
the complexity of the differences between the operating systems.

Dedication
----------
Puppet will be supported by an organization dedicated to creating
the best system automation software, and I expect to have a staff of at
least a few people dedicated to development, support, consulting, and custom
development.  Constrast this with cfengine, which is supported by a professor
whose primary use for the software is in research into anomalies.

Cfengine's author is only now starting to invest on community involvement in
its development; while its author has always accepted patches from the
community, he has been hesitant to provide standard project features like a
version repository and a bug database and as a result cfengine's large user
base has not resulted in a large development community.

Because Reductive Labs is a commercial enterprise dependent on customer
satisfaction for its survival, our customers will have a large say in how best
to develop Puppet, and we'll be doing everything we can to develop a strong
community just as dedicated to Puppet and server automation as we are.  Our
goal is also to have multiple developers dedicated full time to Puppet
development, which should significantly accelerate feature development
compared to cfengine.

Language Power
--------------
While the two languages are superficially similar, the puppet language already
supports two critical features that cfengine forces you to hack around.
Puppet supports building higher level objects out of a set of low-level
objects including the ability to parameterize, and has a built-in ability to
express relationships between objects.  For instance, here is how you might
define an 'apache' component::

  define apache(docroot,htmlsource,configfile) {
    # make sure the package is installed
    package { apache: version => "2.0.51", installed => true }

    # pull down the data to serve
    file { $docroot: source => $htmlsource }

    # and the config file
    file { "/etc/apache/httpd.conf": source => $configfile }

    # restart the apache service if the package is reinstalled or if
    # the config file changes; notice no need for 'define' statements
    # or AddInstallable calls
    service { apache: running => true,
      requires => [ package[apache], file["/etc/apache/httpd.conf"] ]
    }
  }

  # You could now have different versions of this:

  apache {
    docroot => "/var/wwwprod",
    htmlsource => "nfs://fileserver/web/wwwprod",
    configfile => "https://webserver/web/prod.conf"
  }

  apache {
    docroot => "/var/wwwdev",
    htmlsource => "http://tmpserver/web/wwwdev",
    configfile => "https://webserver/web/dev.conf"
  }

This simple level of abstraction already puts you far beyond what cfengine
can do.  The initial goal is to provide ample power to express the true
complexity of a network configuration, but just as importantly we want to
support code sharing.  There has been essentially zero success in sharing
configurations within the cfengine community because of how difficult basic
abstraction is with cfengine, so one of my primary goals with the language was
to make abstraction, within a network or across one, downright easy.

Decoupling
----------
Puppet is being written with all components decoupled from each other, using
clean and preferably industry-standard interfaces between them.  Adding a new
action to cfengine requires modification of the entire functional stack
from the lexer and parser through to the backing library, while adding a new
type to Puppet can be as simple as dropping a ruby script into the right
directory.

Puppet also uses the industry-standard XMLRPC protocol for communication
between Puppet clients and servers, so the protocol is easy to study and
either end could be replaced by another service if desired.

Interactivity
-------------
Puppet is being designed to make it easy to get information back
out of it.  For instance, it will be easy to figure out how many changes
happened on a given node, even in a given time frame and of a given type,
without having to parse log files or something.  When puppet 
ships, it will ship with a small add-on that will automatically graph all
of this info in RRD files so that you can just enable this and
automatically get graphs of change rates on your network.

Development Methodology
-----------------------
Reductive Labs is a big believer in enhancing developer productivity.  Puppet
is being written in Ruby because it is a high-level language that is easy to
use yet provides significant productivity enhancements over low-level
languages like C.  Reductive Labs also strongly believes that unreadable code
is bad code; if you can't easily follow a code path in Puppet, then you've
found a bug.  Lastly, we assiduosly unit test our code.  We're always looking
for more ways to test our code, and every bug we quash gets turned into a unit
test so we know we'll never release that bug again.

Examples
--------
I've got some small configurations that exemplify some of the differences.
Here's how a simple centralized Apache configuration would look in the two
languages, for instance.  The two manifests just download Apache's
configuration from a central server, restarting Apache if the files change at
all, and also making sure that Apache is always running.

Here's how it looks in puppet::

    # This would normally be in a separate file, e.g., classes/apache.pp
    class apacheserver {
        # Download the config from a central $server
        file { "/etc/apache":
            source => "puppet://server.domain.com/source/apache",
            recurse => true,
            owner => root,
            group => root
        }

        # Check that apache is running, and mark it to restart if
        # the config files change
        service { apache:
            running => true,
            subscribe => file["/etc/apache"]
        }
    }

    # Node "nodename" is an apache server
    node nodename {
        include apacheserver
    }

And here's how the same configuration looks in cfengine::

    control:
        # this class is necessary later
        AddInstallable = ( restart_apache )

    groups:
        # Mark which nodes are apache servers
        apacheserver = ( nodename )

    # copy the files down from the central server, setting 'restart_apache'
    # if any files changed
    copy:
        apacheserver::
            /source/apache
                dest=/etc/apache server=$(server) owner=root group=root
                define=restart_apache

    # Make sure the process is running
    processes:
        apacheserver::
            "apache" restart "/etc/init.d/apache startssl"

    # restart apache if the appropriate class is set 
    shellcommands:
        apacheserver.restart_apache::
            "/etc/init.d/apache restart"

There are a few specific items worth noting in this comparison:

* The cfengine configuration is a bit inside out, in that each
  statement has to mention the class associated with the work in question
  (assuming you have multiple classes in your configuration).  This encourages
  you to organize your configuration based on the type of work being done
  (e.g., copying or shellcommands), rather than the reason you're doing the
  work (i.e., it's all for the Apache server).

* The cfengine configuration uses the dynamically defined class
  'restart_Apache' to mark the relationship between the Apache configuration
  files and the running Apache process, rather than allowing you to just
  directly specify a relationship.

* The cfengine configuration also separates the management of the Apache
  process into two statements, one for starting if it happens to not be
  running and one for restarting if the files change, whereas Puppet is able
  to handle both functions in one statement.

* The cfengine configuration requires at least two forward references (that
  is, references to portions of the configuration that are further on).  The
  'restart_apache' class must be set as 'AddInstallable' before it is used
  anywhere, and the 'apacheserver' class must be set before any code is
  associated with it.  Neither of these is a big deal in small doses, but it
  can get quite complicated as the configuration matures.

.. _cfengine: http://www.cfengine.org
.. _puppet: /projects/puppet
