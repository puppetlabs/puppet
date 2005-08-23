require 'openssl'
require 'puppet'
require 'puppet/sslcertificates'
require 'xmlrpc/server'

# Much of this was taken from QuickCert:
#   http://segment7.net/projects/ruby/QuickCert/

module Puppet
class Server
    class CAError < Puppet::Error; end
    class CA
        attr_reader :ca

        def self.interface
            XMLRPC::Service::Interface.new("puppetca") { |iface|
                iface.add_method("array getcert(csr)")
            }
        end

        Puppet::Server.addhandler(:CA, self)

        def autosign?(hostname)
            # simple values are easy
            asign = Puppet[:autosign]
            if asign == true or asign == false
                return asign
            end

            # we only otherwise know how to handle files
            unless asign =~ /^\//
                raise Puppet::Error, "Invalid autosign value %s" %
                    asign
            end

            unless FileTest.exists?(asign)
                Puppet.warning "Autosign is enabled but %s is missing" % asign
                return false
            end
            File.open(asign) { |f|
                f.each { |line|
                    line.chomp!
                    if line =~ /^[.\w-]+$/ and line == hostname
                        Puppet.info "%s exactly matched %s" % [hostname, line]
                        return true
                    else
                        begin
                            rx = Regexp.new(line)
                        rescue => detail
                            Puppet.err(
                                "Could not create regexp out of autosign line %s: %s" %
                                [line, detail]
                            )
                            next
                        end

                        if hostname =~ rx
                            Puppet.info "%s matched %s" % [hostname, line]
                            return true
                        end
                    end
                }
            }

            return false
        end

        def initialize(hash = {})
            @ca = Puppet::SSLCertificates::CA.new()
        end

        # our client sends us a csr, and we either store it for later signing,
        # or we sign it right away
        def getcert(csrtext, request = nil)
            # okay, i need to retrieve the hostname from the csr, and then
            # verify that i get the same hostname through reverse lookup or
            # something

            Puppet.info "Someone's trying for a cert"
            csr = OpenSSL::X509::Request.new(csrtext)

            subject = csr.subject

            nameary = subject.to_a.find { |ary|
                ary[0] == "CN"
            }

            if nameary.nil?
                Puppet.err "Invalid certificate request"
                return "invalid"
            end

            hostname = nameary[1]

            unless @ca
                Puppet.notice "Host %s asked for signing from non-CA master" % hostname
                return ""
            end

            # okay, we're now going to store the public key if we don't already
            # have it
            public_key = csr.public_key
            unless FileTest.directory?(Puppet[:publickeydir])
                Puppet.recmkdir(Puppet[:publickeydir])
            end
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
            unless FileTest.directory?(Puppet[:certdir])
                Puppet.recmkdir(Puppet[:certdir], 0770)
            end
            certfile = File.join(Puppet[:certdir], [hostname, "pem"].join("."))

            #puts hostname
            #puts certfile

            unless FileTest.directory?(Puppet[:csrdir])
                Puppet.recmkdir(Puppet[:csrdir], 0770)
            end
            # first check to see if we already have a signed cert for the host
            cert, cacert = ca.getclientcert(hostname)
            if cert and cacert
                Puppet.info "Retrieving existing certificate for %s" % hostname
                Puppet.info "Cert: %s; Cacert: %s" % [cert.class, cacert.class]
                return [cert.to_pem, cacert.to_pem]
            elsif @ca
                if self.autosign?(hostname)
                    # okay, we don't have a signed cert
                    # if we're a CA and autosign is turned on, then go ahead and sign
                    # the csr and return the results
                    Puppet.info "Signing certificate for %s" % hostname
                    cert, cacert = @ca.sign(csr)
                    Puppet.info "Cert: %s; Cacert: %s" % [cert.class, cacert.class]
                    return [cert.to_pem, cacert.to_pem]
                else # just write out the csr for later signing
                    if @ca.getclientcsr(hostname)
                        Puppet.info "Not replacing existing request from %s" % hostname
                    else
                        Puppet.info "Storing certificate request for %s" % hostname
                        @ca.storeclientcsr(csr)
                    end
                    return ["", ""]
                end
            else
                raise "huh?"
            end
        end
    end
end
end
