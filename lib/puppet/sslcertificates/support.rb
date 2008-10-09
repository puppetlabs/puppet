require 'puppet/sslcertificates'

# A module to handle reading of certificates.
module Puppet::SSLCertificates::Support
    class MissingCertificate < Puppet::Error; end
    class InvalidCertificate < Puppet::Error; end

    attr_reader :cacert

    # Some metaprogramming to create methods for retrieving and creating keys.
    # This probably isn't fewer lines than defining each separately...
    def self.keytype(name, options, &block)
        var = "@%s" % name

        maker = "mk_%s" % name
        reader = "read_%s" % name

        unless param = options[:param]
            raise ArgumentError, "You must specify the parameter for the key"
        end

        unless klass = options[:class]
            raise ArgumentError, "You must specify the class for the key"
        end

        # Define the method that creates it.
        define_method(maker, &block)

        # Define the reading method.
        define_method(reader) do
            return nil unless FileTest.exists?(Puppet[param]) or rename_files_with_uppercase(Puppet[param])

            begin
                instance_variable_set(var, klass.new(File.read(Puppet[param])))
            rescue => detail
                raise InvalidCertificate, "Could not read %s: %s" % [param, detail]
            end
        end

        # Define the overall method, which just calls the reader and maker
        # as appropriate.
        define_method(name) do
            unless cert = instance_variable_get(var)
                unless cert = send(reader)
                    cert = send(maker)
                    Puppet.settings.write(param) { |f| f.puts cert.to_pem }
                end
                instance_variable_set(var, cert)
            end
            cert
        end
    end

    # The key pair.
    keytype :key, :param => :hostprivkey, :class => OpenSSL::PKey::RSA do
        Puppet.info "Creating a new SSL key at %s" % Puppet[:hostprivkey]
        key = OpenSSL::PKey::RSA.new(Puppet[:keylength])

        # Our key meta programming can only handle one file, so we have
        # to separately write out the public key.
        Puppet.settings.write(:hostpubkey) do |f|
            f.print key.public_key.to_pem
        end
        return key
    end

    # Our certificate request
    keytype :csr, :param => :hostcsr, :class => OpenSSL::X509::Request do
        Puppet.info "Creating a new certificate request for %s" %
            Puppet[:certname]

        csr = OpenSSL::X509::Request.new
        csr.version = 0
        csr.subject = OpenSSL::X509::Name.new([["CN", Puppet[:certname]]])
        csr.public_key = key.public_key
        csr.sign(key, OpenSSL::Digest::MD5.new)

        return csr
    end

    keytype :cert, :param => :hostcert, :class => OpenSSL::X509::Certificate do
        raise MissingCertificate, "No host certificate"
    end

    keytype :ca_cert, :param => :localcacert, :class => OpenSSL::X509::Certificate do
        raise MissingCertificate, "No CA certificate"
    end

    # Request a certificate from the remote system.  This does all of the work
    # of creating the cert request, contacting the remote system, and
    # storing the cert locally.
    def requestcert
        begin
            cert, cacert = caclient.getcert(@csr.to_pem)
        rescue => detail
            if Puppet[:trace]
                puts detail.backtrace
            end
            raise Puppet::Error.new("Certificate retrieval failed: %s" %
                detail)
        end

        if cert.nil? or cert == ""
            return nil
        end
        Puppet.settings.write(:hostcert) do |f| f.print cert end
        Puppet.settings.write(:localcacert) do |f| f.print cacert end
        #File.open(@certfile, "w", 0644) { |f| f.print cert }
        #File.open(@cacertfile, "w", 0644) { |f| f.print cacert }
        begin
            @cert = OpenSSL::X509::Certificate.new(cert)
            @cacert = OpenSSL::X509::Certificate.new(cacert)
            retrieved = true
        rescue => detail
            raise Puppet::Error.new(
                "Invalid certificate: %s" % detail
            )
        end

        unless @cert.check_private_key(@key)
            raise Puppet::DevError, "Received invalid certificate"
        end
        return retrieved
    end

    # A hack method to deal with files that exist with a different case.
    # Just renames it; doesn't read it in or anything.
    def rename_files_with_uppercase(file)
        dir = File.dirname(file)
        short = File.basename(file)

        # If the dir isn't present, we clearly don't have the file.
        #return nil unless FileTest.directory?(dir)

        raise ArgumentError, "Tried to fix SSL files to a file containing uppercase" unless short.downcase == short

        return false unless File.directory?(dir)

        real_file = Dir.entries(dir).reject { |f| f =~ /^\./ }.find do |other|
            other.downcase == short
        end

        return nil unless real_file

        full_file = File.join(dir, real_file)

        Puppet.notice "Fixing case in %s; renaming to %s" % [full_file, file]
        File.rename(full_file, file)

        return true
    end
end
