require 'puppet/ssl/base'
require 'puppet/indirector'

# Manage private and public keys as a pair.
class Puppet::SSL::Key < Puppet::SSL::Base
    wraps OpenSSL::PKey::RSA

    extend Puppet::Indirector
    indirects :key, :terminus_class => :file

    attr_reader :password_file

    # Knows how to create keys with our system defaults.
    def generate
        Puppet.info "Creating a new SSL key for %s" % name
        if pass = password
            @content = OpenSSL::PKey::RSA.new(Puppet[:keylength], pass)
        else
            @content = OpenSSL::PKey::RSA.new(Puppet[:keylength])
        end
    end

    def password
        return nil unless password_file

        ::File.read(password_file)
    end

    # Set our password file.
    def password_file=(file)
        raise ArgumentError, "Password file %s does not exist" % file unless FileTest.exist?(file)

        @password_file = file
    end

    # Optionally support specifying a password file.
    def read(path)
        return super unless password_file

        @content = wrapped_class.new(::File.read(path), password)
    end
end
