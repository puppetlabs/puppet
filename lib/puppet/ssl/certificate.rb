require 'puppet/ssl'

# The class that manages all aspects of our SSL certificates --
# private keys, public keys, requests, etc.
class Puppet::SSL::Certificate
    extend Puppet::Indirector

    indirects :certificate #, :terminus_class => :file

    attr_accessor :name, :content

    def generate
        raise Puppet::DevError, "Cannot generate certificates directly; they must be generated during signing"
    end

    def initialize(name)
        @name = name
    end
end
