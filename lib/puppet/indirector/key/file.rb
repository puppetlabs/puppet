require 'puppet/indirector/ssl_file'
require 'puppet/ssl/key'

class Puppet::SSL::Key::File < Puppet::Indirector::SslFile
    desc "Manage SSL private and public keys on disk."

    store_in :privatekeydir
    store_ca_at :cakey

    # Where should we store the public key?
    def public_key_path(name)
        if ca?(name)
            Puppet[:capub]
        else
            File.join(Puppet[:publickeydir], name.to_s + ".pem")
        end
    end

    # Remove the public key, in addition to the private key
    def destroy(request)
        super

        return unless FileTest.exist?(public_key_path(request.key))

        begin
            File.unlink(public_key_path(request.key))
        rescue => detail
            raise Puppet::Error, "Could not remove %s public key: %s" % [request.key, detail]
        end
    end

    # Save the public key, in addition to the private key.
    def save(request)
        super

        begin
            Puppet.settings.writesub(:publickeydir, public_key_path(request.key)) { |f| f.print request.instance.content.public_key.to_pem }
        rescue => detail
            raise Puppet::Error, "Could not write %s: %s" % [request.key, detail]
        end
    end
end
