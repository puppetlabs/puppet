#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/agent'
require 'puppet/application/agent'
require 'puppet/network/server'
require 'puppet/daemon'

describe Puppet::Application::Agent do
  include PuppetSpec::Files

  before :each do
    @puppetd = Puppet::Application[:agent]

    @daemon = Puppet::Daemon.new(nil)
    @daemon.stubs(:daemonize)
    @daemon.stubs(:start)
    @daemon.stubs(:stop)
    Puppet::Daemon.stubs(:new).returns(@daemon)
    Puppet[:daemonize] = false

    @agent = stub_everything 'agent'
    Puppet::Agent.stubs(:new).returns(@agent)

    @puppetd.preinit
    Puppet::Util::Log.stubs(:newdestination)

    @ssl_host = stub_everything 'ssl host'
    Puppet::SSL::Host.stubs(:new).returns(@ssl_host)

    Puppet::Node.indirection.stubs(:terminus_class=)
    Puppet::Node.indirection.stubs(:cache_class=)
    Puppet::Node::Facts.indirection.stubs(:terminus_class=)

    $stderr.expects(:puts).never

    Puppet.settings.stubs(:use)
  end

  it "should operate in agent run_mode" do
    expect(@puppetd.class.run_mode.name).to eq(:agent)
  end

  it "should declare a main command" do
    expect(@puppetd).to respond_to(:main)
  end

  it "should declare a onetime command" do
    expect(@puppetd).to respond_to(:onetime)
  end

  it "should declare a fingerprint command" do
    expect(@puppetd).to respond_to(:fingerprint)
  end

  it "should declare a preinit block" do
    expect(@puppetd).to respond_to(:preinit)
  end

  describe "in preinit" do
    it "should catch INT" do
      Signal.expects(:trap).with { |arg,block| arg == :INT }

      @puppetd.preinit
    end

    it "should init fqdn to nil" do
      @puppetd.preinit

      expect(@puppetd.options[:fqdn]).to be_nil
    end

    it "should init serve to []" do
      @puppetd.preinit

      expect(@puppetd.options[:serve]).to eq([])
    end

    it "should use SHA256 as default digest algorithm" do
      @puppetd.preinit

      expect(@puppetd.options[:digest]).to eq('SHA256')
    end

    it "should not fingerprint by default" do
      @puppetd.preinit

      expect(@puppetd.options[:fingerprint]).to be_falsey
    end

    it "should init waitforcert to nil" do
      @puppetd.preinit

      expect(@puppetd.options[:waitforcert]).to be_nil
    end
  end

  describe "when handling options" do
    before do
      @puppetd.command_line.stubs(:args).returns([])
    end

    [:enable, :debug, :fqdn, :test, :verbose, :digest].each do |option|
      it "should declare handle_#{option} method" do
        expect(@puppetd).to respond_to("handle_#{option}".to_sym)
      end

      it "should store argument value when calling handle_#{option}" do
        @puppetd.send("handle_#{option}".to_sym, 'arg')

        expect(@puppetd.options[option]).to eq('arg')
      end
    end

    describe "when handling --disable" do
      it "should set disable to true" do
        @puppetd.handle_disable('')

        expect(@puppetd.options[:disable]).to eq(true)
      end

      it "should store disable message" do
        @puppetd.handle_disable('message')

        expect(@puppetd.options[:disable_message]).to eq('message')
      end
    end

    it "should set waitforcert to 0 with --onetime and if --waitforcert wasn't given" do
      @agent.stubs(:run).returns(2)
      Puppet[:onetime] = true

      @ssl_host.expects(:wait_for_cert).with(0)

      expect { execute_agent }.to exit_with 0
    end

    it "should use supplied waitforcert when --onetime is specified" do
      @agent.stubs(:run).returns(2)
      Puppet[:onetime] = true
      @puppetd.handle_waitforcert(60)

      @ssl_host.expects(:wait_for_cert).with(60)

      expect { execute_agent }.to exit_with 0
    end

    it "should use a default value for waitforcert when --onetime and --waitforcert are not specified" do
      @ssl_host.expects(:wait_for_cert).with(120)

      execute_agent
    end

    it "should use the waitforcert setting when checking for a signed certificate" do
      Puppet[:waitforcert] = 10
      @ssl_host.expects(:wait_for_cert).with(10)

      execute_agent
    end

    it "should set the log destination with --logdest" do
      Puppet::Log.expects(:newdestination).with("console")

      @puppetd.handle_logdest("console")
    end

    it "should put the setdest options to true" do
      @puppetd.handle_logdest("console")

      expect(@puppetd.options[:setdest]).to eq(true)
    end

    it "should parse the log destination from the command line" do
      @puppetd.command_line.stubs(:args).returns(%w{--logdest /my/file})

      Puppet::Util::Log.expects(:newdestination).with("/my/file")

      @puppetd.parse_options
    end

    it "should store the waitforcert options with --waitforcert" do
      @puppetd.handle_waitforcert("42")

      expect(@puppetd.options[:waitforcert]).to eq(42)
    end
  end

  describe "during setup" do
    before :each do
      Puppet.stubs(:info)
      Puppet[:libdir] = "/dev/null/lib"
      Puppet::Transaction::Report.indirection.stubs(:terminus_class=)
      Puppet::Transaction::Report.indirection.stubs(:cache_class=)
      Puppet::Resource::Catalog.indirection.stubs(:terminus_class=)
      Puppet::Resource::Catalog.indirection.stubs(:cache_class=)
      Puppet::Node::Facts.indirection.stubs(:terminus_class=)
      Puppet.stubs(:settraps)
    end

    it "should not run with extra arguments" do
      @puppetd.command_line.stubs(:args).returns(%w{disable})
      expect{@puppetd.setup}.to raise_error ArgumentError, /does not take parameters/
    end

    describe "with --test" do
      it "should call setup_test" do
        @puppetd.options[:test] = true
        @puppetd.expects(:setup_test)

        @puppetd.setup
      end

      it "should set options[:verbose] to true" do
        @puppetd.setup_test

        expect(@puppetd.options[:verbose]).to eq(true)
      end
      it "should set options[:onetime] to true" do
        Puppet[:onetime] = false
        @puppetd.setup_test
        expect(Puppet[:onetime]).to eq(true)
      end
      it "should set options[:detailed_exitcodes] to true" do
        @puppetd.setup_test

        expect(@puppetd.options[:detailed_exitcodes]).to eq(true)
      end
    end

    it "should call setup_logs" do
      @puppetd.expects(:setup_logs)
      @puppetd.setup
    end

    describe "when setting up logs" do
      before :each do
        Puppet::Util::Log.stubs(:newdestination)
      end

      it "should set log level to debug if --debug was passed" do
        @puppetd.options[:debug] = true
        @puppetd.setup_logs
        expect(Puppet::Util::Log.level).to eq(:debug)
      end

      it "should set log level to info if --verbose was passed" do
        @puppetd.options[:verbose] = true
        @puppetd.setup_logs
        expect(Puppet::Util::Log.level).to eq(:info)
      end

      [:verbose, :debug].each do |level|
        it "should set console as the log destination with level #{level}" do
          @puppetd.options[level] = true

          Puppet::Util::Log.expects(:newdestination).at_least_once
          Puppet::Util::Log.expects(:newdestination).with(:console).once

          @puppetd.setup_logs
        end
      end

      it "should set a default log destination if no --logdest" do
        @puppetd.options[:setdest] = false

        Puppet::Util::Log.expects(:setup_default)

        @puppetd.setup_logs
      end

    end

    it "should print puppet config if asked to in Puppet config" do
      Puppet[:configprint] = "pluginsync"
      Puppet.settings.expects(:print_configs).returns true
      expect { execute_agent }.to exit_with 0
    end

    it "should exit after printing puppet config if asked to in Puppet config" do
      path = make_absolute('/my/path')
      Puppet[:modulepath] = path
      Puppet[:configprint] = "modulepath"
      Puppet::Settings.any_instance.expects(:puts).with(path)
      expect { execute_agent }.to exit_with 0
    end

    it "should use :main, :puppetd, and :ssl" do
      Puppet.settings.unstub(:use)
      Puppet.settings.expects(:use).with(:main, :agent, :ssl)

      @puppetd.setup
    end

    it "should install a remote ca location" do
      Puppet::SSL::Host.expects(:ca_location=).with(:remote)

      @puppetd.setup
    end

    it "should install a none ca location in fingerprint mode" do
      @puppetd.options[:fingerprint] = true
      Puppet::SSL::Host.expects(:ca_location=).with(:none)

      @puppetd.setup
    end

    it "should tell the report handler to use REST" do
      Puppet::Transaction::Report.indirection.expects(:terminus_class=).with(:rest)

      @puppetd.setup
    end

    it "should tell the report handler to cache locally as yaml" do
      Puppet::Transaction::Report.indirection.expects(:cache_class=).with(:yaml)

      @puppetd.setup
    end

    it "should default catalog_terminus setting to 'rest'" do
      @puppetd.initialize_app_defaults
      expect(Puppet[:catalog_terminus]).to eq(:rest)
    end

    it "should default node_terminus setting to 'rest'" do
      @puppetd.initialize_app_defaults
      expect(Puppet[:node_terminus]).to eq(:rest)
    end

    it "has an application default :catalog_cache_terminus setting of 'json'" do
      Puppet::Resource::Catalog.indirection.expects(:cache_class=).with(:json)

      @puppetd.initialize_app_defaults
      @puppetd.setup
    end

    it "should tell the catalog cache class based on the :catalog_cache_terminus setting" do
      Puppet[:catalog_cache_terminus] = "yaml"
      Puppet::Resource::Catalog.indirection.expects(:cache_class=).with(:yaml)

      @puppetd.initialize_app_defaults
      @puppetd.setup
    end

    it "should not set catalog cache class if :catalog_cache_terminus is explicitly nil" do
      Puppet[:catalog_cache_terminus] = nil
      Puppet::Resource::Catalog.indirection.unstub(:cache_class=)
      Puppet::Resource::Catalog.indirection.expects(:cache_class=).never

      @puppetd.initialize_app_defaults
      @puppetd.setup
    end

    it "should set catalog cache class to nil during a noop run" do
      Puppet[:catalog_cache_terminus] = "json"
      Puppet[:noop] = true
      Puppet::Resource::Catalog.indirection.expects(:cache_class=).with(nil)

      @puppetd.initialize_app_defaults
      @puppetd.setup
    end

    it "should default facts_terminus setting to 'facter'" do
      @puppetd.initialize_app_defaults
      expect(Puppet[:facts_terminus]).to eq(:facter)
    end

    it "should create an agent" do
      Puppet::Agent.stubs(:new).with(Puppet::Configurer)

      @puppetd.setup
    end

    [:enable, :disable].each do |action|
      it "should delegate to enable_disable_client if we #{action} the agent" do
        @puppetd.options[action] = true
        @puppetd.expects(:enable_disable_client).with(@agent)

        @puppetd.setup
      end
    end

    describe "when enabling or disabling agent" do
      [:enable, :disable].each do |action|
        it "should call client.#{action}" do
          @puppetd.options[action] = true
          @agent.expects(action)
          expect { execute_agent }.to exit_with 0
        end
      end

      it "should pass the disable message when disabling" do
        @puppetd.options[:disable] = true
        @puppetd.options[:disable_message] = "message"
        @agent.expects(:disable).with("message")

        expect { execute_agent }.to exit_with 0
      end

      it "should pass the default disable message when disabling without a message" do
        @puppetd.options[:disable] = true
        @puppetd.options[:disable_message] = nil
        @agent.expects(:disable).with("reason not specified")

        expect { execute_agent }.to exit_with 0
      end
    end

    it "should inform the daemon about our agent if :client is set to 'true'" do
      @puppetd.options[:client] = true

      execute_agent

      expect(@daemon.agent).to eq(@agent)
    end

    it "should daemonize if needed" do
      Puppet.features.stubs(:microsoft_windows?).returns false
      Puppet[:daemonize] = true

      @daemon.expects(:daemonize)

      execute_agent
    end

    it "should wait for a certificate" do
      @puppetd.options[:waitforcert] = 123
      @ssl_host.expects(:wait_for_cert).with(123)

      execute_agent
    end

    it "should not wait for a certificate in fingerprint mode" do
      @puppetd.options[:fingerprint] = true
      @puppetd.options[:waitforcert] = 123
      @puppetd.options[:digest] = 'MD5'

      certificate = mock 'certificate'
      certificate.stubs(:digest).with('MD5').returns('ABCDE')
      @ssl_host.stubs(:certificate).returns(certificate)

      @ssl_host.expects(:wait_for_cert).never
      @puppetd.expects(:puts).with('ABCDE')

      execute_agent
    end

    describe "when setting up for fingerprint" do
      before(:each) do
        @puppetd.options[:fingerprint] = true
      end

      it "should not setup as an agent" do
        @puppetd.expects(:setup_agent).never
        @puppetd.setup
      end

      it "should not create an agent" do
        Puppet::Agent.stubs(:new).with(Puppet::Configurer).never
        @puppetd.setup
      end

      it "should not daemonize" do
        @daemon.expects(:daemonize).never
        @puppetd.setup
      end
    end

    describe "when configuring agent for catalog run" do
      it "should set should_fork as true when running normally" do
        Puppet::Agent.expects(:new).with(anything, true)
        @puppetd.setup
      end

      it "should not set should_fork as false for --onetime" do
        Puppet[:onetime] = true
        Puppet::Agent.expects(:new).with(anything, false)
        @puppetd.setup
      end
    end
  end


  describe "when running" do
    before :each do
      @puppetd.options[:fingerprint] = false
    end

    it "should dispatch to fingerprint if --fingerprint is used" do
      @puppetd.options[:fingerprint] = true

      @puppetd.stubs(:fingerprint)

      execute_agent
    end

    it "should dispatch to onetime if --onetime is used" do
      @puppetd.options[:onetime] = true

      @puppetd.stubs(:onetime)

      execute_agent
    end

    it "should dispatch to main if --onetime and --fingerprint are not used" do
      @puppetd.options[:onetime] = false

      @puppetd.stubs(:main)

      execute_agent
    end

    describe "with --onetime" do

      before :each do
        @agent.stubs(:run).returns(:report)
        Puppet[:onetime] = true
        @puppetd.options[:client] = :client
        @puppetd.options[:detailed_exitcodes] = false
      end

      it "should setup traps" do
        @daemon.expects(:set_signal_traps)

        expect { execute_agent }.to exit_with 0
      end

      it "should let the agent run" do
        @agent.expects(:run).returns(:report)

        expect { execute_agent }.to exit_with 0
      end

      it "should stop the daemon" do
        @daemon.expects(:stop).with(:exit => false)

        expect { execute_agent }.to exit_with 0
      end

      describe "and --detailed-exitcodes" do
        before :each do
          @puppetd.options[:detailed_exitcodes] = true
        end

        it "should exit with agent computed exit status" do
          Puppet[:noop] = false
          @agent.stubs(:run).returns(666)

          expect { execute_agent }.to exit_with 666
        end

        it "should exit with the agent's exit status, even if --noop is set." do
          Puppet[:noop] = true
          @agent.stubs(:run).returns(666)

          expect { execute_agent }.to exit_with 666
        end
      end
    end

    describe "with --fingerprint" do
      before :each do
        @cert = mock 'cert'
        @puppetd.options[:fingerprint] = true
        @puppetd.options[:digest] = :MD5
      end

      it "should fingerprint the certificate if it exists" do
        @ssl_host.stubs(:certificate).returns(@cert)
        @cert.stubs(:digest).with('MD5').returns "fingerprint"

        @puppetd.expects(:puts).with "fingerprint"

        @puppetd.fingerprint
      end

      it "should fingerprint the certificate request if no certificate have been signed" do
        @ssl_host.stubs(:certificate).returns(nil)
        @ssl_host.stubs(:certificate_request).returns(@cert)
        @cert.stubs(:digest).with('MD5').returns "fingerprint"

        @puppetd.expects(:puts).with "fingerprint"

        @puppetd.fingerprint
      end
    end

    describe "without --onetime and --fingerprint" do
      before :each do
        Puppet.stubs(:notice)
      end

      it "should start our daemon" do
        @daemon.expects(:start)

        execute_agent
      end
    end
  end

  def execute_agent
    @puppetd.setup
    @puppetd.run_command
  end
end
