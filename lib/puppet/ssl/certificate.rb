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
    indirects :certificate, :terminus_class => :file

    # Because of how the format handler class is included, this
    # can't be in the base class.
    def self.supported_formats
        [:str]
    end

    def expiration
        return nil unless content
        return content.not_after
    end
end
