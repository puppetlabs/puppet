# Confines have been moved out of the provider as they are also used for other things.
# This provides backwards compatibility for people still including this old location.
require 'puppet/provider'
require 'puppet/confine'

Puppet::Provider::Confine = Puppet::Confine
