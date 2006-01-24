# helper functions for daemons

require 'puppet'

module Puppet
    # A module that handles operations common to all daemons.
    module Daemon
        def daemonname
            $0.sub(/.+#{File::SEPARATOR}/,'')
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

            setpidfile()

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
            file = nil
            if self.is_a?(Puppet::Server)
                file = Puppet[:masterhttplog]
            else
                file = Puppet[:httplog]
            end

            unless FileTest.exists?(File.dirname(file))
                Puppet.recmkdir(File.dirname(file))
            end
            args << file
            if Puppet[:debug]
                args << WEBrick::Log::DEBUG
            end

            log = WEBrick::Log.new(*args)

            return log
        end

        def readcert
            return unless @secureinit
            # verify we've got all of the certs set up and such

            if defined? @cert and defined? @key and @cert and @key
                return true
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

        def requestcert
            retrieved = false
            # create the directories involved
            [Puppet[:certdir], Puppet[:privatekeydir], Puppet[:csrdir],
                Puppet[:publickeydir]].each { |dir|
                unless FileTest.exists?(dir)
                    Puppet.recmkdir(dir, 0770)
                end
            }

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

        # Create the pid file.
        def setpidfile
            @pidfile = self.pidfile
            if FileTest.exists?(@pidfile)
                Puppet.info "Deleting old pid file"
                begin
                    File.unlink(@pidfile)
                rescue Errno::EACCES
                    Puppet.err "Could not delete old PID file; cannot create new one"
                    return
                end
            end

            unless FileTest.exists?(Puppet[:rundir])
                Puppet.recmkdir(Puppet[:rundir])
                File.chmod(01777, Puppet[:rundir])
            end

            Puppet.info "Setting pidfile to %s" % @pidfile
            begin
                File.open(@pidfile, "w") { |f| f.puts $$ }
            rescue => detail
                Puppet.err "Could not create PID file: %s" % detail
                exit(74)
            end
            Puppet.info "pid file is %s" % @pidfile
        end

        # Shut down our server
        def shutdown
            # Remove our pid file
            if defined? @pidfile and @pidfile and FileTest.exists?(@pidfile)
                begin
                    File.unlink(@pidfile)
                rescue => detail
                    Puppet.err "Could not remove PID file %s: %s" % [@pidfile, detail]
                end
            end

            # And close all logs
            Puppet::Log.close

            super
        end
    end
end

# $Id$
