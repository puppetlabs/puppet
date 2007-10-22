require 'puppet/indirector/file'
require 'puppet/indirector/ssl_rsa'

class Puppet::Indirector::SslRsa::File < Puppet::Indirector::File
    desc "Store SSL keys on disk."

    def initialize
        Puppet.settings.use(:ssl)
    end

    def path(name)
        if name == :ca
            File.join Puppet.settings[:cadir], "ca_key.pem"
        else
            File.join Puppet.settings[:publickeydir], name.to_s + ".pem"
        end
    end

    def save(key)
        File.open(path(key.name), "w") { |f| f.print key.to_pem }
    end

    def find(name)
        return nil unless FileTest.exists?(path(name))
        OpenSSL::PKey::RSA.new(File.read(path(name)))
    end

    def destroy(name)
        return nil unless FileTest.exists?(path(name))
        File.unlink(path(name)) and true
    end

end
