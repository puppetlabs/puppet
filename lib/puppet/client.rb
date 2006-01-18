# the available clients

require 'puppet'
require 'puppet/sslcertificates'
require 'puppet/type'
require 'facter'
require 'openssl'
require 'puppet/transaction'
require 'puppet/transportable'
require 'puppet/metric'
require 'puppet/daemon'
require 'puppet/server'
require 'puppet/base64'

$noclientnetworking = false
begin
    require 'webrick'
    require 'cgi'
    require 'xmlrpc/client'
    require 'xmlrpc/server'
    require 'yaml'
rescue LoadError => detail
    $noclientnetworking = detail
    raise Puppet::Error, "You must have the Ruby XMLRPC, CGI, and Webrick libraries installed"
end

module Puppet
    class NetworkClientError < RuntimeError; end
    class ClientError < RuntimeError; end
    #---------------------------------------------------------------
    if $noclientnetworking
        Puppet.err "Could not load client network libs: %s" % $noclientnetworking
    else
        class NetworkClient < XMLRPC::Client
            #include Puppet::Daemon

            # add the methods associated with each namespace
            Puppet::Server::Handler.each { |handler|
                interface = handler.interface
                namespace = interface.prefix

                interface.methods.each { |ary|
                    method = ary[0]
                    Puppet.info "Defining %s.%s" % [namespace, method]
                    self.send(:define_method,method) { |*args|
                        #Puppet.info "Calling %s" % method
                        #Puppet.info "peer cert is %s" % @http.peer_cert
                        #Puppet.info "cert is %s" % @http.cert
                        begin
                            call("%s.%s" % [namespace, method.to_s],*args)
                        rescue OpenSSL::SSL::SSLError => detail
                            #Puppet.err "Could not call %s.%s: Untrusted certificates" %
                            #    [namespace, method]
                            raise NetworkClientError,
                                "Certificates were not trusted"
                        rescue XMLRPC::FaultException => detail
                            #Puppet.err "Could not call %s.%s: %s" %
                            #    [namespace, method, detail.faultString]
                            #raise NetworkClientError,
                            #    "XMLRPC Error: %s" % detail.faultString
                            raise NetworkClientError, detail.faultString
                        rescue Errno::ECONNREFUSED => detail
                            msg = "Could not connect to %s on port %s" % [@host, @port]
                            #Puppet.err msg
                            raise NetworkClientError, msg
                        rescue SocketError => detail
                            Puppet.err "Could not find server %s" % @puppetserver
                            exit(12)
                        rescue => detail
                            Puppet.err "Could not call %s.%s: %s" %
                                [namespace, method, detail.inspect]
                            #raise NetworkClientError.new(detail.to_s)
                            raise
                        end
                    }
                }
            }

            def ca_file=(cafile)
                @http.ca_file = cafile
                store = OpenSSL::X509::Store.new
                cacert = OpenSSL::X509::Certificate.new(
                    File.read(cafile)
                )
                store.add_cert(cacert) 
                store.purpose = OpenSSL::X509::PURPOSE_SSL_CLIENT
                @http.cert_store = store
            end

            def cert=(cert)
                #Puppet.debug "Adding certificate"
                @http.cert = cert
                @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
            end

            def key=(key)
                @http.key = key
            end

            def initialize(hash)
                hash[:Path] ||= "/RPC2"
                hash[:Server] ||= "localhost"
                hash[:Port] ||= Puppet[:masterport]

                @puppetserver = hash[:Server]

                super(
                    hash[:Server],
                    hash[:Path],
                    hash[:Port],
                    nil, # proxy_host
                    nil, # proxy_port
                    nil, # user
                    nil, # password
                    true # use_ssl
                )

                if hash[:Certificate]
                    self.cert = hash[:Certificate]
                else
                    Puppet.err "No certificate; running with reduced functionality."
                end

                if hash[:Key]
                    self.key = hash[:Key]
                end

                if hash[:CAFile]
                    self.ca_file = hash[:CAFile]
                end

                # from here, i need to add the key, cert, and ca cert
                # and reorgize how i start the client
            end

            def local
                false
            end
        end
    end

    # FIXME this still isn't a good design, because none of the handlers overlap
    # so i could just as easily include them all in the main module
    # but at least it's better organized for now
    class Client
        include Puppet

        # FIXME the cert stuff should only come up with networking, so it
        # should be in the network client, not the normal client
        # but if i do that, it's hard to tell whether the certs have been initialized
        include Puppet::Daemon
        attr_reader :local, :secureinit

        class << self
            attr_reader :drivername
        end

        def initcerts
            unless self.readcert
                unless self.requestcert
                    return nil
                end
            end

            # unless we have a driver, we're a local client and we can't add
            # certs anyway, so it doesn't matter
            unless @driver
                return true
            end

            self.setcerts
        end

        def initialize(hash)
            # to whom do we connect?
            @server = nil
            @nil = nil
            @secureinit = hash[:NoSecureInit] || true

            if hash.include?(:FQDN)
                @fqdn = hash[:FQDN]
            else
                self.fqdn
            end

            if hash.include?(:Cache)
                @cache = hash[:Cache]
            else
                @cache = true
            end

            driverparam = self.class.drivername
            if hash.include?(:Server)
                if $noclientnetworking
                    raise NetworkClientError.new("Networking not available: %s" %
                        $nonetworking)
                end

                args = {:Server => hash[:Server]}
                args[:Port] = hash[:Port] || Puppet[:masterport]

                if self.readcert
                    args[:Certificate] = @cert
                    args[:Key] = @key
                    args[:CAFile] = @cacertfile
                end

                @driver = Puppet::NetworkClient.new(args)
                @local = false
            elsif hash.include?(driverparam)
                @driver = hash[driverparam]
                @local = true
            else
                raise ClientError, "%s must be passed a Server or %s" %
                    [self.class, driverparam]
            end
        end

        def setcerts
            @driver.cert = @cert
            @driver.key = @key
            @driver.ca_file = @cacertfile
        end

        class MasterClient < Puppet::Client
            @drivername = :Master

            def self.facts
                facts = {}
                Facter.each { |name,fact|
                    facts[name] = fact.downcase
                }

                facts
            end

            # This method is how the client receives the tree of Transportable
            # objects.  For now, just descend into the tree and perform and
            # necessary manipulations.
            def apply
                dostorage()
                unless defined? @objects
                    raise Puppet::Error, "Cannot apply; objects not defined"
                end

                #Puppet.err :yay
                #p @objects
                #Puppet.err :mark
                #@objects = @objects.to_type
                # this is a gross hack... but i don't see a good way around it
                # set all of the variables to empty
                Puppet::Transaction.init

                # For now we just evaluate the top-level object, but eventually
                # there will be schedules and such associated with each object,
                # and probably with the container itself.
                transaction = @objects.evaluate
                #transaction = Puppet::Transaction.new(objects)
                transaction.toplevel = true
                begin
                    transaction.evaluate
                rescue Puppet::Error => detail
                    Puppet.err "Could not apply complete configuration: %s" %
                        detail
                rescue => detail
                    Puppet.err "Found a bug: %s" % detail
                end
                Puppet::Metric.gather
                Puppet::Metric.tally
                if Puppet[:rrdgraph] == true
                    Metric.store
                    Metric.graph
                end
                Puppet::Storage.store

                return transaction
            end

            # Cache the config
            def cache(text)
                Puppet.info "Caching configuration at %s" % self.cachefile
                confdir = File.dirname(Puppet[:localconfig])
                unless FileTest.exists?(confdir)
                    Puppet.recmkdir(confdir, 0770)
                end
                File.open(self.cachefile + ".tmp", "w", 0660) { |f|
                    f.print text
                }
                File.rename(self.cachefile + ".tmp", self.cachefile)
            end

            def cachefile
                unless defined? @cachefile
                    @cachefile = Puppet[:localconfig] + ".yaml"
                end
                @cachefile
            end

            # Initialize and load storage
            def dostorage
                begin
                    Puppet::Storage.init
                    Puppet::Storage.load
                rescue => detail
                    Puppet.err "Corrupt state file %s" % Puppet[:checksumfile]
                    begin
                        File.unlink(Puppet[:checksumfile])
                        retry
                    rescue => detail
                        raise Puppet::Error.new("Cannot remove %s: %s" %
                            [Puppet[statefile], detail])
                    end
                end
            end

            # Check whether our configuration is up to date
            def fresh?
                unless defined? @configstamp
                    return false
                end

                # We're willing to give a 2 second drift
                if @driver.freshness - @configstamp < 1
                    return true
                else
                    return false
                end
            end

            # Retrieve the config from a remote server.  If this fails, then
            # use the cached copy.
            def getconfig
                if self.fresh?
                    Puppet.info "Config is up to date"
                    return
                end
                Puppet.debug("getting config")
                dostorage()

                facts = self.class.facts

                unless facts.length > 0
                    raise Puppet::ClientError.new(
                        "Could not retrieve any facts"
                    )
                end

                objects = nil
                if @local
                    # If we're local, we don't have to do any of the conversion
                    # stuff.
                    objects = @driver.getconfig(facts, "yaml")
                    @configstamp = Time.now.to_i

                    if objects == ""
                        raise Puppet::Error, "Could not retrieve configuration"
                    end
                else
                    textobjects = ""

                    textfacts = CGI.escape(YAML.dump(facts))

                    # error handling for this is done in the network client
                    begin
                        textobjects = @driver.getconfig(textfacts, "yaml")
                    rescue => detail
                        Puppet.err "Could not retrieve configuration: %s" % detail
                    end

                    fromcache = false
                    if textobjects == ""
                        textobjects = self.retrievecache
                        if textobjects == ""
                            raise Puppet::Error.new(
                                "Cannot connect to server and there is no cached configuration"
                            )
                        end
                        Puppet.notice "Could not get config; using cached copy"
                        fromcache = true
                    end

                    begin
                        textobjects = CGI.unescape(textobjects)
                        @configstamp = Time.now.to_i
                    rescue => detail
                        raise Puppet::Error, "Could not CGI.unescape configuration"
                    end

                    if @cache and ! fromcache
                        self.cache(textobjects)
                    end

                    begin
                        objects = YAML.load(textobjects)
                    rescue => detail
                        raise Puppet::Error,
                            "Could not understand configuration: %s" %
                            detail.to_s
                    end
                end

                unless objects.is_a?(Puppet::TransBucket)
                    raise NetworkClientError,
                        "Invalid returned objects of type %s" % objects.class
                end

                if classes = objects.classes
                    self.setclasses(classes)
                else
                    Puppet.info "No classes to store"
                end

                # Clear all existing objects, so we can recreate our stack.
                if defined? @objects
                    Puppet::Type.allclear
                end
                @objects = nil

                # Now convert the objects to real Puppet objects
                @objects = objects.to_type

                if @objects.nil?
                    raise Puppet::Error, "Configuration could not be processed"
                end
                #@objects = objects

                # and perform any necessary final actions before we evaluate.
                Puppet::Type.finalize

                return @objects
            end

            # Retrieve the cached config
            def retrievecache
                if FileTest.exists?(self.cachefile)
                    return File.read(self.cachefile)
                else
                    return ""
                end
            end

            # The code that actually runs the configuration.  For now, just
            # ignore the onetime thing.
            def run(onetime = false)
                #if onetime
                    begin
                        self.getconfig
                        self.apply
                    rescue => detail
                        Puppet.err detail.to_s
                        if Puppet[:debug]
                            puts detail.backtrace
                        end
                        exit(13)
                    end
                    return
                #end

#                Puppet.newthread do
#                    begin
#                        self.getconfig
#                        self.apply
#                    rescue => detail
#                        Puppet.err detail.to_s
#                        if Puppet[:debug]
#                            puts detail.backtrace
#                        end
#                        exit(13)
#                    end
#                end
            end

            def setclasses(ary)
                begin
                    File.open(Puppet[:classfile], "w") { |f|
                        f.puts ary.join("\n")
                    }
                rescue => detail
                    Puppet.err "Could not create class file %s: %s" %
                        [Puppet[:classfile], detail]
                end
            end
        end

        class Dipper < Puppet::Client
            @drivername = :Bucket

            def initialize(hash = {})
                if hash.include?(:Path)
                    bucket = Puppet::Server::FileBucket.new(
                        :Bucket => hash[:Path]
                    )
                    hash.delete(:Path)
                    hash[:Bucket] = bucket
                end

                super(hash)
            end

            def backup(file)
                unless FileTest.exists?(file)
                    raise(BucketError, "File %s does not exist" % file, caller)
                end
                contents = File.open(file) { |of| of.read }

                string = Base64.encode64(contents)
                #puts "string is created"

                sum = @driver.addfile(string,file)
                #puts "file %s is added" % file
                return sum
            end

            def restore(file,sum)
                restore = true
                if FileTest.exists?(file)
                    contents = File.open(file) { |of| of.read }

                    cursum = Digest::MD5.hexdigest(contents)

                    # if the checksum has changed...
                    # this might be extra effort
                    if cursum == sum
                        restore = false
                    end
                end

                if restore
                    #puts "Restoring %s" % file
                    if tmp = @driver.getfile(sum)
                        newcontents = Base64.decode64(tmp)
                        newsum = Digest::MD5.hexdigest(newcontents)
                        changed = nil
                        unless FileTest.writable?(file)
                            changed = File.stat(file).mode
                            File.chmod(changed | 0200, file)
                        end
                        File.open(file,File::WRONLY|File::TRUNC) { |of|
                            of.print(newcontents)
                        }
                        if changed
                            File.chmod(changed, file)
                        end
                    else
                        Puppet.err "Could not find file with checksum %s" % sum
                        return nil
                    end
                    #puts "Done"
                    return newsum
                else
                    return nil
                end

            end
        end

        # unlike the other client classes (again, this design sucks) this class
        # is basically just a proxy class -- it calls its methods on the driver
        # and that's about it
        class ProxyClient < Puppet::Client
            def self.mkmethods
                interface = @handler.interface
                namespace = interface.prefix

                interface.methods.each { |ary|
                    method = ary[0]
                    Puppet.debug "%s: defining %s.%s" % [self, namespace, method]
                    self.send(:define_method,method) { |*args|
                        begin
                            @driver.send(method, *args)
                        rescue XMLRPC::FaultException => detail
                            #Puppet.err "Could not call %s.%s: %s" %
                            #    [namespace, method, detail.faultString]
                            #raise NetworkClientError,
                            #    "XMLRPC Error: %s" % detail.faultString
                            raise NetworkClientError, detail.faultString
                        end
                    }
                }
            end
        end

        class FileClient < Puppet::Client::ProxyClient
            @drivername = :FileServer

            # set up the appropriate interface methods
            @handler = Puppet::Server::FileServer

            self.mkmethods

            def initialize(hash = {})
                if hash.include?(:FileServer)
                    unless hash[:FileServer].is_a?(Puppet::Server::FileServer)
                        raise Puppet::DevError, "Must pass an actual FS object"
                    end
                end

                super(hash)
            end
        end

        class CAClient < Puppet::Client::ProxyClient
            @drivername = :CA

            # set up the appropriate interface methods
            @handler = Puppet::Server::CA
            self.mkmethods

            def initialize(hash = {})
                if hash.include?(:CA)
                    hash[:CA] = Puppet::Server::CA.new()
                end

                super(hash)
            end
        end

        class LogClient < Puppet::Client::ProxyClient
            @drivername = :Logger

            # set up the appropriate interface methods
            @handler = Puppet::Server::Logger
            self.mkmethods

            def initialize(hash = {})
                if hash.include?(:Logger)
                    hash[:Logger] = Puppet::Server::Logger.new()
                end

                super(hash)
            end
        end

        class StatusClient < Puppet::Client::ProxyClient
            # set up the appropriate interface methods
            @handler = Puppet::Server::ServerStatus
            self.mkmethods
        end

    end
#---------------------------------------------------------------
end

# $Id$
