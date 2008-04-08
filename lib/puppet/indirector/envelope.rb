require 'puppet/indirector'

# Provide any attributes or functionality needed for indirected
# instances.
module Puppet::Indirector::Envelope
    attr_accessor :expiration

    def expired?
        return false unless expiration
        return false if expiration >= Time.now
        return true
    end
end
