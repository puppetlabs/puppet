require 'puppet/ssl/base'
require 'puppet/indirector'

# Manage private and public keys as a pair.
class Puppet::SSL::Key < Puppet::SSL::Base
    wraps OpenSSL::PKey::RSA

    extend Puppet::Indirector
    indirects :key, :terminus_class => :file

    # Knows how to create keys with our system defaults.
    def generate
        Puppet.info "Creating a new SSL key for %s" % name
        @content = OpenSSL::PKey::RSA.new(Puppet[:keylength])
    end
end
