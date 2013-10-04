require 'puppet/indirector/terminus'

# Do nothing, requiring that the back-end terminus do all
# of the work.
class Puppet::Indirector::Code < Puppet::Indirector::Terminus
end
