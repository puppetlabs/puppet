require 'spec_helper'
require 'puppet/network/http'
require 'puppet/network/http/webrick'

describe Puppet::Network::HTTP::WEBrick, "after initializing" do
  it "should not be listening" do
    expect(Puppet::Network::HTTP::WEBrick.new).not_to be_listening
  end
end

describe Puppet::Network::HTTP::WEBrick do
  include PuppetSpec::Files

  let(:address) { '127.0.0.1' }
  let(:port) { 31337 }
  let(:server) { Puppet::Network::HTTP::WEBrick.new }
  let(:localcacert) { make_absolute("/ca/crt") }
  let(:ssl_server_ca_auth) { make_absolute("/ca/ssl_server_auth_file") }
  let(:key) { double('key', :content => "mykey") }
  let(:cert) { double('cert', :content => "mycert") }
  let(:host) { double('host', :key => key, :certificate => cert, :name => "yay", :ssl_store => "mystore") }

  let(:mock_ssl_context) do
    double('ssl_context', :ciphers= => nil)
  end

  let(:socket) { double('socket') }
  let(:mock_webrick) do
    server = double('webrick',
                  :[] => {},
                  :listeners => [],
                  :status => :Running,
                  :mount => nil,
                  :shutdown => nil,
                  :ssl_context => mock_ssl_context)
    allow(server).to receive(:start).and_yield(socket)
    allow(IO).to receive(:select).with([socket], nil, nil, anything).and_return(true)
    allow(socket).to receive(:accept)
    allow(server).to receive(:run).with(socket)
    server
  end

  before :each do
    allow(WEBrick::HTTPServer).to receive(:new).and_return(mock_webrick)
    allow(Puppet::SSL::Certificate.indirection).to receive(:find).with('ca').and_return(cert)
    allow(Puppet::SSL::Host).to receive(:localhost).and_return(host)
  end

  describe "when turning on listening" do
    it "should fail if already listening" do
      server.listen(address, port)
      expect { server.listen(address, port) }.to raise_error(RuntimeError, /server is already listening/)
    end

    it "should tell webrick to listen on the specified address and port" do
      expect(WEBrick::HTTPServer).to receive(:new).with(
        hash_including(:Port => 31337, :BindAddress => "127.0.0.1")
      ).and_return(mock_webrick)
      server.listen(address, port)
    end

    it "should not perform reverse lookups" do
      expect(WEBrick::HTTPServer).to receive(:new).with(
        hash_including(:DoNotReverseLookup => true)
      ).and_return(mock_webrick)
      expect(BasicSocket).to receive(:do_not_reverse_lookup=).with(true)

      server.listen(address, port)
    end

    it "should configure a logger for webrick" do
      expect(server).to receive(:setup_logger).and_return(:Logger => :mylogger)

      expect(WEBrick::HTTPServer).to receive(:new) do |args|
        expect(args[:Logger]).to eq(:mylogger)
      end.and_return(mock_webrick)

      server.listen(address, port)
    end

    it "should configure SSL for webrick" do
      expect(server).to receive(:setup_ssl).and_return(:Ssl => :testing, :Other => :yay)

      expect(WEBrick::HTTPServer).to receive(:new).with(hash_including(:Ssl => :testing, :Other => :yay)).and_return(mock_webrick)

      server.listen(address, port)
    end

    it "should be listening" do
      server.listen(address, port)
      expect(server).to be_listening
    end

    it "is passed a yet to be accepted socket" do
      expect(socket).to receive(:accept)

      server.listen(address, port)
      server.unlisten
    end

    describe "when the REST protocol is requested" do
      it "should register the REST handler at /" do
        # We don't care about the options here.
        expect(mock_webrick).to receive(:mount).with("/", Puppet::Network::HTTP::WEBrickREST)

        server.listen(address, port)
      end
    end
  end

  describe "when turning off listening" do
    it "should fail unless listening" do
      expect { server.unlisten }.to raise_error(RuntimeError, /server is not listening/)
    end

    it "should order webrick server to stop" do
      expect(mock_webrick).to receive(:shutdown)
      server.listen(address, port)
      server.unlisten
    end

    it "should no longer be listening" do
      server.listen(address, port)
      server.unlisten
      expect(server).not_to be_listening
    end
  end

  describe "when configuring an http logger" do
    let(:server) { Puppet::Network::HTTP::WEBrick.new }

    before :each do
      allow(Puppet.settings).to receive(:use)
      @filehandle = double('handle', :fcntl => nil, :sync= => nil)

      allow(File).to receive(:open).and_return(@filehandle)
    end

    it "should use the settings for :main, :ssl, and :application" do
      expect(Puppet.settings).to receive(:use).with(:main, :ssl, :application)

      server.setup_logger
    end

    it "should use the masterhttplog" do
      log = make_absolute("/master/log")
      Puppet[:masterhttplog] = log

      expect(File).to receive(:open).with(log, "a+:UTF-8").and_return(@filehandle)

      server.setup_logger
    end

    describe "and creating the logging filehandle" do
      it "should set the close-on-exec flag if supported" do
        if defined? Fcntl::FD_CLOEXEC
          expect(@filehandle).to receive(:fcntl).with(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
        else
          expect(@filehandle).not_to receive(:fcntl)
        end

        server.setup_logger
      end

      it "should sync the filehandle" do
        expect(@filehandle).to receive(:sync=).with(true)

        server.setup_logger
      end
    end

    it "should create a new WEBrick::Log instance with the open filehandle" do
      expect(WEBrick::Log).to receive(:new).with(@filehandle)

      server.setup_logger
    end

    it "should set debugging if the current loglevel is :debug" do
      expect(Puppet::Util::Log).to receive(:level).and_return(:debug)

      expect(WEBrick::Log).to receive(:new).with(anything, WEBrick::Log::DEBUG)

      server.setup_logger
    end

    it "should return the logger as the main log" do
      logger = double('logger')
      expect(WEBrick::Log).to receive(:new).and_return(logger)

      expect(server.setup_logger[:Logger]).to eq(logger)
    end

    it "should return the logger as the access log using both the Common and Referer log format" do
      logger = double('logger')
      expect(WEBrick::Log).to receive(:new).and_return(logger)

      expect(server.setup_logger[:AccessLog]).to eq([
        [logger, WEBrick::AccessLog::COMMON_LOG_FORMAT],
        [logger, WEBrick::AccessLog::REFERER_LOG_FORMAT]
      ])
    end
  end

  describe "when configuring ssl" do
    it "should use the key from the localhost SSL::Host instance" do
      expect(Puppet::SSL::Host).to receive(:localhost).and_return(host)
      expect(host).to receive(:key).and_return(key)

      expect(server.setup_ssl[:SSLPrivateKey]).to eq("mykey")
    end

    it "should configure the certificate" do
      expect(server.setup_ssl[:SSLCertificate]).to eq("mycert")
    end

    it "should fail if no CA certificate can be found" do
      allow(Puppet::SSL::Certificate.indirection).to receive(:find).with('ca').and_return(nil)

      expect { server.setup_ssl }.to raise_error(Puppet::Error, /Could not find CA certificate/)
    end

    it "should specify the path to the CA certificate" do
      Puppet.settings[:hostcrl] = 'false'
      Puppet.settings[:localcacert] = localcacert

      expect(server.setup_ssl[:SSLCACertificateFile]).to eq(localcacert)
    end

    it "should specify the path to the CA certificate" do
      Puppet.settings[:hostcrl] = 'false'
      Puppet.settings[:localcacert] = localcacert
      Puppet.settings[:ssl_server_ca_auth] = ssl_server_ca_auth

      expect(server.setup_ssl[:SSLCACertificateFile]).to eq(ssl_server_ca_auth)
    end

    it "should not start ssl immediately" do
      expect(server.setup_ssl[:SSLStartImmediately]).to eq(false)
    end

    it "should enable ssl" do
      expect(server.setup_ssl[:SSLEnable]).to be_truthy
    end

    it "should reject SSLv2" do
      options = server.setup_ssl[:SSLOptions]

      expect(options & OpenSSL::SSL::OP_NO_SSLv2).to eq(OpenSSL::SSL::OP_NO_SSLv2)
    end

    it "should reject SSLv3" do
      options = server.setup_ssl[:SSLOptions]

      expect(options & OpenSSL::SSL::OP_NO_SSLv3).to eq(OpenSSL::SSL::OP_NO_SSLv3)
    end

    it "should configure the verification method as 'OpenSSL::SSL::VERIFY_PEER'" do
      expect(server.setup_ssl[:SSLVerifyClient]).to eq(OpenSSL::SSL::VERIFY_PEER)
    end

    it "should add an x509 store" do
      expect(host).to receive(:ssl_store).and_return("mystore")

      expect(server.setup_ssl[:SSLCertificateStore]).to eq("mystore")
    end

    it "should set the certificate name to 'nil'" do
      expect(server.setup_ssl[:SSLCertName]).to be_nil
    end

    it "specifies the allowable ciphers" do
      expect(mock_ssl_context).to receive(:ciphers=).with(server.class::CIPHERS)

      server.create_server('localhost', '8888')
    end
  end
end
