require 'openssl'
require 'puppet'
require 'puppet/sslcertificates'
require 'xmlrpc/server'

# Much of this was taken from QuickCert:
#   http://segment7.net/projects/ruby/QuickCert/

module Puppet
class Server
    class CAError < Puppet::Error; end
    class CA < Handler
        attr_reader :ca

        @interface = XMLRPC::Service::Interface.new("puppetca") { |iface|
            iface.add_method("array getcert(csr)")
        }

        def autosign
            if defined? @autosign
                @autosign
            else
                Puppet[:autosign]
            end
        end

        # FIXME autosign? should probably accept both hostnames and IP addresses
        def autosign?(hostname)
            # simple values are easy
            if autosign == true or autosign == false
                return autosign
            end

            # we only otherwise know how to handle files
            unless autosign =~ /^\//
                raise Puppet::Error, "Invalid autosign value %s" %
                    autosign.inspect
            end

            unless FileTest.exists?(autosign)
                unless defined? @@warnedonautosign
                    @@warnedonautosign = true
                    Puppet.info "Autosign is enabled but %s is missing" % autosign
                end
                return false
            end
            auth = Puppet::Server::AuthStore.new
            File.open(autosign) { |f|
                f.each { |line|
                    auth.allow(line.chomp)
                }
            }

            # for now, just cheat and pass a fake IP address to allowed?
            return auth.allowed?(hostname, "127.1.1.1")
        end

        def initialize(hash = {})
            Puppet.config.use(:puppet, :certificates, :ca)
            if hash.include? :autosign
                @autosign = hash[:autosign]
            end

            @ca = Puppet::SSLCertificates::CA.new(hash)
        end

        # our client sends us a csr, and we either store it for later signing,
        # or we sign it right away
        def getcert(csrtext, client = nil, clientip = nil)
            csr = OpenSSL::X509::Request.new(csrtext)

            # Use the hostname from the CSR, not from the network.
            subject = csr.subject

            nameary = subject.to_a.find { |ary|
                ary[0] == "CN"
            }

            if nameary.nil?
                Puppet.err(
                    "Invalid certificate request: could not retrieve server name"
                )
                return "invalid"
            end

            hostname = nameary[1]

            unless @ca
                Puppet.notice "Host %s asked for signing from non-CA master" % hostname
                return ""
            end

            # We used to save the public key, but it's basically unnecessary
            # and it mucks with the permissions requirements.
            # save_pk(hostname, csr.public_key)

            certfile = File.join(Puppet[:certdir], [hostname, "pem"].join("."))

            # first check to see if we already have a signed cert for the host
            cert, cacert = ca.getclientcert(hostname)
            if cert and cacert
                Puppet.info "Retrieving existing certificate for %s" % hostname
                #Puppet.info "Cert: %s; Cacert: %s" % [cert.class, cacert.class]
                return [cert.to_pem, cacert.to_pem]
            elsif @ca
                if self.autosign?(hostname) or client.nil?
                    if client.nil?
                        Puppet.info "Signing certificate for CA server"
                    end
                    # okay, we don't have a signed cert
                    # if we're a CA and autosign is turned on, then go ahead and sign
                    # the csr and return the results
                    Puppet.info "Signing certificate for %s" % hostname
                    cert, cacert = @ca.sign(csr)
                    #Puppet.info "Cert: %s; Cacert: %s" % [cert.class, cacert.class]
                    return [cert.to_pem, cacert.to_pem]
                else # just write out the csr for later signing
                    if @ca.getclientcsr(hostname)
                        Puppet.info "Not replacing existing request from %s" % hostname
                    else
                        Puppet.notice "Host %s has a waiting certificate request" %
                            hostname
                        @ca.storeclientcsr(csr)
                    end
                    return ["", ""]
                end
            else
                raise "huh?"
            end
        end

        private

        # Save the public key.
        def save_pk(hostname, public_key)
            pkeyfile = File.join(Puppet[:publickeydir], [hostname, "pem"].join('.'))

            if FileTest.exists?(pkeyfile)
                currentkey = File.open(pkeyfile) { |k| k.read }
                unless currentkey == public_key.to_s
                    raise Puppet::Error, "public keys for %s differ" % hostname
                end
            else
                File.open(pkeyfile, "w", 0644) { |f|
                    f.print public_key.to_s
                }
            end
        end
    end
end
end

# $Id$
