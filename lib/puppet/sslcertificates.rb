# The library for manipulating SSL certs.

require 'puppet'

raise Puppet::Error, "You must have the Ruby openssl library installed" unless Puppet.features.openssl?

module Puppet::SSLCertificates
    #def self.mkcert(type, name, dnsnames, ttl, issuercert, issuername, serial, publickey)
    def self.mkcert(hash)
        [:type, :name, :ttl, :issuer, :serial, :publickey].each { |param|
            unless hash.include?(param)
                raise ArgumentError, "mkcert called without %s" % param
            end
        }

        cert = OpenSSL::X509::Certificate.new
        # Make the certificate valid as of yesterday, because
        # so many people's clocks are out of sync.
        from = Time.now - (60*60*24)

        cert.subject = hash[:name]
        if hash[:issuer]
            cert.issuer = hash[:issuer].subject
        else
            # we're a self-signed cert
            cert.issuer = hash[:name]
        end
        cert.not_before = from
        cert.not_after = from + hash[:ttl]
        cert.version = 2 # X509v3

        cert.public_key = hash[:publickey]
        cert.serial = hash[:serial]

        basic_constraint = nil
        key_usage = nil
        ext_key_usage = nil
        subject_alt_name = []

        ef = OpenSSL::X509::ExtensionFactory.new

        ef.subject_certificate = cert

        if hash[:issuer]
            ef.issuer_certificate = hash[:issuer]
        else
            ef.issuer_certificate = cert
        end

        ex = []
        case hash[:type]
        when :ca
            basic_constraint = "CA:TRUE"
            key_usage = %w{cRLSign keyCertSign}
        when :terminalsubca
            basic_constraint = "CA:TRUE,pathlen:0"
            key_usage = %w{cRLSign keyCertSign}
        when :server
            basic_constraint = "CA:FALSE"
            dnsnames = Puppet[:certdnsnames]
            name = hash[:name].to_s.sub(%r{/CN=},'')
            if dnsnames != ""
                dnsnames.split(':').each { |d| subject_alt_name << 'DNS:' + d }
                subject_alt_name << 'DNS:' + name # Add the fqdn as an alias
            elsif name == Facter.value(:fqdn) # we're a CA server, and thus probably the server
                subject_alt_name << 'DNS:' + "puppet" # Add 'puppet' as an alias
                subject_alt_name << 'DNS:' + name # Add the fqdn as an alias
                subject_alt_name << 'DNS:' + name.sub(/^[^.]+./, "puppet.") # add puppet.domain as an alias
            end
            key_usage = %w{digitalSignature keyEncipherment}
            ext_key_usage = %w{serverAuth clientAuth emailProtection}
        when :ocsp
            basic_constraint = "CA:FALSE"
            key_usage = %w{nonRepudiation digitalSignature}
            ext_key_usage = %w{serverAuth OCSPSigning}
        when :client
            basic_constraint = "CA:FALSE"
            key_usage = %w{nonRepudiation digitalSignature keyEncipherment}
            ext_key_usage = %w{clientAuth emailProtection}
            ex << ef.create_extension("nsCertType", "client,email")
        else
            raise Puppet::Error, "unknown cert type '%s'" % hash[:type]
        end

        ex << ef.create_extension("nsComment",
                                  "Puppet Ruby/OpenSSL Generated Certificate")
        ex << ef.create_extension("basicConstraints", basic_constraint, true)
        ex << ef.create_extension("subjectKeyIdentifier", "hash")

        ex << ef.create_extension("keyUsage", key_usage.join(",")) if key_usage
        ex << ef.create_extension("extendedKeyUsage", ext_key_usage.join(",")) if ext_key_usage
        ex << ef.create_extension("subjectAltName", subject_alt_name.join(",")) if ! subject_alt_name.empty?

        #if @ca_config[:cdp_location] then
        #  ex << ef.create_extension("crlDistributionPoints",
        #                            @ca_config[:cdp_location])
        #end

        #if @ca_config[:ocsp_location] then
        #  ex << ef.create_extension("authorityInfoAccess",
        #                            "OCSP;" << @ca_config[:ocsp_location])
        #end
        cert.extensions = ex

        # for some reason this _must_ be the last extension added
        ex << ef.create_extension("authorityKeyIdentifier", "keyid:always,issuer:always") if hash[:type] == :ca

        return cert
    end

    def self.mkhash(dir, cert, certfile)
        # Make sure the hash is zero-padded to 8 chars
        hash = "%08x" % cert.issuer.hash
        hashpath = nil
        10.times { |i|
            path = File.join(dir, "%s.%s" % [hash, i])
            if FileTest.exists?(path)
                if FileTest.symlink?(path)
                    dest = File.readlink(path)
                    if dest == certfile
                        # the correct link already exists
                        hashpath = path
                        break
                    else
                        next
                    end
                else
                    next
                end
            end

            File.symlink(certfile, path)

            hashpath = path
            break
        }


        return hashpath
    end
    require 'puppet/sslcertificates/certificate'
    require 'puppet/sslcertificates/inventory'
    require 'puppet/sslcertificates/ca'
end

