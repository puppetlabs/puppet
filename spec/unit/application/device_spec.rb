require 'spec_helper'

require 'ostruct'
require 'puppet/application/apply'
require 'puppet/application/device'
require 'puppet/configurer'
require 'puppet/util/network_device/config'

describe Puppet::Application::Device do
  include PuppetSpec::Files

  let(:device) do
    dev = Puppet::Application[:device]
    allow(dev).to receive(:trap)
    allow(Signal).to receive(:trap)
    dev.preinit
    dev
  end
  let(:ssl_context) { instance_double(Puppet::SSL::SSLContext, 'ssl_context') }
  let(:state_machine) { instance_double(Puppet::SSL::StateMachine, 'state machine') }

  before do
    allow(Puppet::Node::Facts.indirection).to receive(:terminus_class=)
    allow(Puppet::Node.indirection).to receive(:cache_class=)
    allow(Puppet::Node.indirection).to receive(:terminus_class=)
    allow(Puppet::Resource::Catalog.indirection).to receive(:cache_class=)
    allow(Puppet::Resource::Catalog.indirection).to receive(:terminus_class=)
    allow(Puppet::Transaction::Report.indirection).to receive(:terminus_class=)

    allow(Puppet::Util::Log).to receive(:newdestination)

    allow(state_machine).to receive(:ensure_client_certificate).and_return(ssl_context)
    allow(Puppet::SSL::StateMachine).to receive(:new).and_return(state_machine)
  end

  it "operates in agent run_mode" do
    expect(device.class.run_mode.name).to eq(:agent)
  end

  it "declares a main command" do
    expect(device).to respond_to(:main)
  end

  it "declares a preinit block" do
    expect(device).to respond_to(:preinit)
  end

  describe "in preinit" do
    before do
    end

    it "catches INT" do
      device

      expect(Signal).to have_received(:trap).with(:INT)
    end

    it "inits waitforcert to nil" do
      expect(device.options[:waitforcert]).to be_nil
    end

    it "inits target to nil" do
      expect(device.options[:target]).to be_nil
    end
  end

  describe "when handling options" do
    before do
      Puppet[:certname] = 'device.example.com'
      allow(device.command_line).to receive(:args).and_return([])
    end

    [:centrallogging, :debug, :verbose,].each do |option|
      it "should declare handle_#{option} method" do
        expect(device).to respond_to("handle_#{option}".to_sym)
      end

      it "should store argument value when calling handle_#{option}" do
        allow(device.options).to receive(:[]=).with(option, 'arg')
        device.send("handle_#{option}".to_sym, 'arg')
      end
    end

    context 'when setting --onetime' do
      before do
        Puppet[:onetime] = true
      end

      context 'without --waitforcert' do
        it "defaults waitforcert to 0" do
          device.setup_context

          expect(Puppet::SSL::StateMachine).to have_received(:new).with(hash_including(waitforcert: 0))
        end
      end

      context 'with --waitforcert=60' do
        it "uses supplied waitforcert" do
          device.handle_waitforcert(60)
          device.setup_context

          expect(Puppet::SSL::StateMachine).to have_received(:new).with(hash_including(waitforcert: 60))
        end
      end
    end

    context 'without setting --onetime' do
      before do
        Puppet[:onetime] = false
      end

      it "uses a default value for waitforcert when --onetime and --waitforcert are not specified" do
        device.setup_context
        expect(Puppet::SSL::StateMachine).to have_received(:new).with(hash_including(waitforcert: 120))
      end

      it "uses the waitforcert setting when checking for a signed certificate" do
        Puppet[:waitforcert] = 10
        device.setup_context
        expect(Puppet::SSL::StateMachine).to have_received(:new).with(hash_including(waitforcert: 10))
      end
    end

    it "sets the log destination with --logdest" do
      allow(device.options).to receive(:[]=).with(:setdest, anything)
      expect(Puppet::Log).to receive(:newdestination).with("console")

      device.handle_logdest("console")
    end

    it "puts the setdest options to true" do
      expect(device.options).to receive(:[]=).with(:setdest, true)

      device.handle_logdest("console")
    end

    it "parses the log destination from the command line" do
      allow(device.command_line).to receive(:args).and_return(%w{--logdest /my/file})

      expect(Puppet::Util::Log).to receive(:newdestination).with("/my/file")

      device.parse_options
    end

    it "stores the waitforcert options with --waitforcert" do
      expect(device.options).to receive(:[]=).with(:waitforcert,42)

      device.handle_waitforcert("42")
    end

    it "sets args[:Port] with --port" do
      device.handle_port("42")
      expect(device.args[:Port]).to eq("42")
    end

    it "stores the target options with --target" do
      expect(device.options).to receive(:[]=).with(:target,'test123')

      device.handle_target('test123')
    end

    it "stores the resource options with --resource" do
      expect(device.options).to receive(:[]=).with(:resource,true)

      device.handle_resource(true)
    end

    it "stores the facts options with --facts" do
      expect(device.options).to receive(:[]=).with(:facts,true)

      device.handle_facts(true)
    end

    it "should register ssl OIDs" do
      expect(Puppet::SSL::Oids).to receive(:register_puppet_oids)

      device.setup
    end
  end

  describe "during setup" do
    before do
      allow(device.options).to receive(:[])
      Puppet[:libdir] = "/dev/null/lib"
    end

    it "calls setup_logs" do
      expect(device).to receive(:setup_logs)
      device.setup
    end

    describe "when setting up logs" do
      before do
        allow(Puppet::Util::Log).to receive(:newdestination)
      end

      it "sets log level to debug if --debug was passed" do
        allow(device.options).to receive(:[]).with(:debug).and_return(true)
        device.setup_logs
        expect(Puppet::Util::Log.level).to eq(:debug)
      end

      it "sets log level to info if --verbose was passed" do
        allow(device.options).to receive(:[]).with(:verbose).and_return(true)
        device.setup_logs
        expect(Puppet::Util::Log.level).to eq(:info)
      end

      [:verbose, :debug].each do |level|
        it "should set console as the log destination with level #{level}" do
          allow(device.options).to receive(:[]).with(level).and_return(true)

          expect(Puppet::Util::Log).to receive(:newdestination).with(:console)

          device.setup_logs
        end
      end

      it "sets a default log destination if no --logdest" do
        allow(device.options).to receive(:[]).with(:setdest).and_return(false)

        expect(Puppet::Util::Log).to receive(:setup_default)

        device.setup_logs
      end
    end

    it "sets a central log destination with --centrallogs" do
      allow(device.options).to receive(:[]).with(:centrallogs).and_return(true)
      Puppet[:server] = "puppet.example.com"
      allow(Puppet::Util::Log).to receive(:newdestination).with(:syslog)

      expect(Puppet::Util::Log).to receive(:newdestination).with("puppet.example.com")

      device.setup
    end

    it "uses :main, :agent, :device and :ssl config" do
      expect(Puppet.settings).to receive(:use).with(:main, :agent, :device, :ssl)

      device.setup
    end

    it "tells the report handler to use REST" do
      device.setup
      expect(Puppet::Transaction::Report.indirection).to have_received(:terminus_class=).with(:rest)
    end

    it "defaults the catalog_terminus setting to 'rest'" do
      device.initialize_app_defaults
      expect(Puppet[:catalog_terminus]).to eq(:rest)
    end

    it "defaults the node_terminus setting to 'rest'" do
      device.initialize_app_defaults
      expect(Puppet[:node_terminus]).to eq(:rest)
    end

    it "has an application default :catalog_cache_terminus setting of 'json'" do
      expect(Puppet::Resource::Catalog.indirection).to receive(:cache_class=).with(:json)

      device.initialize_app_defaults
      device.setup
    end

    it "tells the catalog cache class based on the :catalog_cache_terminus setting" do
      Puppet[:catalog_cache_terminus] = "yaml"
      expect(Puppet::Resource::Catalog.indirection).to receive(:cache_class=).with(:yaml)

      device.initialize_app_defaults
      device.setup
    end

    it "does not set catalog cache class if :catalog_cache_terminus is explicitly nil" do
      Puppet[:catalog_cache_terminus] = nil
      expect(Puppet::Resource::Catalog.indirection).not_to receive(:cache_class=)

      device.initialize_app_defaults
      device.setup
    end

    it "defaults the facts_terminus setting to 'network_device'" do
      device.initialize_app_defaults
      expect(Puppet[:facts_terminus]).to eq(:network_device)
    end
  end

  describe "when initializing SSL" do
    it "creates a new ssl host" do
      allow(device.options).to receive(:[]).with(:waitforcert).and_return(123)

      device.setup_context

      expect(Puppet::SSL::StateMachine).to have_received(:new).with(hash_including(waitforcert: 123))
    end
  end

  describe "when running" do
    let(:device_hash) { {} }
    let(:plugin_handler) { instance_double(Puppet::Configurer::PluginHandler, 'plugin_handler') }

    before do
      allow(device.options).to receive(:[]).with(:fingerprint).and_return(false)
      allow(Puppet).to receive(:notice)
      allow(device.options).to receive(:[]).with(:detailed_exitcodes).and_return(false)
      allow(device.options).to receive(:[]).with(:target).and_return(nil)
      allow(device.options).to receive(:[]).with(:apply).and_return(nil)
      allow(device.options).to receive(:[]).with(:facts).and_return(false)
      allow(device.options).to receive(:[]).with(:resource).and_return(false)
      allow(device.options).to receive(:[]).with(:to_yaml).and_return(false)
      allow(device.options).to receive(:[]).with(:libdir).and_return(nil)
      allow(device.options).to receive(:[]).with(:client)
      allow(device.command_line).to receive(:args).and_return([])
      allow(Puppet::Util::NetworkDevice::Config).to receive(:devices).and_return(device_hash)
      allow(Puppet::Configurer::PluginHandler).to receive(:new).and_return(plugin_handler)
    end

    it "dispatches to main" do
      allow(device).to receive(:main)
      device.run_command
    end

    it "errors if resource is requested without target" do
      allow(device.options).to receive(:[]).with(:resource).and_return(true)
      expect { device.main }.to raise_error(RuntimeError, "resource command requires target")
    end

    it "errors if facts is requested without target" do
      allow(device.options).to receive(:[]).with(:facts).and_return(true)
      expect { device.main }.to raise_error(RuntimeError, "facts command requires target")
    end

    it "gets the device list" do
      expect(Puppet::Util::NetworkDevice::Config).to receive(:devices).and_return(device_hash)
      expect { device.main }.to exit_with 1
    end

    it "errors when an invalid target parameter is passed" do
      allow(device.options).to receive(:[]).with(:target).and_return('bla')
      expect(Puppet).not_to receive(:info).with(/starting applying configuration to/)
      expect { device.main }.to raise_error(RuntimeError, /Target device \/ certificate 'bla' not found in .*\.conf/)
    end

    it "errors if target is passed and the apply path is incorrect" do
      allow(device.options).to receive(:[]).with(:apply).and_return('file.pp')
      allow(device.options).to receive(:[]).with(:target).and_return('device1')

      expect(File).to receive(:file?).and_return(false)
      expect { device.main }.to raise_error(RuntimeError, /does not exist, cannot apply/)
    end

    it "exits if the device list is empty" do
      expect { device.main }.to exit_with 1
    end

    context 'with some devices configured' do
      let(:configurer) { instance_double(Puppet::Configurer, 'configurer') }
      let(:device_hash) {
        {
          "device1" => OpenStruct.new(:name => "device1", :url => "ssh://user:pass@testhost", :provider => "cisco"),
          "device2" => OpenStruct.new(:name => "device2", :url => "https://user:pass@testhost/some/path", :provider => "rest"),
        }
      }

      before do
        Puppet[:vardir] = make_absolute("/dummy")
        Puppet[:confdir] = make_absolute("/dummy")
        Puppet[:certname] = "certname"

        allow(Puppet).to receive(:[]=)
        allow(Puppet.settings).to receive(:use)

        allow(device).to receive(:setup_context)
        allow(Puppet::Util::NetworkDevice).to receive(:init)

        allow(configurer).to receive(:run)
        allow(Puppet::Configurer).to receive(:new).and_return(configurer)

        allow(Puppet::FileSystem).to receive(:exist?)
        allow(Puppet::FileSystem).to receive(:symlink)
        allow(Puppet::FileSystem).to receive(:dir_mkpath).and_return(true)
        allow(Puppet::FileSystem).to receive(:dir_exist?).and_return(true)

        allow(plugin_handler).to receive(:download_plugins)
      end

      it "sets ssldir relative to the global confdir" do
        expect(Puppet).to receive(:[]=).with(:ssldir, make_absolute("/dummy/devices/device1/ssl"))
        expect { device.main }.to exit_with 1
      end

      it "sets vardir to the device vardir" do
        expect(Puppet).to receive(:[]=).with(:vardir, make_absolute("/dummy/devices/device1"))
        expect { device.main }.to exit_with 1
      end

      it "sets confdir to the device confdir" do
        expect(Puppet).to receive(:[]=).with(:confdir, make_absolute("/dummy/devices/device1"))
        expect { device.main }.to exit_with 1
      end

      it "sets certname to the device certname" do
        expect(Puppet).to receive(:[]=).with(:certname, "device1")
        expect(Puppet).to receive(:[]=).with(:certname, "device2")
        expect { device.main }.to exit_with 1
      end

      context 'with --target=device1' do
        it "symlinks the ssl directory if it doesn't exist" do
          allow(device.options).to receive(:[]).with(:target).and_return('device1')
          allow(Puppet::FileSystem).to receive(:exist?).and_return(false)

          expect(Puppet::FileSystem).to receive(:symlink).with(Puppet[:ssldir], File.join(Puppet[:confdir], 'ssl')).and_return(true)
          expect { device.main }.to exit_with 1
        end

        it "creates the device confdir under the global confdir" do
          allow(device.options).to receive(:[]).with(:target).and_return('device1')
          allow(Puppet::FileSystem).to receive(:dir_exist?).and_return(false)

          expect(Puppet::FileSystem).to receive(:dir_mkpath).with(Puppet[:ssldir]).and_return(true)
          expect { device.main }.to exit_with 1
        end

        it "manages the specified target" do
          allow(device.options).to receive(:[]).with(:target).and_return('device1')

          expect(URI).to receive(:parse).with("ssh://user:pass@testhost")
          expect(URI).not_to receive(:parse).with("https://user:pass@testhost/some/path")
          expect { device.main }.to exit_with 1
        end
      end

      context 'when running --resource' do
        before do
          allow(device.options).to receive(:[]).with(:resource).and_return(true)
          allow(device.options).to receive(:[]).with(:target).and_return('device1')
        end

        it "raises an error if no type is given" do
          allow(device.command_line).to receive(:args).and_return([])
          expect(Puppet).to receive(:log_exception) { |e| expect(e.message).to eq("You must specify the type to display") }
          expect { device.main }.to exit_with 1
        end

        it "raises an error if the type is not found" do
          allow(device.command_line).to receive(:args).and_return(['nope'])
          expect(Puppet).to receive(:log_exception) { |e| expect(e.message).to eq("Could not find type nope") }
          expect { device.main }.to exit_with 1
        end

        it "retrieves all resources of a type" do
          allow(device.command_line).to receive(:args).and_return(['user'])
          expect(Puppet::Resource.indirection).to receive(:search).with('user/', {}).and_return([])
          expect { device.main }.to exit_with 0
        end

        it "retrieves named resources of a type" do
          resource = Puppet::Type.type(:user).new(:name => "jim").to_resource
          allow(device.command_line).to receive(:args).and_return(['user', 'jim'])
          expect(Puppet::Resource.indirection).to receive(:find).with('user/jim').and_return(resource)
          expect(device).to receive(:puts).with("user { 'jim':\n  ensure => 'absent',\n}")
          expect { device.main }.to exit_with 0
        end

        it "outputs resources as YAML" do
          resources = [
            Puppet::Type.type(:user).new(:name => "title").to_resource,
          ]
          allow(device.options).to receive(:[]).with(:to_yaml).and_return(true)
          allow(device.command_line).to receive(:args).and_return(['user'])
          expect(Puppet::Resource.indirection).to receive(:search).with('user/', {}).and_return(resources)
          expect(device).to receive(:puts).with("---\nuser:\n  title:\n    ensure: absent\n")
          expect { device.main }.to exit_with 0
        end
      end

      context 'when running --facts' do
        before do
          allow(device.options).to receive(:[]).with(:facts).and_return(true)
          allow(device.options).to receive(:[]).with(:target).and_return('device1')
        end

        it "retrieves facts" do
          indirection_fact_values = {"operatingsystem"=>"cisco_ios","clientcert"=>"3750"}
          indirection_facts = Puppet::Node::Facts.new("nil", indirection_fact_values)
          expect(Puppet::Node::Facts.indirection).to receive(:find).with(nil, anything()).and_return(indirection_facts)
          expect(device).to receive(:puts).with(/name.*3750.*\n.*values.*\n.*operatingsystem.*cisco_ios/)
          expect { device.main }.to exit_with 0
        end
      end

      context 'when running in agent mode' do
        it "makes sure all the required folders and files are created" do
          expect(Puppet.settings).to receive(:use).with(:main, :agent, :ssl).twice
          expect { device.main }.to exit_with 1
        end

        it "initializes the device singleton" do
          expect(Puppet::Util::NetworkDevice).to receive(:init).with(device_hash["device1"]).ordered
          expect(Puppet::Util::NetworkDevice).to receive(:init).with(device_hash["device2"]).ordered
          expect { device.main }.to exit_with 1
        end

        it "retrieves plugins and print the device url scheme, host, and port" do
          allow(Puppet).to receive(:info)
          expect(plugin_handler).to receive(:download_plugins).twice
          expect(Puppet).to receive(:info).with("starting applying configuration to device1 at ssh://testhost")
          expect(Puppet).to receive(:info).with("starting applying configuration to device2 at https://testhost:443/some/path")
          expect { device.main }.to exit_with 1
        end

        it "setups the SSL context before pluginsync" do
          expect(device).to receive(:setup_context).ordered
          expect(plugin_handler).to receive(:download_plugins).ordered
          expect(device).to receive(:setup_context).ordered
          expect(plugin_handler).to receive(:download_plugins).ordered
          expect { device.main }.to exit_with 1
        end

        it "launches a configurer for this device" do
          expect(configurer).to receive(:run).twice
          expect { device.main }.to exit_with 1
        end

        it "exits 1 when configurer raises error" do
          expect(configurer).to receive(:run).and_raise(Puppet::Error).ordered
          expect(configurer).to receive(:run).and_return(0).ordered
          expect { device.main }.to exit_with 1
        end

        it "exits 0 when run happens without puppet errors but with failed run" do
          allow(configurer).to receive(:run).and_return(6, 2)
          expect { device.main }.to exit_with 0
        end

        it "makes the Puppet::Pops::Loaders available" do
          expect(configurer).to receive(:run).with({:network_device => true, :pluginsync => false}) do
            fail('Loaders not available') unless Puppet.lookup(:loaders) { nil }.is_a?(Puppet::Pops::Loaders)
            true
          end.and_return(6, 2)
          expect { device.main }.to exit_with 0
        end

        it "exits 2 when --detailed-exitcodes and successful runs" do
          allow(device.options).to receive(:[]).with(:detailed_exitcodes).and_return(true)
          allow(configurer).to receive(:run).and_return(0, 2)
          expect { device.main }.to exit_with 2
        end

        it "exits 1 when --detailed-exitcodes and failed parse" do
          allow(Puppet::Configurer).to receive(:new).and_return(configurer)
          allow(device.options).to receive(:[]).with(:detailed_exitcodes).and_return(true)
          allow(configurer).to receive(:run).and_return(6, 1)
          expect { device.main }.to exit_with 7
        end

        it "exits 6 when --detailed-exitcodes and failed run" do
          allow(Puppet::Configurer).to receive(:new).and_return(configurer)
          allow(device.options).to receive(:[]).with(:detailed_exitcodes).and_return(true)
          allow(configurer).to receive(:run).and_return(6, 2)
          expect { device.main }.to exit_with 6
        end

        [:vardir, :confdir].each do |setting|
          it "resets the #{setting} setting after the run" do
            all_devices = Set.new(device_hash.keys.map do |device_name| make_absolute("/dummy/devices/#{device_name}") end)
            found_devices = Set.new()

            # a block to use in a few places later to validate the updated settings
            p = Proc.new do |my_setting, my_value|
              expect(all_devices).to include(my_value)
              found_devices.add(my_value)
            end

            all_devices.size.times do
              ## one occurrence of set / run / set("/dummy") for each device
              expect(Puppet).to receive(:[]=, &p).with(setting, anything).ordered
              expect(configurer).to receive(:run).ordered
              expect(Puppet).to receive(:[]=).with(setting, make_absolute("/dummy")).ordered
            end

            expect { device.main }.to exit_with 1

            expect(found_devices).to eq(all_devices)
          end
        end

        it "resets the certname setting after the run" do
          all_devices = Set.new(device_hash.keys)
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
            expect(configurer).to receive(:run).ordered
            expect(Puppet).to receive(:[]=).with(:certname, "certname").ordered
          end


          expect { device.main }.to exit_with 1

          # make sure that we were called with each of the defined devices
          expect(found_devices).to eq(all_devices)
        end
      end
    end
  end
end
