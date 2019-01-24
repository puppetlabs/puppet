require 'spec_helper'

require 'puppet/application/device'
require 'puppet/util/network_device/config'
require 'ostruct'
require 'puppet/configurer'
require 'puppet/application/apply'

describe Puppet::Application::Device do
  include PuppetSpec::Files

  before :each do
    @device = Puppet::Application[:device]
    @device.preinit
    allow(Puppet::Util::Log).to receive(:newdestination)

    allow(Puppet::Node.indirection).to receive(:terminus_class=)
    allow(Puppet::Node.indirection).to receive(:cache_class=)
    allow(Puppet::Node::Facts.indirection).to receive(:terminus_class=)
  end

  it "should operate in agent run_mode" do
    expect(@device.class.run_mode.name).to eq(:agent)
  end

  it "should declare a main command" do
    expect(@device).to respond_to(:main)
  end

  it "should declare a preinit block" do
    expect(@device).to respond_to(:preinit)
  end

  describe "in preinit" do
    before :each do
      allow(@device).to receive(:trap)
    end

    it "should catch INT" do
      expect(Signal).to receive(:trap).with(:INT)

      @device.preinit
    end

    it "should init waitforcert to nil" do
      @device.preinit

      expect(@device.options[:waitforcert]).to be_nil
    end

    it "should init target to nil" do
      @device.preinit

      expect(@device.options[:target]).to be_nil
    end
  end

  describe "when handling options" do
    before do
      allow(@device.command_line).to receive(:args).and_return([])
    end

    [:centrallogging, :debug, :verbose,].each do |option|
      it "should declare handle_#{option} method" do
        expect(@device).to respond_to("handle_#{option}".to_sym)
      end

      it "should store argument value when calling handle_#{option}" do
        allow(@device.options).to receive(:[]=).with(option, 'arg')
        @device.send("handle_#{option}".to_sym, 'arg')
      end
    end

    it "should set waitforcert to 0 with --onetime and if --waitforcert wasn't given" do
      Puppet[:onetime] = true
      expect_any_instance_of(Puppet::SSL::Host).to receive(:wait_for_cert).with(0)
      @device.setup_host
    end

    it "should use supplied waitforcert when --onetime is specified" do
      Puppet[:onetime] = true
      @device.handle_waitforcert(60)
      expect_any_instance_of(Puppet::SSL::Host).to receive(:wait_for_cert).with(60)
      @device.setup_host
    end

    it "should use a default value for waitforcert when --onetime and --waitforcert are not specified" do
      expect_any_instance_of(Puppet::SSL::Host).to receive(:wait_for_cert).with(120)
      @device.setup_host
    end

    it "should use the waitforcert setting when checking for a signed certificate" do
      Puppet[:waitforcert] = 10
      expect_any_instance_of(Puppet::SSL::Host).to receive(:wait_for_cert).with(10)
      @device.setup_host
    end

    it "should set the log destination with --logdest" do
      allow(@device.options).to receive(:[]=).with(:setdest, anything)
      expect(Puppet::Log).to receive(:newdestination).with("console")

      @device.handle_logdest("console")
    end

    it "should put the setdest options to true" do
      expect(@device.options).to receive(:[]=).with(:setdest, true)

      @device.handle_logdest("console")
    end

    it "should parse the log destination from the command line" do
      allow(@device.command_line).to receive(:args).and_return(%w{--logdest /my/file})

      expect(Puppet::Util::Log).to receive(:newdestination).with("/my/file")

      @device.parse_options
    end

    it "should store the waitforcert options with --waitforcert" do
      expect(@device.options).to receive(:[]=).with(:waitforcert,42)

      @device.handle_waitforcert("42")
    end

    it "should set args[:Port] with --port" do
      @device.handle_port("42")
      expect(@device.args[:Port]).to eq("42")
    end

    it "should store the target options with --target" do
      expect(@device.options).to receive(:[]=).with(:target,'test123')

      @device.handle_target('test123')
    end

    it "should store the resource options with --resource" do
      expect(@device.options).to receive(:[]=).with(:resource,true)

      @device.handle_resource(true)
    end

    it "should store the facts options with --facts" do
      expect(@device.options).to receive(:[]=).with(:facts,true)

      @device.handle_facts(true)
    end
  end

  describe "during setup" do
    before :each do
      allow(@device.options).to receive(:[])
      Puppet[:libdir] = "/dev/null/lib"
      allow(Puppet::SSL::Host).to receive(:ca_location=)
      allow(Puppet::Transaction::Report.indirection).to receive(:terminus_class=)
      allow(Puppet::Resource::Catalog.indirection).to receive(:terminus_class=)
      allow(Puppet::Resource::Catalog.indirection).to receive(:cache_class=)
      allow(Puppet::Node::Facts.indirection).to receive(:terminus_class=)
      @host = double('host')
      allow(Puppet::SSL::Host).to receive(:new).and_return(@host)
      allow(Puppet).to receive(:settraps)
    end

    it "should call setup_logs" do
      expect(@device).to receive(:setup_logs)
      @device.setup
    end

    describe "when setting up logs" do
      before :each do
        allow(Puppet::Util::Log).to receive(:newdestination)
      end

      it "should set log level to debug if --debug was passed" do
        allow(@device.options).to receive(:[]).with(:debug).and_return(true)
        @device.setup_logs
        expect(Puppet::Util::Log.level).to eq(:debug)
      end

      it "should set log level to info if --verbose was passed" do
        allow(@device.options).to receive(:[]).with(:verbose).and_return(true)
        @device.setup_logs
        expect(Puppet::Util::Log.level).to eq(:info)
      end

      [:verbose, :debug].each do |level|
        it "should set console as the log destination with level #{level}" do
          allow(@device.options).to receive(:[]).with(level).and_return(true)

          expect(Puppet::Util::Log).to receive(:newdestination).with(:console)

          @device.setup_logs
        end
      end

      it "should set a default log destination if no --logdest" do
        allow(@device.options).to receive(:[]).with(:setdest).and_return(false)

        expect(Puppet::Util::Log).to receive(:setup_default)

        @device.setup_logs
      end
    end

    it "should set a central log destination with --centrallogs" do
      allow(@device.options).to receive(:[]).with(:centrallogs).and_return(true)
      Puppet[:server] = "puppet.reductivelabs.com"
      allow(Puppet::Util::Log).to receive(:newdestination).with(:syslog)

      expect(Puppet::Util::Log).to receive(:newdestination).with("puppet.reductivelabs.com")

      @device.setup
    end

    it "should use :main, :agent, :device and :ssl config" do
      expect(Puppet.settings).to receive(:use).with(:main, :agent, :device, :ssl)

      @device.setup
    end

    it "should install a remote ca location" do
      expect(Puppet::SSL::Host).to receive(:ca_location=).with(:remote)

      @device.setup
    end

    it "should tell the report handler to use REST" do
      expect(Puppet::Transaction::Report.indirection).to receive(:terminus_class=).with(:rest)

      @device.setup
    end

    it "should default the catalog_terminus setting to 'rest'" do
      @device.initialize_app_defaults
      expect(Puppet[:catalog_terminus]).to eq(:rest)
    end

    it "should default the node_terminus setting to 'rest'" do
      @device.initialize_app_defaults
      expect(Puppet[:node_terminus]).to eq(:rest)
    end

    it "has an application default :catalog_cache_terminus setting of 'json'" do
      expect(Puppet::Resource::Catalog.indirection).to receive(:cache_class=).with(:json)

      @device.initialize_app_defaults
      @device.setup
    end

    it "should tell the catalog cache class based on the :catalog_cache_terminus setting" do
      Puppet[:catalog_cache_terminus] = "yaml"
      expect(Puppet::Resource::Catalog.indirection).to receive(:cache_class=).with(:yaml)

      @device.initialize_app_defaults
      @device.setup
    end

    it "should not set catalog cache class if :catalog_cache_terminus is explicitly nil" do
      Puppet[:catalog_cache_terminus] = nil
      expect(Puppet::Resource::Catalog.indirection).not_to receive(:cache_class=)

      @device.initialize_app_defaults
      @device.setup
    end

    it "should default the facts_terminus setting to 'network_device'" do
      @device.initialize_app_defaults
      expect(Puppet[:facts_terminus]).to eq(:network_device)
    end
  end

  describe "when initializing each devices SSL" do
    before(:each) do
      @host = double('host')
      allow(@host).to receive(:wait_for_cert)
      allow(Puppet::SSL::Host).to receive(:new).and_return(@host)
    end

    it "should create a new ssl host" do
      expect(Puppet::SSL::Host).to receive(:new).and_return(@host)
      @device.setup_host
    end

    it "should wait for a certificate" do
      allow(@device.options).to receive(:[]).with(:waitforcert).and_return(123)
      expect(@host).to receive(:wait_for_cert).with(123)

      @device.setup_host
    end
  end

  describe "when running" do
    before :each do
      allow(@device.options).to receive(:[]).with(:fingerprint).and_return(false)
      allow(Puppet).to receive(:notice)
      allow(@device.options).to receive(:[]).with(:detailed_exitcodes).and_return(false)
      allow(@device.options).to receive(:[]).with(:target).and_return(nil)
      allow(@device.options).to receive(:[]).with(:apply).and_return(nil)
      allow(@device.options).to receive(:[]).with(:facts).and_return(false)
      allow(@device.options).to receive(:[]).with(:resource).and_return(false)
      allow(@device.options).to receive(:[]).with(:to_yaml).and_return(false)
      allow(@device.options).to receive(:[]).with(:libdir).and_return(nil)
      allow(@device.options).to receive(:[]).with(:client)
      allow(@device.command_line).to receive(:args).and_return([])
      allow(Puppet::Util::NetworkDevice::Config).to receive(:devices).and_return({})
    end

    it "should dispatch to main" do
      allow(@device).to receive(:main)
      @device.run_command
    end

    it "should exit if resource is requested without target" do
      allow(@device.options).to receive(:[]).with(:resource).and_return(true)
      expect { @device.main }.to raise_error(RuntimeError, "resource command requires target")
    end

    it "should exit if facts is requested without target" do
      allow(@device.options).to receive(:[]).with(:facts).and_return(true)
      expect { @device.main }.to raise_error(RuntimeError, "facts command requires target")
    end

    it "should get the device list" do
      device_hash = {}
      expect(Puppet::Util::NetworkDevice::Config).to receive(:devices).and_return(device_hash)
      expect { @device.main }.to exit_with 1
    end

    it "should get a single device, when a valid target parameter is passed" do
      allow(@device.options).to receive(:[]).with(:target).and_return('device1')

      device_hash = {
        "device1" => OpenStruct.new(:name => "device1", :url => "ssh://user:pass@testhost", :provider => "cisco"),
        "device2" => OpenStruct.new(:name => "device2", :url => "https://user:pass@testhost/some/path", :provider => "rest"),
      }

      expect(Puppet::Util::NetworkDevice::Config).to receive(:devices).and_return(device_hash)
      expect(URI).to receive(:parse).with("ssh://user:pass@testhost")
      expect(URI).not_to receive(:parse).with("https://user:pass@testhost/some/path")
      expect { @device.main }.to exit_with 1
    end

    it "should exit, when an invalid target parameter is passed" do
      allow(@device.options).to receive(:[]).with(:target).and_return('bla')
      device_hash = {
        "device1" => OpenStruct.new(:name => "device1", :url => "ssh://user:pass@testhost", :provider => "cisco"),
      }

      expect(Puppet::Util::NetworkDevice::Config).to receive(:devices).and_return(device_hash)
      expect(Puppet).not_to receive(:info).with(/starting applying configuration to/)
      expect { @device.main }.to raise_error(RuntimeError, /Target device \/ certificate 'bla' not found in .*\.conf/)
    end

    it "should error if target is passed and the apply path is incorrect" do
      allow(@device.options).to receive(:[]).with(:apply).and_return('file.pp')
      allow(@device.options).to receive(:[]).with(:target).and_return('device1')

      expect(File).to receive(:file?).and_return(false)
      expect { @device.main }.to raise_error(RuntimeError, /does not exist, cannot apply/)
    end

    it "should run an apply, and not create the state folder" do
      allow(@device.options).to receive(:[]).with(:apply).and_return('file.pp')
      allow(@device.options).to receive(:[]).with(:target).and_return('device1')
      device_hash = {
        "device1" => OpenStruct.new(:name => "device1", :url => "ssh://user:pass@testhost", :provider => "cisco"),
      }
      expect(Puppet::Util::NetworkDevice::Config).to receive(:devices).and_return(device_hash)
      allow(Puppet::Util::NetworkDevice).to receive(:init)
      expect(File).to receive(:file?).and_return(true)

      allow(::File).to receive(:directory?).and_return(false)
      state_path = tmpfile('state')
      Puppet[:statedir] = state_path
      expect(File).to receive(:directory?).with(state_path).and_return(true)
      expect(FileUtils).not_to receive(:mkdir_p).with(state_path)

      expect(Puppet::Util::CommandLine).to receive(:new).once
      expect(Puppet::Application::Apply).to receive(:new).once

      expect(Puppet::Configurer).not_to receive(:new)
      expect { @device.main }.to exit_with 1
    end

    it "should run an apply, and create the state folder" do
      allow(@device.options).to receive(:[]).with(:apply).and_return('file.pp')
      allow(@device.options).to receive(:[]).with(:target).and_return('device1')
      device_hash = {
        "device1" => OpenStruct.new(:name => "device1", :url => "ssh://user:pass@testhost", :provider => "cisco"),
      }
      expect(Puppet::Util::NetworkDevice::Config).to receive(:devices).and_return(device_hash)
      allow(Puppet::Util::NetworkDevice).to receive(:init)
      expect(File).to receive(:file?).and_return(true)
      expect(FileUtils).to receive(:mkdir_p).once

      expect(Puppet::Util::CommandLine).to receive(:new).once
      expect(Puppet::Application::Apply).to receive(:new).once

      expect(Puppet::Configurer).not_to receive(:new)
      expect { @device.main }.to exit_with 1
    end

    it "should exit if the device list is empty" do
      expect { @device.main }.to exit_with 1
    end

    describe "for each device" do
      before(:each) do
        Puppet[:vardir] = make_absolute("/dummy")
        Puppet[:confdir] = make_absolute("/dummy")
        Puppet[:certname] = "certname"
        @device_hash = {
          "device1" => OpenStruct.new(:name => "device1", :url => "ssh://user:pass@testhost", :provider => "cisco"),
          "device2" => OpenStruct.new(:name => "device2", :url => "https://user:pass@testhost/some/path", :provider => "rest"),
        }
        allow(Puppet::Util::NetworkDevice::Config).to receive(:devices).and_return(@device_hash)
        allow(Puppet).to receive(:[]=)
        allow(Puppet.settings).to receive(:use)
        allow(@device).to receive(:setup_host)
        allow(Puppet::Util::NetworkDevice).to receive(:init)
        @configurer = double('configurer')
        allow(@configurer).to receive(:run)
        allow(Puppet::Configurer).to receive(:new).and_return(@configurer)
      end

      it "should set vardir to the device vardir" do
        expect(Puppet).to receive(:[]=).with(:vardir, make_absolute("/dummy/devices/device1"))
        expect { @device.main }.to exit_with 1
      end

      it "should set confdir to the device confdir" do
        expect(Puppet).to receive(:[]=).with(:confdir, make_absolute("/dummy/devices/device1"))
        expect { @device.main }.to exit_with 1
      end

      it "should set certname to the device certname" do
        expect(Puppet).to receive(:[]=).with(:certname, "device1")
        expect(Puppet).to receive(:[]=).with(:certname, "device2")
        expect { @device.main }.to exit_with 1
      end

      it "should raise an error if no type is given" do
        allow(@device.options).to receive(:[]).with(:resource).and_return(true)
        allow(@device.options).to receive(:[]).with(:target).and_return('device1')
        allow(@device.command_line).to receive(:args).and_return([])
        expect(Puppet).to receive(:log_exception) { |e| expect(e.message).to eq("You must specify the type to display") }
        expect { @device.main }.to exit_with 1
      end

      it "should raise an error if the type is not found" do
        allow(@device.options).to receive(:[]).with(:resource).and_return(true)
        allow(@device.options).to receive(:[]).with(:target).and_return('device1')
        allow(@device.command_line).to receive(:args).and_return(['nope'])
        expect(Puppet).to receive(:log_exception) { |e| expect(e.message).to eq("Could not find type nope") }
        expect { @device.main }.to exit_with 1
      end

      it "should retrieve all resources of a type" do
        allow(@device.options).to receive(:[]).with(:resource).and_return(true)
        allow(@device.options).to receive(:[]).with(:target).and_return('device1')
        allow(@device.command_line).to receive(:args).and_return(['user'])
        expect(Puppet::Resource.indirection).to receive(:search).with('user/', {}).and_return([])
        expect { @device.main }.to exit_with 0
      end

      it "should retrieve named resources of a type" do
        resource = Puppet::Type.type(:user).new(:name => "jim").to_resource
        allow(@device.options).to receive(:[]).with(:resource).and_return(true)
        allow(@device.options).to receive(:[]).with(:target).and_return('device1')
        allow(@device.command_line).to receive(:args).and_return(['user', 'jim'])
        expect(Puppet::Resource.indirection).to receive(:find).with('user/jim').and_return(resource)
        expect(@device).to receive(:puts).with("user { 'jim':\n}")
        expect { @device.main }.to exit_with 0
      end

      it "should output resources as YAML" do
        resources = [
          Puppet::Type.type(:user).new(:name => "title").to_resource,
        ]
        allow(@device.options).to receive(:[]).with(:resource).and_return(true)
        allow(@device.options).to receive(:[]).with(:target).and_return('device1')
        allow(@device.options).to receive(:[]).with(:to_yaml).and_return(true)
        allow(@device.command_line).to receive(:args).and_return(['user'])
        expect(Puppet::Resource.indirection).to receive(:search).with('user/', {}).and_return(resources)
        expect(@device).to receive(:puts).with("user:\n  title:\n")
        expect { @device.main }.to exit_with 0
      end

      it "should retrieve facts" do
        indirection_fact_values = {"operatingsystem"=>"cisco_ios","clientcert"=>"3750"}
        indirection_facts = Puppet::Node::Facts.new("nil", indirection_fact_values)
        allow(@device.options).to receive(:[]).with(:facts).and_return(true)
        allow(@device.options).to receive(:[]).with(:target).and_return('device1')
        expect(Puppet::Node::Facts.indirection).to receive(:find).with(nil, anything()).and_return(indirection_facts)
        expect(@device).to receive(:puts).with(/name.*3750.*\n.*values.*\n.*operatingsystem.*cisco_ios/)
        expect { @device.main }.to exit_with 0
      end

      it "should make sure all the required folders and files are created" do
        expect(Puppet.settings).to receive(:use).with(:main, :agent, :ssl).twice
        expect { @device.main }.to exit_with 1
      end

      it "should initialize the device singleton" do
        expect(Puppet::Util::NetworkDevice).to receive(:init).with(@device_hash["device1"]).ordered
        expect(Puppet::Util::NetworkDevice).to receive(:init).with(@device_hash["device2"]).ordered
        expect { @device.main }.to exit_with 1
      end

      it "should retrieve plugins and print the device url scheme, host, and port" do
        allow(Puppet).to receive(:info)
        expect(Puppet).to receive(:info).with("Retrieving pluginfacts")
        expect(Puppet).to receive(:info).with("starting applying configuration to device1 at ssh://testhost")
        expect(Puppet).to receive(:info).with("starting applying configuration to device2 at https://testhost:443/some/path")
        expect { @device.main }.to exit_with 1
      end

      it "should setup the SSL context" do
        expect(@device).to receive(:setup_host).twice
        expect { @device.main }.to exit_with 1
      end

      it "should launch a configurer for this device" do
        expect(@configurer).to receive(:run).twice
        expect { @device.main }.to exit_with 1
      end

      it "exits 1 when configurer raises error" do
        expect(@configurer).to receive(:run).and_raise(Puppet::Error).ordered
        expect(@configurer).to receive(:run).and_return(0).ordered
        expect { @device.main }.to exit_with 1
      end

      it "exits 0 when run happens without puppet errors but with failed run" do
        allow(@configurer).to receive(:run).and_return(6, 2)
        expect { @device.main }.to exit_with 0
      end

      it "should make the Puppet::Pops::Loaaders available" do
        expect(@configurer).to receive(:run).with(:network_device => true, :pluginsync => true) do
          fail('Loaders not available') unless Puppet.lookup(:loaders) { nil }.is_a?(Puppet::Pops::Loaders)
          true
        end.and_return(6, 2)
        expect { @device.main }.to exit_with 0
      end

      it "exits 2 when --detailed-exitcodes and successful runs" do
        allow(@device.options).to receive(:[]).with(:detailed_exitcodes).and_return(true)
        allow(@configurer).to receive(:run).and_return(0, 2)
        expect { @device.main }.to exit_with 2
      end

      it "exits 1 when --detailed-exitcodes and failed parse" do
        @configurer = double('configurer')
        allow(Puppet::Configurer).to receive(:new).and_return(@configurer)
        allow(@device.options).to receive(:[]).with(:detailed_exitcodes).and_return(true)
        allow(@configurer).to receive(:run).and_return(6, 1)
        expect { @device.main }.to exit_with 7
      end

      it "exits 6 when --detailed-exitcodes and failed run" do
        @configurer = double('configurer')
        allow(Puppet::Configurer).to receive(:new).and_return(@configurer)
        allow(@device.options).to receive(:[]).with(:detailed_exitcodes).and_return(true)
        allow(@configurer).to receive(:run).and_return(6, 2)
        expect { @device.main }.to exit_with 6
      end

      [:vardir, :confdir].each do |setting|
        it "should cleanup the #{setting} setting after the run" do
          all_devices = Set.new(@device_hash.keys.map do |device_name| make_absolute("/dummy/devices/#{device_name}") end)
          found_devices = Set.new()

          # a block to use in a few places later to validate the updated settings
          p = Proc.new do |my_setting, my_value|
            expect(all_devices).to include(my_value)
            found_devices.add(my_value)
          end

          all_devices.size.times do
            ## one occurrence of set / run / set("/dummy") for each device
            expect(Puppet).to receive(:[]=, &p).with(setting, anything).ordered
            expect(@configurer).to receive(:run).ordered
            expect(Puppet).to receive(:[]=).with(setting, make_absolute("/dummy")).ordered
          end

          expect { @device.main }.to exit_with 1

          expect(found_devices).to eq(all_devices)
        end
      end

      it "should cleanup the certname setting after the run" do
        all_devices = Set.new(@device_hash.keys)
        found_devices = Set.new()

        # a block to use in a few places later to validate the updated settings
        p = Proc.new do |my_setting, my_value|
          expect(all_devices).to include(my_value)
          found_devices.add(my_value)
        end

        allow(Puppet).to receive(:[]=)
        all_devices.size.times do
          ## one occurrence of set / run / set("certname") for each device
          expect(Puppet).to receive(:[]=, &p).with(:certname, anything).ordered
          expect(@configurer).to receive(:run).ordered
          expect(Puppet).to receive(:[]=).with(:certname, "certname").ordered
        end


        expect { @device.main }.to exit_with 1

        # make sure that we were called with each of the defined devices
        expect(found_devices).to eq(all_devices)
      end

      it "should expire all cached attributes" do
        expect(Puppet::SSL::Host).to receive(:reset).twice

        expect { @device.main }.to exit_with 1
      end
    end
  end
end
