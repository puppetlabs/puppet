config = Puppet::Util::Reference.newreference(:configuration, :depth => 1, :doc => "A reference for all configuration parameters") do
    docs = {}
    Puppet.settings.each do |name, object|
        docs[name] = object
    end

    str = ""
    docs.sort { |a, b|
        a[0].to_s <=> b[0].to_s
    }.each do |name, object|
        # Make each name an anchor
        header = name.to_s
        str += h(header, 3)

        # Print the doc string itself
        begin
            str += object.desc.gsub(/\n/, " ")
        rescue => detail
            puts detail.backtrace
            puts detail
        end
        str += "\n\n"

        # Now print the data about the item.
        str += ""
        val = object.default
        if name.to_s == "vardir"
            val = "/var/lib/puppet"
        elsif name.to_s == "confdir"
            val = "/etc/puppet"
        end

        # Leave out the section information; it was apparently confusing people.
        #str += "- **Section**: %s\n" % object.section
        unless val == ""
            str += "- **Default**: %s\n" % val
        end
        str += "\n"
    end

    return str
end

config.header = "
Specifying Configuration Parameters
-----------------------------------

On The Command-Line
+++++++++++++++++++
Every Puppet executable (with the exception of ``puppetdoc``) accepts all of
the parameters below, but not all of the arguments make sense for every executable.

I have tried to be as thorough as possible in the descriptions of the
arguments, so it should be obvious whether an argument is appropriate or not.

These parameters can be supplied to the executables either as command-line
options or in the configuration file.  For instance, the command-line
invocation below would set the configuration directory to ``/private/puppet``::

    $ puppetd --confdir=/private/puppet

Note that boolean options are turned on and off with a slightly different
syntax on the command line::

    $ puppetd --storeconfigs

    $ puppetd --no-storeconfigs

The invocations above will enable and disable, respectively, the storage of
the client configuration.

Configuration Files
+++++++++++++++++++
As mentioned above, the configuration parameters can also be stored in a
configuration file, located in the configuration directory.  As root, the
default configuration directory is ``/etc/puppet``, and as a regular user, the
default configuration directory is ``~user/.puppet``.  As of 0.23.0, all
executables look for ``puppet.conf`` in their configuration directory
(although they previously looked for separate files).  For example,
``puppet.conf`` is located at ``/etc/puppet/puppet.conf`` as root and
``~user/.puppet/puppet.conf`` as a regular user by default.

All executables will set any parameters set within the ``main`` section,
while each executable will also look for a section named for the executable
and load those parameters.  For example, ``puppetd`` will look for a
section named ``puppetd``, and ``puppetmasterd`` looks for a section
named ``puppetmasterd``.  This allows you to use a single configuration file
to customize the settings for all of your executables.

File Format
'''''''''''
The file follows INI-style formatting.  Here is an example of a very simple
``puppet.conf`` file::

    [main]
        confdir = /private/puppet
        storeconfigs = true

Note that boolean parameters must be explicitly specified as `true` or
`false` as seen above.

If you need to change file parameters (e.g., reset the mode or owner), do
so within curly braces on the same line::

    [main]
        myfile = /tmp/whatever {owner = root, mode = 644}

If you're starting out with a fresh configuration, you may wish to let
the executable generate a template configuration file for you by invoking
the executable in question with the `--genconfig` command.  The executable
will print a template configuration to standard output, which can be
redirected to a file like so::

    $ puppetd --genconfig > /etc/puppet/puppet.conf

Note that this invocation will replace the contents of any pre-existing
`puppet.conf` file, so make a backup of your present config if it contains
valuable information.

Like the `--genconfig` argument, the executables also accept a `--genmanifest`
argument, which will generate a manifest that can be used to manage all of
Puppet's directories and files and prints it to standard output.  This can
likewise be redirected to a file::

    $ puppetd --genmanifest > /etc/puppet/manifests/site.pp

Puppet can also create user and group accounts for itself (one `puppet` group
and one `puppet` user) if it is invoked as `root` with the `--mkusers` argument::

    $ puppetd --mkusers

Signals
-------
The ``puppetd`` and ``puppetmasterd`` executables catch some signals for special
handling.  Both daemons catch (``SIGHUP``), which forces the server to restart
tself.  Predictably, interrupt and terminate (``SIGINT`` and ``SIGTERM``) will shut
down the server, whether it be an instance of ``puppetd`` or ``puppetmasterd``.

Sending the ``SIGUSR1`` signal to an instance of ``puppetd`` will cause it to
immediately begin a new configuration transaction with the server.  This
signal has no effect on ``puppetmasterd``.

Configuration Parameter Reference
---------------------------------
Below is a list of all documented parameters.  Not all of them are valid with all
Puppet executables, but the executables will ignore any inappropriate values.

"

