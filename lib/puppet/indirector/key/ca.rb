require 'puppet/indirector/ssl_file'
require 'puppet/ssl/key'

class Puppet::SSL::Key::Ca < Puppet::Indirector::SslFile
    desc "Manage the CA's private on disk.  This terminus *only* works
        with the CA key, because that's the only key that the CA ever interacts
        with."

    # This is just to pass the validation in the base class.  Eh.
    store_at :cakey

    store_ca_at :cakey

    def path(name)
        unless ca?(name)
            raise ArgumentError, "The :ca terminus can only handle the CA private key"
        end
        super
    end
end
