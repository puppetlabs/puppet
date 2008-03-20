require 'puppet/indirector/ssl_file'
require 'puppet/ssl/key'

class Puppet::SSL::Key::File < Puppet::Indirector::SslFile
    desc "Manage SSL private and public keys on disk."

    store_in :privatekeydir

    def public_key_path(name)
        File.join(Puppet[:publickeydir], name.to_s + ".pem")
    end

    # Remove the public key, in addition to the private key
    def destroy(key, options = {})
        super

        return unless FileTest.exist?(public_key_path(key.name))

        begin
            File.unlink(public_key_path(key.name))
        rescue => detail
            raise Puppet::Error, "Could not remove %s public key: %s" % [key.name, detail]
        end
    end

    # Save the public key, in addition to the private key.
    def save(key, options = {})
        super

        begin
            File.open(public_key_path(key.name), "w") { |f| f.print key.content.public_key.to_pem }
        rescue => detail
            raise Puppet::Error, "Could not write %s: %s" % [key, detail]
        end
    end
end
