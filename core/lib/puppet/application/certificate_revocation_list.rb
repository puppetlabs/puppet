require 'puppet/application/indirection_base'

# NOTE: this is using an "old" naming convention (underscores instead of camel-case), for backwards
#  compatibility with 2.7.x.  When the old naming convention is officially and publicly deprecated,
#  this should be changed to camel-case.
class Puppet::Application::Certificate_revocation_list < Puppet::Application::IndirectionBase
end
