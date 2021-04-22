require 'spec_helper'

require 'puppet/agent'
require 'puppet/application/agent'
require 'puppet/daemon'

describe Puppet::Application::Agent do
  include PuppetSpec::Files

  let(:machine) { double(ensure_client_certificate: nil) }

  before :each do
    @puppetd = Puppet::Application[:agent]

    @agent = double('agent')
    allow(Puppet::Agent).to receive(:new).and_return(@agent)

    @daemon = Puppet::Daemon.new(@agent, nil)
    allow(@daemon).to receive(:daemonize)
    allow(@daemon).to receive(:start)
    allow(@daemon).to receive(:stop)
    allow(Puppet::Daemon).to receive(:new).and_return(@daemon)
    Puppet[:daemonize] = false

    @puppetd.preinit
    allow(Puppet::Util::Log).to receive(:newdestination)

    allow(Puppet::Node.indirection).to receive(:terminus_class=)
    allow(Puppet::Node.indirection).to receive(:cache_class=)
    allow(Puppet::Node::Facts.indirection).to receive(:terminus_class=)

    allow(Puppet.settings).to receive(:use)
    allow(Puppet::SSL::StateMachine).to receive(:new).and_return(machine)
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
      expect(Signal).to receive(:trap).with(:INT)

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
      allow(@puppetd.command_line).to receive(:args).and_return([])
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

    it "should log the agent start time" do
      expect(@puppetd.options[:start_time]).to be_a(Time)
    end

    it "should set waitforcert to 0 with --onetime and if --waitforcert wasn't given" do
      allow(@agent).to receive(:run).and_return(2)
      Puppet[:onetime] = true

      expect(Puppet::SSL::StateMachine).to receive(:new).with(waitforcert: 0).and_return(machine)

      expect { execute_agent }.to exit_with 0
    end

    it "should use supplied waitforcert when --onetime is specified" do
      allow(@agent).to receive(:run).and_return(2)
      Puppet[:onetime] = true
      @puppetd.handle_waitforcert(60)

      expect(Puppet::SSL::StateMachine).to receive(:new).with(waitforcert: 60).and_return(machine)

      expect { execute_agent }.to exit_with 0
    end

    it "should use a default value for waitforcert when --onetime and --waitforcert are not specified" do
      expect(Puppet::SSL::StateMachine).to receive(:new).with(waitforcert: 120).and_return(machine)

      execute_agent
    end

    it "should register ssl OIDs" do
      expect(Puppet::SSL::StateMachine).to receive(:new).with(waitforcert: 120).and_return(double(ensure_client_certificate: nil))
      expect(Puppet::SSL::Oids).to receive(:register_puppet_oids)

      execute_agent
    end

    it "should use the waitforcert setting when checking for a signed certificate" do
      Puppet[:waitforcert] = 10

      expect(Puppet::SSL::StateMachine).to receive(:new).with(waitforcert: 10).and_return(machine)

      execute_agent
    end

    it "should set the log destination with --logdest" do
      expect(Puppet::Log).to receive(:newdestination).with("console")

      @puppetd.handle_logdest("console")
    end

    it "should put the setdest options to true" do
      @puppetd.handle_logdest("console")

      expect(@puppetd.options[:setdest]).to eq(true)
    end

    it "should parse the log destination from the command line" do
      allow(@puppetd.command_line).to receive(:args).and_return(%w{--logdest /my/file})

      expect(Puppet::Util::Log).to receive(:newdestination).with("/my/file")

      @puppetd.parse_options
    end

    it "should store the waitforcert options with --waitforcert" do
      @puppetd.handle_waitforcert("42")

      expect(@puppetd.options[:waitforcert]).to eq(42)
    end
  end

  describe "during setup" do
    before :each do
      allow(Puppet).to receive(:info)
      Puppet[:libdir] = "/dev/null/lib"
      allow(Puppet::Transaction::Report.indirection).to receive(:terminus_class=)
      allow(Puppet::Transaction::Report.indirection).to receive(:cache_class=)
      allow(Puppet::Resource::Catalog.indirection).to receive(:terminus_class=)
      allow(Puppet::Resource::Catalog.indirection).to receive(:cache_class=)
      allow(Puppet::Node::Facts.indirection).to receive(:terminus_class=)
    end

    it "should not run with extra arguments" do
      allow(@puppetd.command_line).to receive(:args).and_return(%w{disable})
      expect{@puppetd.setup}.to raise_error ArgumentError, /does not take parameters/
    end

    describe "with --test" do
      it "should call setup_test" do
        @puppetd.options[:test] = true
        expect(@puppetd).to receive(:setup_test)

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
      expect(@puppetd).to receive(:setup_logs)
      @puppetd.setup
    end

    describe "when setting up logs" do
      before :each do
        allow(Puppet::Util::Log).to receive(:newdestination)
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

          allow(Puppet::Util::Log).to receive(:newdestination)
          expect(Puppet::Util::Log).to receive(:newdestination).with(:console).exactly(:once)

          @puppetd.setup_logs
        end
      end

      it "should set a default log destination if no --logdest" do
        @puppetd.options[:setdest] = false

        expect(Puppet::Util::Log).to receive(:setup_default)

        @puppetd.setup_logs
      end
    end

    it "should print puppet config if asked to in Puppet config" do
      Puppet[:configprint] = "plugindest"
      expect(Puppet.settings).to receive(:print_configs).and_return(true)
      expect { execute_agent }.to exit_with 0
    end

    it "should exit after printing puppet config if asked to in Puppet config" do
      path = make_absolute('/my/path')
      Puppet[:modulepath] = path
      Puppet[:configprint] = "modulepath"
      expect_any_instance_of(Puppet::Settings).to receive(:puts).with(path)
      expect { execute_agent }.to exit_with 0
    end

    it "should use :main, :puppetd, and :ssl" do
      expect(Puppet.settings).to receive(:use).with(:main, :agent, :ssl)

      @puppetd.setup
    end

    it "should setup an agent in fingerprint mode" do
      @puppetd.options[:fingerprint] = true
      expect(@puppetd).not_to receive(:setup_agent)

      @puppetd.setup
    end

    it "should tell the report handler to use REST" do
      expect(Puppet::Transaction::Report.indirection).to receive(:terminus_class=).with(:rest)

      @puppetd.setup
    end

    it "should tell the report handler to cache locally as yaml" do
      expect(Puppet::Transaction::Report.indirection).to receive(:cache_class=).with(:yaml)

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
      expect(Puppet::Resource::Catalog.indirection).to receive(:cache_class=).with(:json)

      @puppetd.initialize_app_defaults
      @puppetd.setup
    end

    it "should tell the catalog cache class based on the :catalog_cache_terminus setting" do
      Puppet[:catalog_cache_terminus] = "yaml"
      expect(Puppet::Resource::Catalog.indirection).to receive(:cache_class=).with(:yaml)

      @puppetd.initialize_app_defaults
      @puppetd.setup
    end

    it "should not set catalog cache class if :catalog_cache_terminus is explicitly nil" do
      Puppet[:catalog_cache_terminus] = nil
      expect(Puppet::Resource::Catalog.indirection).not_to receive(:cache_class=)

      @puppetd.initialize_app_defaults
      @puppetd.setup
    end

    it "should default facts_terminus setting to 'facter'" do
      @puppetd.initialize_app_defaults
      expect(Puppet[:facts_terminus]).to eq(:facter)
    end

    it "should create an agent" do
      allow(Puppet::Agent).to receive(:new).with(Puppet::Configurer)

      @puppetd.setup
    end

    [:enable, :disable].each do |action|
      it "should delegate to enable_disable_client if we #{action} the agent" do
        @puppetd.options[action] = true
        expect(@puppetd).to receive(:enable_disable_client).with(@agent)

        @puppetd.setup
      end
    end

    describe "when enabling or disabling agent" do
      [:enable, :disable].each do |action|
        it "should call client.#{action}" do
          @puppetd.options[action] = true
          expect(@agent).to receive(action)
          expect { execute_agent }.to exit_with 0
        end
      end

      it "should pass the disable message when disabling" do
        @puppetd.options[:disable] = true
        @puppetd.options[:disable_message] = "message"
        expect(@agent).to receive(:disable).with("message")

        expect { execute_agent }.to exit_with 0
      end

      it "should pass the default disable message when disabling without a message" do
        @puppetd.options[:disable] = true
        @puppetd.options[:disable_message] = nil
        expect(@agent).to receive(:disable).with("reason not specified")

        expect { execute_agent }.to exit_with 0
      end
    end

    it "should inform the daemon about our agent if :client is set to 'true'" do
      @puppetd.options[:client] = true

      execute_agent

      expect(@daemon.agent).to eq(@agent)
    end

    it "should daemonize if needed" do
      allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)
      Puppet[:daemonize] = true
      allow(Signal).to receive(:trap)

      expect(@daemon).to receive(:daemonize)

      execute_agent
    end

    it "should wait for a certificate" do
      @puppetd.options[:waitforcert] = 123

      expect(Puppet::SSL::StateMachine).to receive(:new).with(waitforcert: 123).and_return(machine)

      execute_agent
    end

    describe "when setting up for fingerprint" do
      before(:each) do
        @puppetd.options[:fingerprint] = true
      end

      it "should not setup as an agent" do
        expect(@puppetd).not_to receive(:setup_agent)
        @puppetd.setup
      end

      it "should not create an agent" do
        expect(Puppet::Agent).not_to receive(:new).with(Puppet::Configurer)
        @puppetd.setup
      end

      it "should not daemonize" do
        expect(@daemon).not_to receive(:daemonize)
        @puppetd.setup
      end
    end

    describe "when configuring agent for catalog run" do
      it "should set should_fork as true when running normally" do
        expect(Puppet::Agent).to receive(:new).with(anything, true)
        @puppetd.setup
      end

      it "should not set should_fork as false for --onetime" do
        Puppet[:onetime] = true
        expect(Puppet::Agent).to receive(:new).with(anything, false)
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

      expect(@puppetd).to receive(:fingerprint)

      execute_agent
    end

    it "should dispatch to onetime if --onetime is used" do
      Puppet[:onetime] = true

      expect(@puppetd).to receive(:onetime)

      execute_agent
    end

    it "should dispatch to main if --onetime and --fingerprint are not used" do
      Puppet[:onetime] = false

      expect(@puppetd).to receive(:main)

      execute_agent
    end

    describe "with --onetime" do
      before :each do
        allow(@agent).to receive(:run).and_return(:report)
        Puppet[:onetime] = true
        @puppetd.options[:client] = :client
        @puppetd.options[:detailed_exitcodes] = false


      end

      it "should setup traps" do
        expect(@daemon).to receive(:set_signal_traps)

        expect { execute_agent }.to exit_with 0
      end

      it "should let the agent run" do
        expect(@agent).to receive(:run).and_return(:report)

        expect { execute_agent }.to exit_with 0
      end

      it "should run the agent with the supplied job_id" do
        @puppetd.options[:job_id] = 'special id'
        expect(@agent).to receive(:run).with(hash_including(:job_id => 'special id')).and_return(:report)

        expect { execute_agent }.to exit_with 0
      end

      it "should stop the daemon" do
        expect(@daemon).to receive(:stop).with(:exit => false)

        expect { execute_agent }.to exit_with 0
      end

      describe "and --detailed-exitcodes" do
        before :each do
          @puppetd.options[:detailed_exitcodes] = true
        end

        it "should exit with agent computed exit status" do
          Puppet[:noop] = false
          allow(@agent).to receive(:run).and_return(666)

          expect { execute_agent }.to exit_with 666
        end

        it "should exit with the agent's exit status, even if --noop is set." do
          Puppet[:noop] = true
          allow(@agent).to receive(:run).and_return(666)

          expect { execute_agent }.to exit_with 666
        end
      end
    end

    describe "with --fingerprint" do
      before :each do
        @puppetd.options[:fingerprint] = true
        @puppetd.options[:digest] = :MD5
      end

      def expected_fingerprint(name, x509)
        digest = OpenSSL::Digest.new(name).hexdigest(x509.to_der)
        digest.scan(/../).join(':').upcase
      end

      it "should fingerprint the certificate if it exists" do
        cert = cert_fixture('signed.pem')
        allow_any_instance_of(Puppet::X509::CertProvider).to receive(:load_client_cert).and_return(cert)

        expect(@puppetd).to receive(:puts).with("(MD5) #{expected_fingerprint('md5', cert)}")

        @puppetd.fingerprint
      end

      it "should fingerprint the request if it exists" do
        request = request_fixture('request.pem')
        allow_any_instance_of(Puppet::X509::CertProvider).to receive(:load_client_cert).and_return(nil)
        allow_any_instance_of(Puppet::X509::CertProvider).to receive(:load_request).and_return(request)

        expect(@puppetd).to receive(:puts).with("(MD5) #{expected_fingerprint('md5', request)}")

        @puppetd.fingerprint
      end

      it "should print an error to stderr if neither exist" do
        allow_any_instance_of(Puppet::X509::CertProvider).to receive(:load_client_cert).and_return(nil)
        allow_any_instance_of(Puppet::X509::CertProvider).to receive(:load_request).and_return(nil)

        expect {
          @puppetd.fingerprint
        }.to exit_with(1)
         .and output(/Fingerprint asked but neither the certificate, nor the certificate request have been issued/).to_stderr
      end

      it "should log an error if an exception occurs" do
        allow_any_instance_of(Puppet::X509::CertProvider).to receive(:load_client_cert).and_raise(Puppet::Error, "Invalid PEM")

        expect {
          @puppetd.fingerprint
        }.to exit_with(1)

        expect(@logs).to include(an_object_having_attributes(message: /Failed to generate fingerprint: Invalid PEM/))
      end
    end

    describe "without --onetime and --fingerprint" do
      before :each do
        allow(Puppet).to receive(:notice)
      end

      it "should start our daemon" do
        expect(@daemon).to receive(:start)

        execute_agent
      end
    end
  end

  describe "when starting in daemon mode on non-windows", :unless => Puppet.features.microsoft_windows? do
    before :each do
      allow(Puppet).to receive(:notice)
      Puppet[:daemonize] = true
      allow(Puppet::SSL::StateMachine).to receive(:new).and_return(machine)
    end

    it "should not print config in default mode" do
      execute_agent
      expect(@logs).to be_empty
    end

    it "should print config in debug mode" do
      @puppetd.options[:debug] = true
      execute_agent
      expect(@logs).to include(an_object_having_attributes(level: :debug, message: /agent_catalog_run_lockfile=/))
    end
  end

  def execute_agent
    @puppetd.setup
    @puppetd.run_command
  end
end
