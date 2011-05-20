#!/usr/bin/env rspec
#
#  Created by Rick Bradley on 2007-10-15.
#  Copyright (c) 2007. All rights reserved.

require 'spec_helper'
require 'puppet/network/handler'
require 'puppet/network/http'
require 'puppet/network/http/webrick'

describe Puppet::Network::HTTP::WEBrick, "after initializing" do
  it "should not be listening" do
    Puppet::Network::HTTP::WEBrick.new.should_not be_listening
  end
end

describe Puppet::Network::HTTP::WEBrick, "when turning on listening" do
  before do
    @mock_webrick = stub('webrick', :[] => {}, :listeners => [], :status => :Running)
    [:mount, :start, :shutdown].each {|meth| @mock_webrick.stubs(meth)}
    WEBrick::HTTPServer.stubs(:new).returns(@mock_webrick)
    @server = Puppet::Network::HTTP::WEBrick.new
    [:setup_logger, :setup_ssl].each {|meth| @server.stubs(meth).returns({})} # the empty hash is required because of how we're merging
    @listen_params = { :address => "127.0.0.1", :port => 31337, :xmlrpc_handlers => [], :protocols => [ :rest ] }
  end

  it "should fail if already listening" do
    @server.listen(@listen_params)
    Proc.new { @server.listen(@listen_params) }.should raise_error(RuntimeError)
  end

  it "should require at least one protocol" do
    Proc.new { @server.listen(@listen_params.delete_if {|k,v| :protocols == k}) }.should raise_error(ArgumentError)
  end

  it "should require a listening address to be specified" do
    Proc.new { @server.listen(@listen_params.delete_if {|k,v| :address == k})}.should raise_error(ArgumentError)
  end

  it "should require a listening port to be specified" do
    Proc.new { @server.listen(@listen_params.delete_if {|k,v| :port == k})}.should raise_error(ArgumentError)
  end

  it "should order a webrick server to start in a separate thread" do
    @mock_webrick.expects(:start)
    # If you remove this you'll sometimes get race condition problems
    Thread.expects(:new).yields
    @server.listen(@listen_params)
  end

  it "should tell webrick to listen on the specified address and port" do
    WEBrick::HTTPServer.expects(:new).with {|args|
      args[:Port] == 31337 and args[:BindAddress] == "127.0.0.1"
    }.returns(@mock_webrick)
    @server.listen(@listen_params)
  end

  it "should configure a logger for webrick" do
    @server.expects(:setup_logger).returns(:Logger => :mylogger)

    WEBrick::HTTPServer.expects(:new).with {|args|
      args[:Logger] == :mylogger
    }.returns(@mock_webrick)

    @server.listen(@listen_params)
  end

  it "should configure SSL for webrick" do
    @server.expects(:setup_ssl).returns(:Ssl => :testing, :Other => :yay)

    WEBrick::HTTPServer.expects(:new).with {|args|
      args[:Ssl] == :testing and args[:Other] == :yay
    }.returns(@mock_webrick)

    @server.listen(@listen_params)
  end

  it "should be listening" do
    @server.listen(@listen_params)
    @server.should be_listening
  end

  describe "when the REST protocol is requested" do
    it "should register the REST handler at /" do
      # We don't care about the options here.
      @mock_webrick.expects(:mount).with { |path, klass, options| path == "/" and klass == Puppet::Network::HTTP::WEBrickREST }

      @server.listen(@listen_params.merge(:protocols => [:rest]))
    end
  end

  describe "when the XMLRPC protocol is requested" do
    before do
      @servlet = mock 'servlet'

      Puppet::Network::XMLRPC::WEBrickServlet.stubs(:new).returns @servlet

      @master_handler = mock('master_handler')
      @file_handler = mock('file_handler')

      @master = mock 'master'
      @file = mock 'file'
      @master_handler.stubs(:new).returns @master
      @file_handler.stubs(:new).returns @file

      Puppet::Network::Handler.stubs(:handler).with(:master).returns @master_handler
      Puppet::Network::Handler.stubs(:handler).with(:fileserver).returns @file_handler
    end

    it "should do nothing if no xmlrpc handlers have been specified" do
      Puppet::Network::Handler.expects(:handler).never

      @server.listen(@listen_params.merge(:protocols => [:xmlrpc], :xmlrpc_handlers => []))
    end

    it "should look the handler classes up via their base class" do
      Puppet::Network::Handler.expects(:handler).with(:master).returns @master_handler
      Puppet::Network::Handler.expects(:handler).with(:fileserver).returns @file_handler

      @server.listen(@listen_params.merge(:protocols => [:xmlrpc], :xmlrpc_handlers => [:master, :fileserver]))
    end

    it "should create an instance for each requested xmlrpc handler" do
      @master_handler.expects(:new).returns @master
      @file_handler.expects(:new).returns @file

      @server.listen(@listen_params.merge(:protocols => [:xmlrpc], :xmlrpc_handlers => [:master, :fileserver]))
    end

    it "should create a webrick servlet with the xmlrpc handler instances" do
      Puppet::Network::XMLRPC::WEBrickServlet.expects(:new).with([@master, @file]).returns @servlet

      @server.listen(@listen_params.merge(:protocols => [:xmlrpc], :xmlrpc_handlers => [:master, :fileserver]))
    end

    it "should mount the webrick servlet at /RPC2" do
      @mock_webrick.stubs(:mount)
      @mock_webrick.expects(:mount).with("/RPC2", @servlet)

      @server.listen(@listen_params.merge(:protocols => [:xmlrpc], :xmlrpc_handlers => [:master, :fileserver]))
    end
  end
end


describe Puppet::Network::HTTP::WEBrick, "when looking up the class to handle a protocol" do
  it "should require a protocol" do
    lambda { Puppet::Network::HTTP::WEBrick.class_for_protocol }.should raise_error(ArgumentError)
  end

  it "should accept a protocol" do
    lambda { Puppet::Network::HTTP::WEBrick.class_for_protocol("bob") }.should_not raise_error(ArgumentError)
  end

  it "should use a WEBrick + REST class when a REST protocol is specified" do
    Puppet::Network::HTTP::WEBrick.class_for_protocol("rest").should == Puppet::Network::HTTP::WEBrickREST
  end

  it "should fail when an unknown protocol is specified" do
    lambda { Puppet::Network::HTTP::WEBrick.class_for_protocol("abcdefg") }.should raise_error
  end
end

describe Puppet::Network::HTTP::WEBrick, "when turning off listening" do
  before do
    @mock_webrick = stub('webrick', :[] => {}, :listeners => [], :status => :Running)
    [:mount, :start, :shutdown].each {|meth| @mock_webrick.stubs(meth)}
    WEBrick::HTTPServer.stubs(:new).returns(@mock_webrick)
    @server = Puppet::Network::HTTP::WEBrick.new
    [:setup_logger, :setup_ssl].each {|meth| @server.stubs(meth).returns({})} # the empty hash is required because of how we're merging
    @listen_params = { :address => "127.0.0.1", :port => 31337, :handlers => [ :node, :catalog ], :protocols => [ :rest ] }
  end

  it "should fail unless listening" do
    Proc.new { @server.unlisten }.should raise_error(RuntimeError)
  end

  it "should order webrick server to stop" do
    @mock_webrick.expects(:shutdown)
    @server.listen(@listen_params)
    @server.unlisten
  end

  it "should no longer be listening" do
    @server.listen(@listen_params)
    @server.unlisten
    @server.should_not be_listening
  end
end

describe Puppet::Network::HTTP::WEBrick do
  before do
    @mock_webrick = stub('webrick', :[] => {})
    [:mount, :start, :shutdown].each {|meth| @mock_webrick.stubs(meth)}
    WEBrick::HTTPServer.stubs(:new).returns(@mock_webrick)
    @server = Puppet::Network::HTTP::WEBrick.new
  end

  describe "when configuring an http logger" do
    before do
      Puppet.settings.stubs(:value).returns "something"
      Puppet.settings.stubs(:use)
      @filehandle = stub 'handle', :fcntl => nil, :sync => nil

      File.stubs(:open).returns @filehandle
    end

    it "should use the settings for :main, :ssl, and the process name" do
      Puppet.settings.stubs(:value).with(:name).returns "myname"
      Puppet.settings.expects(:use).with(:main, :ssl, "myname")

      @server.setup_logger
    end

    it "should use the masterlog if the run_mode is master" do
      Puppet.run_mode.stubs(:master?).returns(true)
      Puppet.settings.expects(:value).with(:masterhttplog).returns "/master/log"

      File.expects(:open).with("/master/log", "a+").returns @filehandle

      @server.setup_logger
    end

    it "should use the httplog if the run_mode is not master" do
      Puppet.run_mode.stubs(:master?).returns(false)
      Puppet.settings.expects(:value).with(:httplog).returns "/other/log"

      File.expects(:open).with("/other/log", "a+").returns @filehandle

      @server.setup_logger
    end

    describe "and creating the logging filehandle" do
      it "should set fcntl to 'Fcntl::F_SETFD, Fcntl::FD_CLOEXEC'" do
        @filehandle.expects(:fcntl).with(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)

        @server.setup_logger
      end

      it "should sync the filehandle" do
        @filehandle.expects(:sync)

        @server.setup_logger
      end
    end

    it "should create a new WEBrick::Log instance with the open filehandle" do
      WEBrick::Log.expects(:new).with(@filehandle)

      @server.setup_logger
    end

    it "should set debugging if the current loglevel is :debug" do
      Puppet::Util::Log.expects(:level).returns :debug

      WEBrick::Log.expects(:new).with { |handle, debug| debug == WEBrick::Log::DEBUG }

      @server.setup_logger
    end

    it "should return the logger as the main log" do
      logger = mock 'logger'
      WEBrick::Log.expects(:new).returns logger

      @server.setup_logger[:Logger].should == logger
    end

    it "should return the logger as the access log using both the Common and Referer log format" do
      logger = mock 'logger'
      WEBrick::Log.expects(:new).returns logger

      @server.setup_logger[:AccessLog].should == [
        [logger, WEBrick::AccessLog::COMMON_LOG_FORMAT],
        [logger, WEBrick::AccessLog::REFERER_LOG_FORMAT]
      ]
    end
  end

  describe "when configuring ssl" do
    before do
      @key = stub 'key', :content => "mykey"
      @cert = stub 'cert', :content => "mycert"
      @host = stub 'host', :key => @key, :certificate => @cert, :name => "yay", :ssl_store => "mystore"

      Puppet::SSL::Certificate.indirection.stubs(:find).with('ca').returns @cert

      Puppet::SSL::Host.stubs(:localhost).returns @host
    end

    it "should use the key from the localhost SSL::Host instance" do
      Puppet::SSL::Host.expects(:localhost).returns @host
      @host.expects(:key).returns @key

      @server.setup_ssl[:SSLPrivateKey].should == "mykey"
    end

    it "should configure the certificate" do
      @server.setup_ssl[:SSLCertificate].should == "mycert"
    end

    it "should fail if no CA certificate can be found" do
      Puppet::SSL::Certificate.indirection.stubs(:find).with('ca').returns nil

      lambda { @server.setup_ssl }.should raise_error(Puppet::Error)
    end

    it "should specify the path to the CA certificate" do
      Puppet.settings.stubs(:value).returns "whatever"
      Puppet.settings.stubs(:value).with(:hostcrl).returns 'false'
      Puppet.settings.stubs(:value).with(:localcacert).returns '/ca/crt'

      @server.setup_ssl[:SSLCACertificateFile].should == "/ca/crt"
    end

    it "should start ssl immediately" do
      @server.setup_ssl[:SSLStartImmediately].should be_true
    end

    it "should enable ssl" do
      @server.setup_ssl[:SSLEnable].should be_true
    end

    it "should configure the verification method as 'OpenSSL::SSL::VERIFY_PEER'" do
      @server.setup_ssl[:SSLVerifyClient].should == OpenSSL::SSL::VERIFY_PEER
    end

    it "should add an x509 store" do
      Puppet.settings.stubs(:value).returns "whatever"
      Puppet.settings.stubs(:value).with(:hostcrl).returns '/my/crl'

      @host.expects(:ssl_store).returns "mystore"

      @server.setup_ssl[:SSLCertificateStore].should == "mystore"
    end

    it "should set the certificate name to 'nil'" do
      @server.setup_ssl[:SSLCertName].should be_nil
    end
  end
end
