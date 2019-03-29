require 'spec_helper'

require 'puppet/application/master'
require 'puppet/daemon'
require 'puppet/network/server'

describe Puppet::Application::Master, :unless => Puppet.features.microsoft_windows? do
  before :each do
    Puppet[:bindaddress] = '127.0.0.1'
    @master = Puppet::Application[:master]
    @daemon = double('daemon')
    allow(@daemon).to receive(:argv=)
    allow(@daemon).to receive(:server=)
    allow(@daemon).to receive(:set_signal_traps)
    allow(@daemon).to receive(:start)
    allow(Puppet::Daemon).to receive(:new).and_return(@daemon)
    allow(Puppet::Util::Log).to receive(:newdestination)

    allow(Puppet::Node.indirection).to receive(:terminus_class=)
    allow(Puppet::Node::Facts.indirection).to receive(:terminus_class=)
    allow(Puppet::Node::Facts.indirection).to receive(:cache_class=)
    allow(Puppet::Transaction::Report.indirection).to receive(:terminus_class=)
    allow(Puppet::Resource::Catalog.indirection).to receive(:terminus_class=)
    allow(Puppet::SSL::Host).to receive(:ca_location=)
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
      allow(@master).to receive(:trap)
    end

    it "should catch INT" do
      allow(@master).to receive(:trap) { |arg,block| arg == :INT }

      @master.preinit
    end
  end

  [:debug,:verbose].each do |option|
    it "should declare handle_#{option} method" do
      expect(@master).to respond_to("handle_#{option}".to_sym)
    end

    it "should store argument value when calling handle_#{option}" do
      expect(@master.options).to receive(:[]=).with(option, 'arg')
      @master.send("handle_#{option}".to_sym, 'arg')
    end
  end

  describe "when applying options" do
    before do
      allow(@master.command_line).to receive(:args).and_return([])
    end

    it "should set the log destination with --logdest" do
      expect(Puppet::Log).to receive(:newdestination).with("console")

      @master.handle_logdest("console")
    end

    it "should put the setdest options to true" do
      expect(@master.options).to receive(:[]=).with(:setdest,true)

      @master.handle_logdest("console")
    end

    it "should parse the log destination from ARGV" do
      allow(@master.command_line).to receive(:args).and_return(%w{--logdest /my/file})

      expect(Puppet::Util::Log).to receive(:newdestination).with("/my/file")

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
      allow(Puppet::Log).to receive(:newdestination)
      allow(Puppet).to receive(:settraps)
      allow(Puppet::SSL::CertificateAuthority).to receive(:instance)
      allow(Puppet::SSL::CertificateAuthority).to receive(:ca?)
      allow(Puppet.settings).to receive(:use)

      allow(@master.options).to receive(:[])
    end

    it "should abort stating that the master is not supported on Windows" do
      allow(Puppet.features).to receive(:microsoft_windows?).and_return(true)

      expect { @master.setup }.to raise_error(Puppet::Error, /Puppet master is not supported on Microsoft Windows/)
    end

    describe "setting up logging" do
      it "sets the log level" do
        expect(@master).to receive(:set_log_level)
        @master.setup
      end

      describe "when the log destination is not explicitly configured" do
        before do
          allow(@master.options).to receive(:[]).with(:setdest).and_return(false)
        end

        it "should log to the console when --compile is given" do
          allow(@master.options).to receive(:[]).with(:node).and_return("default")
          expect(Puppet::Util::Log).to receive(:newdestination).with(:console)
          @master.setup
        end

        it "should log to the console when the master is not daemonized or run with rack" do
          expect(Puppet::Util::Log).to receive(:newdestination).with(:console)
          Puppet[:daemonize] = false
          allow(@master.options).to receive(:[]).with(:rack).and_return(false)
          @master.setup
        end

        it "should log to syslog when the master is daemonized" do
          expect(Puppet::Util::Log).not_to receive(:newdestination).with(:console)
          expect(Puppet::Util::Log).to receive(:newdestination).with(:syslog)
          Puppet[:daemonize] = true
          allow(@master.options).to receive(:[]).with(:rack).and_return(false)
          @master.setup
        end

        it "should log to syslog when the master is run with rack" do
          expect(Puppet::Util::Log).not_to receive(:newdestination).with(:console)
          expect(Puppet::Util::Log).to receive(:newdestination).with(:syslog)
          Puppet[:daemonize] = false
          allow(@master.options).to receive(:[]).with(:rack).and_return(true)
          @master.setup
        end
      end

      it "sets the log destination using settings" do
        expect(Puppet::Util::Log).to receive(:newdestination).with("set_via_config")
        Puppet[:logdest] = "set_via_config"

        @master.setup
      end
    end

    it "should print puppet config if asked to in Puppet config" do
      allow(Puppet.settings).to receive(:print_configs?).and_return(true)
      expect(Puppet.settings).to receive(:print_configs).and_return(true)
      expect { @master.setup }.to exit_with 0
    end

    it "should exit after printing puppet config if asked to in Puppet config" do
      allow(Puppet.settings).to receive(:print_configs?).and_return(true)
      expect { @master.setup }.to exit_with 1
    end

    it "should tell Puppet.settings to use :main,:ssl,:master and :metrics category" do
      expect(Puppet.settings).to receive(:use).with(:main,:master,:ssl,:metrics)

      @master.setup
    end

    describe "with no ca" do
      it "should set the ca_location to none" do
        expect(Puppet::SSL::Host).to receive(:ca_location=).with(:none)

        @master.setup
      end

    end

    describe "with a ca configured" do
      before :each do
        allow(Puppet::SSL::CertificateAuthority).to receive(:ca?).and_return(true)
      end

      it "should set the ca_location to local" do
        expect(Puppet::SSL::Host).to receive(:ca_location=).with(:local)

        @master.setup
      end

      it "should tell Puppet.settings to use :ca category" do
        expect(Puppet.settings).to receive(:use).with(:ca)

        @master.setup
      end

      it "should instantiate the CertificateAuthority singleton" do
        expect(Puppet::SSL::CertificateAuthority).to receive(:instance)

        @master.setup
      end
    end

    it "should not set Puppet[:node_cache_terminus] by default" do
      # This is normally called early in the application lifecycle but in our
      # spec testing we don't actually do a full application initialization so
      # we call it here to validate the (possibly) overridden settings are as we
      # expect
      @master.initialize_app_defaults
      @master.setup

      expect(Puppet[:node_cache_terminus]).to be(nil)
    end

    it "should honor Puppet[:node_cache_terminus] by setting the cache_class to its value" do
      # PUP-6060 - ensure we honor this value if specified
      @master.initialize_app_defaults
      Puppet[:node_cache_terminus] = 'plain'
      @master.setup

      expect(Puppet::Node.indirection.cache_class).to eq(:plain)
    end
  end

  describe "when running" do
    before do
      @master.preinit
    end

    it "should dispatch to compile if called with --compile" do
      @master.options[:node] = "foo"
      expect(@master).to receive(:compile)
      @master.run_command
    end

    it "should dispatch to main otherwise" do
      @master.options[:node] = nil

      expect(@master).to receive(:main)
      @master.run_command
    end

    describe "the compile command" do
      before do
        Puppet[:manifest] = "site.pp"
        allow(Puppet).to receive(:err)
        allow(@master).to receive(:puts)
      end

      it "should compile a catalog for the specified node" do
        @master.options[:node] = "foo"
        expect(Puppet::Resource::Catalog.indirection).to receive(:find).with("foo").and_return(Puppet::Resource::Catalog.new)

        expect { @master.compile }.to exit_with 0
      end

      it "should convert the catalog to a pure-resource catalog and use 'JSON::pretty_generate' to pretty-print the catalog" do
        catalog = Puppet::Resource::Catalog.new
        allow(JSON).to receive(:pretty_generate)
        expect(Puppet::Resource::Catalog.indirection).to receive(:find).and_return(catalog)

        expect(catalog).to receive(:to_resource).and_return("rescat")

        @master.options[:node] = "foo"
        expect(JSON).to receive(:pretty_generate).with('rescat', :allow_nan => true, :max_nesting => false)

        expect { @master.compile }.to exit_with 0
      end

      it "should exit with error code 30 if no catalog can be found" do
        @master.options[:node] = "foo"
        expect(Puppet::Resource::Catalog.indirection).to receive(:find).and_return(nil)
        expect(Puppet).to receive(:log_exception)
        expect { @master.compile }.to exit_with 30
      end

      it "should exit with error code 30 if there's a failure" do
        @master.options[:node] = "foo"
        expect(Puppet::Resource::Catalog.indirection).to receive(:find).and_raise(ArgumentError)
        expect(Puppet).to receive(:log_exception)
        expect { @master.compile }.to exit_with 30
      end
    end

    describe "the main command" do
      before :each do
        @master.preinit
        @server = double('server')
        allow(Puppet::Network::Server).to receive(:new).and_return(@server)
        @app = double('app')
        allow(Puppet::SSL::Host).to receive(:localhost)
        allow(Puppet::SSL::CertificateAuthority).to receive(:ca?)
        allow(Process).to receive(:uid).and_return(1000)
        allow(Puppet).to receive(:service)
        Puppet[:daemonize] = false
        allow(Puppet).to receive(:notice)
        allow(Puppet).to receive(:start)
        allow(Puppet::Util).to receive(:chuser)
      end

      it "should create a Server" do
        expect(Puppet::Network::Server).to receive(:new)

        @master.main
      end

      it "should give the server to the daemon" do
        expect(@daemon).to receive(:server=).with(@server)

        @master.main
      end

      it "should generate a SSL cert for localhost" do
        expect(Puppet::SSL::Host).to receive(:localhost)

        @master.main
      end

      it "should make sure to *only* hit the CA for data" do
        allow(Puppet::SSL::CertificateAuthority).to receive(:ca?).and_return(true)

        expect(Puppet::SSL::Host).to receive(:ca_location=).with(:only)

        @master.main
      end

      def a_user_type_for(username)
        user = double('user')
        expect(Puppet::Type.type(:user)).to receive(:new).with(hash_including(name: username)).and_return(user)
        user
      end

      context "user privileges" do
        it "should drop privileges if running as root and the puppet user exists" do
          allow(Puppet.features).to receive(:root?).and_return(true)
          expect(a_user_type_for("puppet")).to receive(:exists?).and_return(true)

          expect(Puppet::Util).to receive(:chuser)

          @master.main
        end

        it "should exit and log an error if running as root and the puppet user does not exist" do
          allow(Puppet.features).to receive(:root?).and_return(true)
          expect(a_user_type_for("puppet")).to receive(:exists?).and_return(false)
          expect(Puppet).to receive(:err).with('Could not change user to puppet. User does not exist and is required to continue.')
          expect { @master.main }.to exit_with 74
        end
      end

      it "should log a deprecation notice when running a WEBrick server" do
        expect(Puppet).to receive(:deprecation_warning).with("The WEBrick Puppet master server is deprecated and will be removed in a future release. Please use Puppet Server instead. See http://links.puppet.com/deprecate-rack-webrick-servers for more information.")
        expect(Puppet).to receive(:deprecation_warning).with("Accessing 'bindaddress' as a setting is deprecated.")

        @master.main
      end

      it "should daemonize if needed" do
        Puppet[:daemonize] = true

        expect(@daemon).to receive(:daemonize)

        @master.main
      end

      it "should start the service" do
        expect(@daemon).to receive(:start)

        @master.main
      end

      describe "with --rack", :if => Puppet.features.rack? do
        before do
          require 'puppet/network/http/rack'
          allow(Puppet::Network::HTTP::Rack).to receive(:new).and_return(@app)

          allow(@master.options).to receive(:[]).with(:rack).and_return(:true)
        end

        it "it should not start a daemon" do
          expect(@daemon).not_to receive(:start)

          @master.main
        end

        it "it should return the app" do
          app = @master.main
          expect(app).to equal(@app)
        end

        it "should log a deprecation notice" do
          expect(Puppet).to receive(:deprecation_warning).with("The Rack Puppet master server is deprecated and will be removed in a future release. Please use Puppet Server instead. See http://links.puppet.com/deprecate-rack-webrick-servers for more information.")

          @master.main
        end
      end
    end
  end
end
