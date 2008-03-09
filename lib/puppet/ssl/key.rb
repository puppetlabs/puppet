require 'puppet/ssl'
require 'puppet/indirector'

# Manage private and public keys as a pair.
class Puppet::SSL::Key
    extend Puppet::Indirector

    indirects :key #, :terminus_class => :file

    attr_accessor :name, :content

    # Knows how to create keys with our system defaults.
    def generate
        Puppet.info "Creating a new SSL key for %s" % name
        @content = OpenSSL::PKey::RSA.new(Puppet[:keylength])
    end

    def initialize(name)
        @name = name
    end
end
