# The library for manipulating SSL certs.

require 'puppet'

begin
    require 'openssl'
rescue LoadError
    raise Puppet::Error, "You must have the Ruby openssl library installed"
end

module Puppet::SSLCertificates
    Puppet.setdefaults("certificates",
        :certdir => ["$ssldir/certs", "The certificate directory."],
        :publickeydir => ["$ssldir/public_keys", "The public key directory."],
        :privatekeydir => { :default => "$ssldir/private_keys",
            :mode => 0750,
            :desc => "The private key directory."
        },
        :privatedir => { :default => "$ssldir/private",
            :mode => 0750,
            :desc => "Where the client stores private certificate information."
        },
        :passfile => { :default => "$privatedir/password",
            :mode => 0640,
            :desc => "Where puppetd stores the password for its private key.
                Generally unused."
        }
    )

    #def self.mkcert(type, name, days, issuercert, issuername, serial, publickey)
    def self.mkcert(hash)
        [:type, :name, :days, :issuer, :serial, :publickey].each { |param|
            unless hash.include?(param)
                raise ArgumentError, "mkcert called without %s" % param
            end
        }

        cert = OpenSSL::X509::Certificate.new
        from = Time.now

        cert.subject = hash[:name]
        if hash[:issuer]
            cert.issuer = hash[:issuer].subject
        else
            # we're a self-signed cert
            cert.issuer = hash[:name]
        end
        cert.not_before = from
        cert.not_after = from + (hash[:days] * 24 * 60 * 60)
        cert.version = 2 # X509v3

        cert.public_key = hash[:publickey]
        cert.serial = hash[:serial]

        basic_constraint = nil
        key_usage = nil
        ext_key_usage = nil

        ef = OpenSSL::X509::ExtensionFactory.new

        ef.subject_certificate = cert

        if hash[:issuer]
            ef.issuer_certificate = hash[:issuer]
        else
            ef.issuer_certificate = cert
        end

        ex = []
        case hash[:type]
        when :ca:
            basic_constraint = "CA:TRUE"
            key_usage = %w{cRLSign keyCertSign}
        when :terminalsubca:
            basic_constraint = "CA:TRUE,pathlen:0"
            key_usage = %w{cRLSign keyCertSign}
        when :server:
            basic_constraint = "CA:FALSE"
            key_usage = %w{digitalSignature keyEncipherment}
        ext_key_usage = %w{serverAuth clientAuth}
        when :ocsp:
            basic_constraint = "CA:FALSE"
            key_usage = %w{nonRepudiation digitalSignature}
        ext_key_usage = %w{serverAuth OCSPSigning}
        when :client:
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

        if key_usage
          ex << ef.create_extension("keyUsage", key_usage.join(","))
        end
        if ext_key_usage
          ex << ef.create_extension("extendedKeyUsage", ext_key_usage.join(","))
        end

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
        if hash[:type] == :ca
            ex << ef.create_extension("authorityKeyIdentifier",
                                      "keyid:always,issuer:always")
        end

        return cert
    end

    def self.mkhash(dir, cert, certfile)
        hash = "%x" % cert.issuer.hash
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
    require 'puppet/sslcertificates/ca'
end

# $Id$
