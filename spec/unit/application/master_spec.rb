#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/application/master'
require 'puppet/daemon'
require 'puppet/network/server'

describe Puppet::Application::Master, :unless => Puppet.features.microsoft_windows? do
  before :each do
    @master = Puppet::Application[:master]
    @daemon = stub_everything 'daemon'
    Puppet::Daemon.stubs(:new).returns(@daemon)
    Puppet::Util::Log.stubs(:newdestination)

    Puppet::Node.indirection.stubs(:terminus_class=)
    Puppet::Node.indirection.stubs(:cache_class=)
    Puppet::Node::Facts.indirection.stubs(:terminus_class=)
    Puppet::Node::Facts.indirection.stubs(:cache_class=)
    Puppet::Transaction::Report.indirection.stubs(:terminus_class=)
    Puppet::Resource::Catalog.indirection.stubs(:terminus_class=)
    Puppet::SSL::Host.stubs(:ca_location=)
  end

  it "should operate in master run_mode" do
    @master.class.run_mode.name.should equal(:master)
  end

  it "should ask Puppet::Application to parse Puppet configuration file" do
    @master.should_parse_config?.should be_true
  end

  it "should declare a main command" do
    @master.should respond_to(:main)
  end

  it "should declare a compile command" do
    @master.should respond_to(:compile)
  end

  it "should declare a preinit block" do
    @master.should respond_to(:preinit)
  end

  describe "during preinit" do
    before :each do
      @master.stubs(:trap)
    end

    it "should catch INT" do
      @master.stubs(:trap).with { |arg,block| arg == :INT }

      @master.preinit
    end

    it "should create a Puppet Daemon" do
      Puppet::Daemon.expects(:new).returns(@daemon)

      @master.preinit
    end

    it "should give ARGV to the Daemon" do
      argv = stub 'argv'
      ARGV.stubs(:dup).returns(argv)
      @daemon.expects(:argv=).with(argv)

      @master.preinit
    end

  end

  [:debug,:verbose].each do |option|
    it "should declare handle_#{option} method" do
      @master.should respond_to("handle_#{option}".to_sym)
    end

    it "should store argument value when calling handle_#{option}" do
      @master.options.expects(:[]=).with(option, 'arg')
      @master.send("handle_#{option}".to_sym, 'arg')
    end
  end

  describe "when applying options" do
    before do
      @master.command_line.stubs(:args).returns([])
    end

    it "should set the log destination with --logdest" do
      Puppet::Log.expects(:newdestination).with("console")

      @master.handle_logdest("console")
    end

    it "should put the setdest options to true" do
      @master.options.expects(:[]=).with(:setdest,true)

      @master.handle_logdest("console")
    end

    it "should parse the log destination from ARGV" do
      @master.command_line.stubs(:args).returns(%w{--logdest /my/file})

      Puppet::Util::Log.expects(:newdestination).with("/my/file")

      @master.parse_options
    end
  end

  describe "during setup" do
    before :each do
      Puppet::Log.stubs(:newdestination)
      Puppet.stubs(:settraps)
      Puppet::SSL::CertificateAuthority.stubs(:instance)
      Puppet::SSL::CertificateAuthority.stubs(:ca?)
      Puppet.settings.stubs(:use)

      @master.options.stubs(:[]).with(any_parameters)
    end

    it "should abort stating that the master is not supported on Windows" do
      Puppet.features.stubs(:microsoft_windows?).returns(true)

      expect { @master.setup }.to raise_error(Puppet::Error, /Puppet master is not supported on Microsoft Windows/)
    end

    it "should set log level to debug if --debug was passed" do
      @master.options.stubs(:[]).with(:debug).returns(true)
      @master.setup
      Puppet::Log.level.should == :debug
    end

    it "should set log level to info if --verbose was passed" do
      @master.options.stubs(:[]).with(:verbose).returns(true)
      @master.setup
      Puppet::Log.level.should == :info
    end

    it "should set console as the log destination if no --logdest and --daemonize" do
      @master.stubs(:[]).with(:daemonize).returns(:false)

      Puppet::Log.expects(:newdestination).with(:syslog)

      @master.setup
    end

    it "should set syslog as the log destination if no --logdest and not --daemonize" do
      Puppet::Log.expects(:newdestination).with(:syslog)

      @master.setup
    end

    it "should set syslog as the log destination if --rack" do
      @master.options.stubs(:[]).with(:rack).returns(:true)

      Puppet::Log.expects(:newdestination).with(:syslog)

      @master.setup
    end

    it "should print puppet config if asked to in Puppet config" do
      Puppet.settings.stubs(:print_configs?).returns(true)
      Puppet.settings.expects(:print_configs).returns(true)
      expect { @master.setup }.to exit_with 0
    end

    it "should exit after printing puppet config if asked to in Puppet config" do
      Puppet.settings.stubs(:print_configs?).returns(true)
      expect { @master.setup }.to exit_with 1
    end

    it "should tell Puppet.settings to use :main,:ssl,:master and :metrics category" do
      Puppet.settings.expects(:use).with(:main,:master,:ssl,:metrics)

      @master.setup
    end

    it "should cache class in yaml" do
      Puppet::Node.indirection.expects(:cache_class=).with(:yaml)

      @master.setup
    end

    describe "with no ca" do

      it "should set the ca_location to none" do
        Puppet::SSL::Host.expects(:ca_location=).with(:none)

        @master.setup
      end

    end

    describe "with a ca configured" do

      before :each do
        Puppet::SSL::CertificateAuthority.stubs(:ca?).returns(true)
      end

      it "should set the ca_location to local" do
        Puppet::SSL::Host.expects(:ca_location=).with(:local)

        @master.setup
      end

      it "should tell Puppet.settings to use :ca category" do
        Puppet.settings.expects(:use).with(:ca)

        @master.setup
      end

      it "should instantiate the CertificateAuthority singleton" do
        Puppet::SSL::CertificateAuthority.expects(:instance)

        @master.setup
      end


    end

  end

  describe "when running" do
    before do
      @master.preinit
    end

    it "should dispatch to compile if called with --compile" do
      @master.options[:node] = "foo"
      @master.expects(:compile)
      @master.run_command
    end

    it "should dispatch to main otherwise" do
      @master.options[:node] = nil

      @master.expects(:main)
      @master.run_command
    end

    describe "the compile command" do
      before do
        Puppet.stubs(:[]).with(:environment)
        Puppet.stubs(:[]).with(:manifest).returns("site.pp")
        Puppet.stubs(:err)
        @master.stubs(:jj)
        Puppet.features.stubs(:pson?).returns true
      end

      it "should fail if pson isn't available" do
        Puppet.features.expects(:pson?).returns false
        lambda { @master.compile }.should raise_error
      end

      it "should compile a catalog for the specified node" do
        @master.options[:node] = "foo"
        Puppet::Resource::Catalog.indirection.expects(:find).with("foo").returns Puppet::Resource::Catalog.new
        $stdout.stubs(:puts)

        expect { @master.compile }.to exit_with 0
      end

      it "should convert the catalog to a pure-resource catalog and use 'jj' to pretty-print the catalog" do
        catalog = Puppet::Resource::Catalog.new
        Puppet::Resource::Catalog.indirection.expects(:find).returns catalog

        catalog.expects(:to_resource).returns("rescat")

        @master.options[:node] = "foo"
        @master.expects(:jj).with("rescat")

        expect { @master.compile }.to exit_with 0
      end

      it "should exit with error code 30 if no catalog can be found" do
        @master.options[:node] = "foo"
        Puppet::Resource::Catalog.indirection.expects(:find).returns nil
        $stderr.expects(:puts)
        expect { @master.compile }.to exit_with 30
      end

      it "should exit with error code 30 if there's a failure" do
        @master.options[:node] = "foo"
        Puppet::Resource::Catalog.indirection.expects(:find).raises ArgumentError
        $stderr.expects(:puts)
        expect { @master.compile }.to exit_with 30
      end
    end

    describe "the main command" do
      before :each do
        @master.preinit
        @server = stub_everything 'server'
        Puppet::Network::Server.stubs(:new).returns(@server)
        @app = stub_everything 'app'
        Puppet::SSL::Host.stubs(:localhost)
        Puppet::SSL::CertificateAuthority.stubs(:ca?)
        Process.stubs(:uid).returns(1000)
        Puppet.stubs(:service)
        Puppet.stubs(:[])
        Puppet.stubs(:notice)
        Puppet.stubs(:start)
      end

      it "should create a Server" do
        Puppet::Network::Server.expects(:new)

        @master.main
      end

      it "should give the server to the daemon" do
        @daemon.expects(:server=).with(@server)

        @master.main
      end

      it "should create the server with the right XMLRPC handlers" do
        Puppet::Network::Server.expects(:new).with { |args| args[:xmlrpc_handlers] == [:Status, :FileServer, :Master, :Report, :Filebucket]}

        @master.main
      end

      it "should create the server with a :ca xmlrpc handler if needed" do
        Puppet.stubs(:[]).with(:ca).returns(true)
        Puppet::Network::Server.expects(:new).with { |args| args[:xmlrpc_handlers].include?(:CA) }

        @master.main
      end

      it "should generate a SSL cert for localhost" do
        Puppet::SSL::Host.expects(:localhost)

        @master.main
      end

      it "should make sure to *only* hit the CA for data" do
        Puppet::SSL::CertificateAuthority.stubs(:ca?).returns(true)

        Puppet::SSL::Host.expects(:ca_location=).with(:only)

        @master.main
      end

      it "should drop privileges if running as root" do
        Puppet.features.stubs(:root?).returns true

        Puppet::Util.expects(:chuser)

        @master.main
      end

      it "should daemonize if needed" do
        Puppet.stubs(:[]).with(:daemonize).returns(true)

        @daemon.expects(:daemonize)

        @master.main
      end

      it "should start the service" do
        @daemon.expects(:start)

        @master.main
      end

      describe "with --rack", :if => Puppet.features.rack? do
        before do
          require 'puppet/network/http/rack'
          Puppet::Network::HTTP::Rack.stubs(:new).returns(@app)
        end

        it "it should create the app with REST and XMLRPC support" do
          @master.options.stubs(:[]).with(:rack).returns(:true)

          Puppet::Network::HTTP::Rack.expects(:new).with { |args|
            args[:xmlrpc_handlers] == [:Status, :FileServer, :Master, :Report, :Filebucket] and
            args[:protocols] == [:rest, :xmlrpc]
          }

          @master.main
        end

        it "it should not start a daemon" do
          @master.options.stubs(:[]).with(:rack).returns(:true)

          @daemon.expects(:start).never

          @master.main
        end

        it "it should return the app" do
          @master.options.stubs(:[]).with(:rack).returns(:true)

          app = @master.main
          app.should equal(@app)
        end

      end

    end
  end
end
