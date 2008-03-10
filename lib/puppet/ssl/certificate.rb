require 'puppet/ssl/base'

# The class that manages all aspects of our SSL certificates --
# private keys, public keys, requests, etc.
class Puppet::SSL::Certificate < Puppet::SSL::Base
    # This is defined from the base class
    wraps OpenSSL::X509::Certificate

    extend Puppet::Indirector
    indirects :certificate #, :terminus_class => :file

    def generate
        raise Puppet::DevError, "Cannot generate certificates directly; they must be generated during signing"
    end
end
