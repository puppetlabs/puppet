#! /usr/bin/env ruby
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
    expect(@master.class.run_mode.name).to equal(:master)
  end

  it "should declare a main command" do
    expect(@master).to respond_to(:main)
  end

  it "should declare a compile command" do
    expect(@master).to respond_to(:compile)
  end

  it "should declare a preinit block" do
    expect(@master).to respond_to(:preinit)
  end

  describe "during preinit" do
    before :each do
      @master.stubs(:trap)
    end

    it "should catch INT" do
      @master.stubs(:trap).with { |arg,block| arg == :INT }

      @master.preinit
    end
  end

  [:debug,:verbose].each do |option|
    it "should declare handle_#{option} method" do
      expect(@master).to respond_to("handle_#{option}".to_sym)
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

    it "should support dns alt names from ARGV" do
      Puppet.settings.initialize_global_settings(["--dns_alt_names", "foo,bar,baz"])

      @master.preinit
      @master.parse_options

      expect(Puppet[:dns_alt_names]).to eq("foo,bar,baz")
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

    describe "setting up logging" do
      it "sets the log level" do
        @master.expects(:set_log_level)
        @master.setup
      end

      describe "when the log destination is not explicitly configured" do
        before do
          @master.options.stubs(:[]).with(:setdest).returns false
        end

        it "logs to the console when --compile is given" do
          @master.options.stubs(:[]).with(:node).returns "default"
          Puppet::Util::Log.expects(:newdestination).with(:console)
          @master.setup
        end

        it "logs to the console when the master is not daemonized or run with rack" do
          Puppet::Util::Log.expects(:newdestination).with(:console)
          Puppet[:daemonize] = false
          @master.options.stubs(:[]).with(:rack).returns(false)
          @master.setup
        end

        it "logs to syslog when the master is daemonized" do
          Puppet::Util::Log.expects(:newdestination).with(:console).never
          Puppet::Util::Log.expects(:newdestination).with(:syslog)
          Puppet[:daemonize] = true
          @master.options.stubs(:[]).with(:rack).returns(false)
          @master.setup
        end

        it "logs to syslog when the master is run with rack" do
          Puppet::Util::Log.expects(:newdestination).with(:console).never
          Puppet::Util::Log.expects(:newdestination).with(:syslog)
          Puppet[:daemonize] = false
          @master.options.stubs(:[]).with(:rack).returns(true)
          @master.setup
        end
      end
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
        Puppet[:manifest] = "site.pp"
        Puppet.stubs(:err)
        @master.stubs(:puts)
      end

      it "should compile a catalog for the specified node" do
        @master.options[:node] = "foo"
        Puppet::Resource::Catalog.indirection.expects(:find).with("foo").returns Puppet::Resource::Catalog.new

        expect { @master.compile }.to exit_with 0
      end

      it "should convert the catalog to a pure-resource catalog and use 'PSON::pretty_generate' to pretty-print the catalog" do
        catalog = Puppet::Resource::Catalog.new
        PSON.stubs(:pretty_generate)
        Puppet::Resource::Catalog.indirection.expects(:find).returns catalog

        catalog.expects(:to_resource).returns("rescat")

        @master.options[:node] = "foo"
        PSON.expects(:pretty_generate).with('rescat', :allow_nan => true, :max_nesting => false)

        expect { @master.compile }.to exit_with 0
      end

      it "should exit with error code 30 if no catalog can be found" do
        @master.options[:node] = "foo"
        Puppet::Resource::Catalog.indirection.expects(:find).returns nil
        Puppet.expects(:log_exception)
        expect { @master.compile }.to exit_with 30
      end

      it "should exit with error code 30 if there's a failure" do
        @master.options[:node] = "foo"
        Puppet::Resource::Catalog.indirection.expects(:find).raises ArgumentError
        Puppet.expects(:log_exception)
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
        Puppet[:daemonize] = false
        Puppet.stubs(:notice)
        Puppet.stubs(:start)
        Puppet::Util.stubs(:chuser)
      end

      it "should create a Server" do
        Puppet::Network::Server.expects(:new)

        @master.main
      end

      it "should give the server to the daemon" do
        @daemon.expects(:server=).with(@server)

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

      def a_user_type_for(username)
        user = mock 'user'
        Puppet::Type.type(:user).expects(:new).with { |args| args[:name] == username }.returns user
        user
      end

      context "user privileges" do
        it "should drop privileges if running as root and the puppet user exists" do
          Puppet.features.stubs(:root?).returns true
          a_user_type_for("puppet").expects(:exists?).returns true

          Puppet::Util.expects(:chuser)

          @master.main
        end

        it "should exit and log an error if running as root and the puppet user does not exist" do
          Puppet.features.stubs(:root?).returns true
          a_user_type_for("puppet").expects(:exists?).returns false
          Puppet.expects(:err).with('Could not change user to puppet. User does not exist and is required to continue.')
          expect { @master.main }.to exit_with 74
        end
      end

      it "should log a deprecation notice when running a WEBrick server" do
        Puppet.expects(:deprecation_warning).with("The WEBrick Puppet master server is deprecated and will be removed in a future release. Please use Puppet Server instead. See http://links.puppetlabs.com/deprecate-rack-webrick-servers for more information.")

        @master.main
      end

      it "should daemonize if needed" do
        Puppet[:daemonize] = true

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

          @master.options.stubs(:[]).with(:rack).returns(:true)
        end

        it "it should not start a daemon" do
          @daemon.expects(:start).never

          @master.main
        end

        it "it should return the app" do
          app = @master.main
          expect(app).to equal(@app)
        end

        it "should log a deprecation notice" do
          Puppet.expects(:deprecation_warning).with("The Rack Puppet master server is deprecated and will be removed in a future release. Please use Puppet Server instead. See http://links.puppetlabs.com/deprecate-rack-webrick-servers for more information.")

          @master.main
        end
      end
    end
  end
end
