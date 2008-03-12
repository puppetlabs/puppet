require 'puppet/ssl/base'
require 'puppet/indirector'

# Manage private and public keys as a pair.
class Puppet::SSL::Key < Puppet::SSL::Base
    wraps OpenSSL::PKey::RSA

    extend Puppet::Indirector
    indirects :key, :terminus_class => :file

    attr_accessor :password_file

    # Knows how to create keys with our system defaults.
    def generate
        Puppet.info "Creating a new SSL key for %s" % name
        @content = OpenSSL::PKey::RSA.new(Puppet[:keylength])
    end

    # Optionally support specifying a password file.
    def read(path)
        return super unless password_file

        begin
            password = ::File.read(password_file)
        rescue => detail
            raise Puppet::Error, "Could not read password for %s: %s" % [name, detail]
        end

        @content = wrapped_class.new(::File.read(path), password)
    end
end
