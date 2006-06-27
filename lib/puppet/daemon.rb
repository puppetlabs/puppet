# helper functions for daemons

require 'puppet'

module Puppet
    # A module that handles operations common to all daemons.  This is included
    # into the Server and Client base classes.
    module Daemon
        include Puppet::Util

        Puppet.config.setdefaults(:puppet, :setpidfile => [true,
            "Whether to store a PID file for the daemon."])
        def daemonname
            #$0.sub(/.+#{File::SEPARATOR}/,'')
            Puppet.name
        end

        # The path to the pid file for this server
        def pidfile
            File.join(Puppet[:rundir], daemonname() + ".pid")
        end

        # Put the daemon into the background.
        def daemonize
            if pid = fork()
                Process.detach(pid)
                exit(0)
            end

            # Get rid of console logging
            Puppet::Log.close(:console)

            Process.setsid
            Dir.chdir("/")
            begin
                $stdin.reopen "/dev/null"
                $stdout.reopen "/dev/null", "a"
                $stderr.reopen $stdout
                Puppet::Log.reopen
            rescue => detail
                File.open("/tmp/daemonout", "w") { |f|
                    f.puts "Could not start %s: %s" % [Puppet.name, detail]
                }
                Puppet.err "Could not start %s: %s" % [Puppet.name, detail]
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
            file = nil
            Puppet.config.use(:puppet, :certificates, Puppet.name)
            if Puppet.name == "puppetmasterd"
                file = Puppet[:masterhttplog]
            else
                file = Puppet[:httplog]
            end
#
#            unless FileTest.exists?(File.dirname(file))
#                Puppet.recmkdir(File.dirname(file))
#            end

            args << file
            if Puppet[:debug]
                args << WEBrick::Log::DEBUG
            end

            log = WEBrick::Log.new(*args)


            return log
        end

        # Read in an existing certificate.
        def readcert
            return unless @secureinit
            Puppet.config.use(:puppet, :certificates)
            # verify we've got all of the certs set up and such

            if defined? @cert and defined? @key and @cert and @key
                return true
            end

            unless defined? @fqdn
                self.fqdn
            end

            # we are not going to encrypt our key, but we need at a minimum
            # a keyfile and a certfile
            @certfile = File.join(Puppet[:certdir], [@fqdn, "pem"].join("."))
            @cacertfile = File.join(Puppet[:certdir], ["ca", "pem"].join("."))
            @keyfile = File.join(Puppet[:privatekeydir], [@fqdn, "pem"].join("."))
            @publickeyfile = File.join(Puppet[:publickeydir], [@fqdn, "pem"].join("."))

            if File.exists?(@keyfile)
                # load the key
                @key = OpenSSL::PKey::RSA.new(File.read(@keyfile))
            else
                return false
            end

            if File.exists?(@certfile)
                if File.exists?(@cacertfile)
                    @cacert = OpenSSL::X509::Certificate.new(File.read(@cacertfile))
                else
                    raise Puppet::Error, "Found cert file with no ca cert file"
                end
                @cert = OpenSSL::X509::Certificate.new(File.read(@certfile))
            else
                return false
            end
            return true
        end

        # Request a certificate from the remote system.  This does all of the work
        # of creating the cert request, contacting the remote system, and
        # storing the cert locally.
        def requestcert
            unless @secureinit
                raise Puppet::DevError,
                    "Tried to request cert without initialized security"
            end
            retrieved = false
            Puppet.config.use(:puppet, :certificates)
            # create the directories involved
            # FIXME it's a stupid hack that i have to do this
#            [Puppet[:certdir], Puppet[:privatekeydir], Puppet[:csrdir],
#                Puppet[:publickeydir]].each { |dir|
#                unless FileTest.exists?(dir)
#                    Puppet.recmkdir(dir, 0770)
#                end
#            }

            if self.readcert
                Puppet.info "Certificate already exists; not requesting"
                return true
            end

            unless defined? @key and @key
                # create a new one and store it
                Puppet.info "Creating a new SSL key at %s" % @keyfile
                @key = OpenSSL::PKey::RSA.new(Puppet[:keylength])
                File.open(@keyfile, "w", 0660) { |f| f.print @key.to_pem }
                File.open(@publickeyfile, "w", 0660) { |f|
                    f.print @key.public_key.to_pem
                }
            end

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
                if Puppet[:debug]
                    puts detail.backtrace
                end
                raise Puppet::Error.new("Certificate retrieval failed: %s" %
                    detail)
            end

            if cert.nil? or cert == ""
                return nil
            end
            File.open(@certfile, "w", 0660) { |f| f.print cert }
            File.open(@cacertfile, "w", 0660) { |f| f.print cacert }
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

        # Remove the pid file
        def rmpidfile
            threadlock(:pidfile) do
                if defined? @pidfile and @pidfile and FileTest.exists?(@pidfile)
                    begin
                        File.unlink(@pidfile)
                    rescue => detail
                        Puppet.err "Could not remove PID file %s: %s" %
                            [@pidfile, detail]
                    end
                end
            end
        end

        # Create the pid file.
        def setpidfile
            return unless Puppet[:setpidfile]
            threadlock(:pidfile) do
                Puppet.config.use(:puppet)
                @pidfile = self.pidfile
                if FileTest.exists?(@pidfile)
                    if defined? $setpidfile
                        return
                    else
                        raise Puppet::Error, "A PID file already exists for #{Puppet.name}
    at #{@pidfile}.  Not starting."
                    end
                end

                Puppet.info "Creating PID file to %s" % @pidfile
                begin
                    File.open(@pidfile, "w") { |f| f.puts $$ }
                rescue => detail
                    Puppet.err "Could not create PID file: %s" % detail
                    exit(74)
                end
                $setpidfile = true
            end
        end

        # Shut down our server
        def shutdown
            # Remove our pid file
            rmpidfile()

            # And close all logs except the console.
            Puppet::Log.destinations.reject { |d| d == :console }.each do |dest|
                Puppet::Log.close(dest)
            end

            super
        end

        def start
            setpidfile()
            super
        end
    end
end

# $Id$
