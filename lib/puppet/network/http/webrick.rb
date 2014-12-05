require 'webrick'
require 'webrick/https'
require 'puppet/network/http/webrick/rest'
require 'thread'

require 'puppet/ssl/certificate'
require 'puppet/ssl/certificate_revocation_list'
require 'puppet/ssl/configuration'

class Puppet::Network::HTTP::WEBrick
  CIPHERS = "EDH+CAMELLIA:EDH+aRSA:EECDH+aRSA+AESGCM:EECDH+aRSA+SHA384:EECDH+aRSA+SHA256:EECDH:+CAMELLIA256:+AES256:+CAMELLIA128:+AES128:+SSLv3:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!DSS:!RC4:!SEED:!IDEA:!ECDSA:kEDH:CAMELLIA256-SHA:AES256-SHA:CAMELLIA128-SHA:AES128-SHA"

  def initialize
    @listening = false
  end

  def listen(address, port)
    @server = create_server(address, port)

    @server.listeners.each { |l| l.start_immediately = false }

    @server.mount('/', Puppet::Network::HTTP::WEBrickREST)

    raise "WEBrick server is already listening" if @listening
    @listening = true
    @thread = Thread.new do
      @server.start do |sock|
        timeout = 10.0
        if ! IO.select([sock],nil,nil,timeout)
          raise "Client did not send data within %.1f seconds of connecting" % timeout
        end
        sock.accept
        @server.run(sock)
      end
    end
    sleep 0.1 until @server.status == :Running
  end

  def unlisten
    raise "WEBrick server is not listening" unless @listening
    @server.shutdown
    wait_for_shutdown
    @server = nil
    @listening = false
  end

  def listening?
    @listening
  end

  def wait_for_shutdown
    @thread.join
  end

  # @api private
  def create_server(address, port)
    arguments = {:BindAddress => address, :Port => port, :DoNotReverseLookup => true}
    arguments.merge!(setup_logger)
    arguments.merge!(setup_ssl)

    BasicSocket.do_not_reverse_lookup = true

    server = WEBrick::HTTPServer.new(arguments)
    server.ssl_context.ciphers = CIPHERS
    server
  end

  # Configure our http log file.
  def setup_logger
    # Make sure the settings are all ready for us.
    Puppet.settings.use(:main, :ssl, :application)

    file = Puppet[:masterhttplog]

    # open the log manually to prevent file descriptor leak
    file_io = ::File.open(file, "a+")
    file_io.sync = true
    if defined?(Fcntl::FD_CLOEXEC)
      file_io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
    end

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

    # Get the cached copy.  We know it's been generated, too.
    host = Puppet::SSL::Host.localhost

    raise Puppet::Error, "Could not retrieve certificate for #{host.name} and not running on a valid certificate authority" unless host.certificate

    results[:SSLPrivateKey] = host.key.content
    results[:SSLCertificate] = host.certificate.content
    results[:SSLStartImmediately] = true
    results[:SSLEnable] = true
    results[:SSLOptions] = OpenSSL::SSL::OP_NO_SSLv2 | OpenSSL::SSL::OP_NO_SSLv3

    raise Puppet::Error, "Could not find CA certificate" unless Puppet::SSL::Certificate.indirection.find(Puppet::SSL::CA_NAME)

    results[:SSLCACertificateFile] = ssl_configuration.ca_auth_file
    results[:SSLVerifyClient] = OpenSSL::SSL::VERIFY_PEER

    results[:SSLCertificateStore] = host.ssl_store

    results
  end

  private

  def ssl_configuration
    @ssl_configuration ||= Puppet::SSL::Configuration.new(
      Puppet[:localcacert],
      :ca_auth_file  => Puppet[:ssl_server_ca_auth])
  end
end
