require 'puppet/ssl/base'
require 'puppet/indirector'

# Manage private and public keys as a pair.
class Puppet::SSL::Key < Puppet::SSL::Base
    wraps OpenSSL::PKey::RSA

    extend Puppet::Indirector
    indirects :key, :terminus_class => :file

    # Because of how the format handler class is included, this
    # can't be in the base class.
    def self.supported_formats
        [:s]
    end

    attr_accessor :password_file

    # Knows how to create keys with our system defaults.
    def generate
        Puppet.info "Creating a new SSL key for %s" % name
        @content = OpenSSL::PKey::RSA.new(Puppet[:keylength].to_i)
    end

    def initialize(name)
        super

        if ca?
            @password_file = Puppet[:capass]
        else
            @password_file = Puppet[:passfile]
        end
    end

    def password
        return nil unless password_file and FileTest.exist?(password_file)

        ::File.read(password_file)
    end

    # Optionally support specifying a password file.
    def read(path)
        return super unless password_file

        #@content = wrapped_class.new(::File.read(path), password)
        @content = wrapped_class.new(::File.read(path), password)
    end

    def to_s
        if pass = password
            @content.export(OpenSSL::Cipher::DES.new(:EDE3, :CBC), pass)
        else
            return super
        end
    end
end
