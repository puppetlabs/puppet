require 'puppet/ssl/base'

# Manage certificates themselves.  This class has no
# 'generate' method because the CA is responsible
# for turning CSRs into certificates; we can only
# retrieve them from the CA (or not, as is often
# the case).
class Puppet::SSL::Certificate < Puppet::SSL::Base
    # This is defined from the base class
    wraps OpenSSL::X509::Certificate

    extend Puppet::Indirector
    indirects :certificate

    # Indicate where we should get our signed certs from.
    def self.ca_is(dest)
        raise(ArgumentError, "Invalid location '%s' for ca; valid values are :local and :remote" % dest) unless [:local, :remote].include?(dest)
        @ca_location = dest
    end

    # Default to :local for the ca location.
    def self.ca_location
        if defined?(@ca_location) and @ca_location
            @ca_location
        else
            :local
        end
    end
end
