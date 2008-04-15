require 'webrick'
require 'webrick/https'
require 'puppet/network/http/webrick/rest'
require 'thread'

class Puppet::Network::HTTP::WEBrick
    def initialize(args = {})
        @listening = false
        @mutex = Mutex.new
    end
    
    def self.class_for_protocol(protocol)
        return Puppet::Network::HTTP::WEBrickREST if protocol.to_sym == :rest
        raise "Unknown protocol [#{protocol}]."
    end
    
    def listen(args = {})
        raise ArgumentError, ":handlers must be specified." if !args[:handlers] or args[:handlers].empty?
        raise ArgumentError, ":protocols must be specified." if !args[:protocols] or args[:protocols].empty?
        raise ArgumentError, ":address must be specified." unless args[:address]
        raise ArgumentError, ":port must be specified." unless args[:port]
        
        @protocols = args[:protocols]
        @handlers = args[:handlers]        

        arguments = {:BindAddress => args[:address], :Port => args[:port]}
        arguments.merge!(setup_logger)
        arguments.merge!(setup_ssl)

        @server = WEBrick::HTTPServer.new(arguments)

        setup_handlers

        @mutex.synchronize do
            raise "WEBrick server is already listening" if @listening        
            @listening = true
            @thread = Thread.new { @server.start }
        end
    end
    
    def unlisten
        @mutex.synchronize do
            raise "WEBrick server is not listening" unless @listening
            @server.shutdown
            @thread.join
            @server = nil
            @listening = false
        end
    end
    
    def listening?
        @mutex.synchronize do
            @listening
        end
    end

    # Configure out http log file.
    def setup_logger
        # Make sure the settings are all ready for us.
        Puppet.settings.use(:main, :ssl, Puppet[:name])

        if Puppet[:name] == "puppetmasterd"
            file = Puppet[:masterhttplog]
        else
            file = Puppet[:httplog]
        end

        # open the log manually to prevent file descriptor leak
        file_io = ::File.open(file, "a+")
        file_io.sync
        file_io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)

        args = [file_io]
        args << WEBrick::Log::DEBUG if Puppet::Util::Log.level == :debug

        logger = WEBrick::Log.new(*args)
        return :Logger => logger, :AccessLog => [
            [logger, WEBrick::AccessLog::COMMON_LOG_FORMAT ],
            [logger, WEBrick::AccessLog::REFERER_LOG_FORMAT ]
        ]
    end

    # Add all of the ssl cert information.
    def setup_ssl
        results = {}

        results[:SSLCertificateStore] = setup_crl if Puppet[:cacrl] != 'false'

        results[:SSLCertificate] = self.cert
        results[:SSLPrivateKey] = self.key
        results[:SSLStartImmediately] = true
        results[:SSLEnable] = true
        results[:SSLCACertificateFile] = Puppet[:localcacert]
        results[:SSLVerifyClient] = OpenSSL::SSL::VERIFY_PEER
        results[:SSLCertName] = nil

        results
    end

    # Create our Certificate revocation list
    def setup_crl
        nil
        if Puppet[:cacrl] == 'false'
            # No CRL, no store needed
            return nil
        end
        unless File.exist?(Puppet[:cacrl])
            raise Puppet::Error, "Could not find CRL; set 'cacrl' to 'false' to disable CRL usage"
        end
        crl = OpenSSL::X509::CRL.new(File.read(Puppet[:cacrl]))
        store = OpenSSL::X509::Store.new
        store.purpose = OpenSSL::X509::PURPOSE_ANY
        store.flags = OpenSSL::X509::V_FLAG_CRL_CHECK_ALL|OpenSSL::X509::V_FLAG_CRL_CHECK
        unless self.ca_cert
            raise Puppet::Error, "Could not find CA certificate"
        end

        store.add_file(Puppet[:localcacert])
        store.add_crl(crl)
        return store
    end

  private
    
    def setup_handlers
        @protocols.each do |protocol|
            klass = self.class.class_for_protocol(protocol)
            @handlers.each do |handler|
                @server.mount('/' + handler.to_s, klass, handler)
                @server.mount('/' + handler.to_s + 's', klass, handler)
            end
        end
    end
end
