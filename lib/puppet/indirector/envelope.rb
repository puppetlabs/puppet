require 'puppet/indirector'

# Provide any attributes or functionality needed for indirected
# instances.
module Puppet::Indirector::Envelope
  attr_accessor :expiration

  def expired?
    expiration and expiration < Time.now
  end
end
