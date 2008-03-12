require 'puppet/ssl/base'

# Manage certificates themselves.
class Puppet::SSL::Certificate < Puppet::SSL::Base
    # This is defined from the base class
    wraps OpenSSL::X509::Certificate

    extend Puppet::Indirector
    indirects :certificate, :extend => Puppet::SSL::IndirectionHooks

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

    # Request a certificate from our CA.
    def generate(request)
        if self.class.ca_location == :local
            terminus = :ca_file
        else
            terminus = :rest
        end

        # Save our certificate request.
        request.save :in => terminus

        # And see if we can retrieve the certificate.
        if cert = self.class.find(name, :in => terminus)
            @content = cert.content
            return true
        else
            return false
        end
    end
end
