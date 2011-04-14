# The public name of this feature is 'face', but we have hidden all the
# plumbing over in the 'interfaces' namespace to make clear the distinction
# between the two.
#
# This file exists to ensure that the public name is usable without revealing
# the details of the implementation; you really only need go look at anything
# under Interfaces if you are looking to extend the implementation.
#
# It isn't hidden to gratuitously hide things, just to make it easier to
# separate out the interests people will have.  --daniel 2011-04-07
require 'puppet/interface'
Puppet::Face = Puppet::Interface
