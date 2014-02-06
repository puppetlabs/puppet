# Developer README #

This file is intended to provide a place for developers and contributors to
document what other developers need to know about changes made to Puppet.

### Dependencies



# Configuration Directory #

In Puppet 3.x we've simplified the behavior of selecting a configuration file
to load.  The intended behavior of reading `puppet.conf` is:

 1. Use the explicit configuration provided by --confdir or --config if present
 2. If running as root (`Puppet.features.root?`) then use the system
    `puppet.conf`
 3. Otherwise, use `~/.puppet/puppet.conf`.

When Puppet master is started from Rack, Puppet 3.x will read from
~/.puppet/puppet.conf by default.  This is intended behavior.  Rack
configurations should start Puppet master with an explicit configuration
directory using `ARGV << "--confdir" << "/etc/puppet"`.  Please see the
`ext/rack/config.ru` file for an up-to-date example.

# Determining the Puppet Version

If you need to programmatically work with the Puppet version, please use the
following:

    require 'puppet/version'
    # Get the version baked into the sourcecode:
    version = Puppet.version
    # Set the version (e.g. in a Rakefile based on `git describe`)
    Puppet.version = '2.3.4'

Please do not monkey patch the constant `Puppet::PUPPETVERSION` or obtain the
version using the constant.  The only supported way to set and get the Puppet
version is through the accessor methods.

Package Maintainers
=====

Software Version API
-----

Please see the public API regarding the software version as described in
`lib/puppet/version.rb`.  Puppet provides the means to easily specify the exact
version of the software packaged using the VERSION file, for example:

    $ git describe --match "3.0.*" > lib/puppet/VERSION
    $ ruby -r puppet/version -e 'puts Puppet.version'
    3.0.1-260-g9ca4e54

EOF
