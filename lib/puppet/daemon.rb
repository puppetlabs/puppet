# helper functions for daemons

require 'puppet'

module Puppet
    module Daemon
        def daemonize
            unless Puppet[:logdest] == :file
                Puppet.err "You must reset log destination before daemonizing"
            end
            if pid = fork()
                Process.detach(pid)
                exit(0)
            end

            Process.setsid
            Dir.chdir("/")
            begin
                $stdin.reopen "/dev/null"
                $stdout.reopen "/dev/null", "a"
                $stderr.reopen $stdin
                Log.reopen
            rescue => detail
                File.open("/tmp/daemonout", "w") { |f|
                    f.puts "Could not start %s: %s" % [$0, detail]
                }
                Puppet.err "Could not start %s: %s" % [$0, detail]
                exit(12)
            end
        end

        def fqdn
            unless defined? @fqdn and @fqdn
                hostname = Facter["hostname"].value
                domain = Facter["domain"].value
                @fqdn = [hostname, domain].join(".")
            end
            return @fqdn
        end

        def httplog
            args = []
            # yuck; separate http logs
            if self.is_a?(Puppet::Server)
                args << Puppet[:masterhttplog]
            else
                args << Puppet[:httplog]
            end
            if Puppet[:debug]
                args << WEBrick::Log::DEBUG
            end
            log = WEBrick::Log.new(*args)

            return log
        end

        def initcerts
            return unless @secureinit
            # verify we've got all of the certs set up and such

            # we are not going to encrypt our key, but we need at a minimum
            # a keyfile and a certfile
            certfile = File.join(Puppet[:certdir], [@fqdn, "pem"].join("."))
            cacertfile = File.join(Puppet[:certdir], ["ca", "pem"].join("."))
            keyfile = File.join(Puppet[:privatekeydir], [@fqdn, "pem"].join("."))
            publickeyfile = File.join(Puppet[:publickeydir], [@fqdn, "pem"].join("."))

            [Puppet[:certdir], Puppet[:privatekeydir], Puppet[:csrdir],
                Puppet[:publickeydir]].each { |dir|
                unless FileTest.exists?(dir)
                    Puppet.recmkdir(dir, 0770)
                end
            }

            inited = false
            if File.exists?(keyfile)
                # load the key
                @key = OpenSSL::PKey::RSA.new(File.read(keyfile))
            else
                # create a new one and store it
                Puppet.info "Creating a new SSL key at %s" % keyfile
                @key = OpenSSL::PKey::RSA.new(Puppet[:keylength])
                File.open(keyfile, "w", 0660) { |f| f.print @key.to_pem }
                File.open(publickeyfile, "w", 0660) { |f|
                    f.print @key.public_key.to_pem
                }
            end

            if File.exists?(certfile)
                unless File.exists?(cacertfile)
                    raise Puppet::Error, "Found cert file with no ca cert file"
                end
                @cert = OpenSSL::X509::Certificate.new(File.read(certfile))
                inited = true
            else
                unless defined? @driver
                    Puppet.err "Cannot request a certificate without a defined target"
                    return false
                end
                Puppet.info "Creating a new certificate request for %s" % @fqdn
                name = OpenSSL::X509::Name.new([["CN", @fqdn]])

                @csr = OpenSSL::X509::Request.new
                @csr.version = 0
                @csr.subject = name
                @csr.public_key = @key.public_key
                @csr.sign(@key, OpenSSL::Digest::MD5.new)

                Puppet.info "Requesting certificate"

                begin
                    cert, cacert = @driver.getcert(@csr.to_pem)
                rescue => detail
                    raise Puppet::Error.new("Certificate retrieval failed: %s" % detail)
                end

                if cert.nil? or cert == ""
                    return nil
                end
                File.open(certfile, "w", 0660) { |f| f.print cert }
                File.open(cacertfile, "w", 0660) { |f| f.print cacert }
                begin
                    @cert = OpenSSL::X509::Certificate.new(cert)
                    @cacert = OpenSSL::X509::Certificate.new(cacert)
                    inited = true
                rescue => detail
                    raise Puppet::Error.new(
                        "Invalid certificate: %s" % detail
                    )
                end
            end

            unless @cert.check_private_key(@key)
                raise Puppet::DevError, "Received invalid certificate"
            end
            return inited
        end
    end
end

# $Id$
