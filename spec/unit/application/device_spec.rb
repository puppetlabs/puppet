#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/application/device'
require 'puppet/util/network_device/config'
require 'ostruct'
require 'puppet/configurer'

describe Puppet::Application::Device do
  include PuppetSpec::Files

  before :each do
    @device = Puppet::Application[:device]
    @device.preinit
    Puppet::Util::Log.stubs(:newdestination)

    Puppet::Node.indirection.stubs(:terminus_class=)
    Puppet::Node.indirection.stubs(:cache_class=)
    Puppet::Node::Facts.indirection.stubs(:terminus_class=)
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
      @device.stubs(:trap)
    end

    it "should catch INT" do
      Signal.expects(:trap).with { |arg,block| arg == :INT }

      @device.preinit
    end

    it "should init waitforcert to nil" do
      @device.preinit

      expect(@device.options[:waitforcert]).to be_nil
    end
  end

  describe "when handling options" do
    before do
      @device.command_line.stubs(:args).returns([])
    end

    [:centrallogging, :debug, :verbose,].each do |option|
      it "should declare handle_#{option} method" do
        expect(@device).to respond_to("handle_#{option}".to_sym)
      end

      it "should store argument value when calling handle_#{option}" do
        @device.options.expects(:[]=).with(option, 'arg')
        @device.send("handle_#{option}".to_sym, 'arg')
      end
    end

    it "should set waitforcert to 0 with --onetime and if --waitforcert wasn't given" do
      Puppet[:onetime] = true
      Puppet::SSL::Host.any_instance.expects(:wait_for_cert).with(0)
      @device.setup_host
    end

    it "should use supplied waitforcert when --onetime is specified" do
      Puppet[:onetime] = true
      @device.handle_waitforcert(60)
      Puppet::SSL::Host.any_instance.expects(:wait_for_cert).with(60)
      @device.setup_host
    end

    it "should use a default value for waitforcert when --onetime and --waitforcert are not specified" do
      Puppet::SSL::Host.any_instance.expects(:wait_for_cert).with(120)
      @device.setup_host
    end

    it "should use the waitforcert setting when checking for a signed certificate" do
      Puppet[:waitforcert] = 10
      Puppet::SSL::Host.any_instance.expects(:wait_for_cert).with(10)
      @device.setup_host
    end

    it "should set the log destination with --logdest" do
      @device.options.stubs(:[]=).with { |opt,val| opt == :setdest }
      Puppet::Log.expects(:newdestination).with("console")

      @device.handle_logdest("console")
    end

    it "should put the setdest options to true" do
      @device.options.expects(:[]=).with(:setdest,true)

      @device.handle_logdest("console")
    end

    it "should parse the log destination from the command line" do
      @device.command_line.stubs(:args).returns(%w{--logdest /my/file})

      Puppet::Util::Log.expects(:newdestination).with("/my/file")

      @device.parse_options
    end

    it "should store the waitforcert options with --waitforcert" do
      @device.options.expects(:[]=).with(:waitforcert,42)

      @device.handle_waitforcert("42")
    end

    it "should set args[:Port] with --port" do
      @device.handle_port("42")
      expect(@device.args[:Port]).to eq("42")
    end

  end

  describe "during setup" do
    before :each do
      @device.options.stubs(:[])
      Puppet[:libdir] = "/dev/null/lib"
      Puppet::SSL::Host.stubs(:ca_location=)
      Puppet::Transaction::Report.indirection.stubs(:terminus_class=)
      Puppet::Resource::Catalog.indirection.stubs(:terminus_class=)
      Puppet::Resource::Catalog.indirection.stubs(:cache_class=)
      Puppet::Node::Facts.indirection.stubs(:terminus_class=)
      @host = stub_everything 'host'
      Puppet::SSL::Host.stubs(:new).returns(@host)
      Puppet.stubs(:settraps)
    end

    it "should call setup_logs" do
      @device.expects(:setup_logs)
      @device.setup
    end

    describe "when setting up logs" do
      before :each do
        Puppet::Util::Log.stubs(:newdestination)
      end

      it "should set log level to debug if --debug was passed" do
        @device.options.stubs(:[]).with(:debug).returns(true)
        @device.setup_logs
        expect(Puppet::Util::Log.level).to eq(:debug)
      end

      it "should set log level to info if --verbose was passed" do
        @device.options.stubs(:[]).with(:verbose).returns(true)
        @device.setup_logs
        expect(Puppet::Util::Log.level).to eq(:info)
      end

      [:verbose, :debug].each do |level|
        it "should set console as the log destination with level #{level}" do
          @device.options.stubs(:[]).with(level).returns(true)

          Puppet::Util::Log.expects(:newdestination).with(:console)

          @device.setup_logs
        end
      end

      it "should set a default log destination if no --logdest" do
        @device.options.stubs(:[]).with(:setdest).returns(false)

        Puppet::Util::Log.expects(:setup_default)

        @device.setup_logs
      end

    end

    it "should set a central log destination with --centrallogs" do
      @device.options.stubs(:[]).with(:centrallogs).returns(true)
      Puppet[:server] = "puppet.reductivelabs.com"
      Puppet::Util::Log.stubs(:newdestination).with(:syslog)

      Puppet::Util::Log.expects(:newdestination).with("puppet.reductivelabs.com")

      @device.setup
    end

    it "should use :main, :agent, :device and :ssl config" do
      Puppet.settings.expects(:use).with(:main, :agent, :device, :ssl)

      @device.setup
    end

    it "should install a remote ca location" do
      Puppet::SSL::Host.expects(:ca_location=).with(:remote)

      @device.setup
    end

    it "should tell the report handler to use REST" do
      Puppet::Transaction::Report.indirection.expects(:terminus_class=).with(:rest)

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
      Puppet::Resource::Catalog.indirection.expects(:cache_class=).with(:json)

      @device.initialize_app_defaults
      @device.setup
    end

    it "should tell the catalog cache class based on the :catalog_cache_terminus setting" do
      Puppet[:catalog_cache_terminus] = "yaml"
      Puppet::Resource::Catalog.indirection.expects(:cache_class=).with(:yaml)

      @device.initialize_app_defaults
      @device.setup
    end

    it "should not set catalog cache class if :catalog_cache_terminus is explicitly nil" do
      Puppet[:catalog_cache_terminus] = nil
      Puppet::Resource::Catalog.indirection.expects(:cache_class=).never

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
      @host = stub_everything 'host'
      Puppet::SSL::Host.stubs(:new).returns(@host)
    end

    it "should create a new ssl host" do
      Puppet::SSL::Host.expects(:new).returns(@host)
      @device.setup_host
    end

    it "should wait for a certificate" do
      @device.options.stubs(:[]).with(:waitforcert).returns(123)
      @host.expects(:wait_for_cert).with(123)

      @device.setup_host
    end
  end


  describe "when running" do
    before :each do
      @device.options.stubs(:[]).with(:fingerprint).returns(false)
      Puppet.stubs(:notice)
      @device.options.stubs(:[]).with(:detailed_exitcodes).returns(false)
      @device.options.stubs(:[]).with(:client)
      Puppet::Util::NetworkDevice::Config.stubs(:devices).returns({})
    end

    it "should dispatch to main" do
      @device.stubs(:main)
      @device.run_command
    end

    it "should get the device list" do
      device_hash = stub_everything 'device hash'
      Puppet::Util::NetworkDevice::Config.expects(:devices).returns(device_hash)
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
        Puppet::Util::NetworkDevice::Config.stubs(:devices).returns(@device_hash)
        Puppet.stubs(:[]=)
        Puppet.settings.stubs(:use)
        @device.stubs(:setup_host)
        Puppet::Util::NetworkDevice.stubs(:init)
        @configurer = stub_everything 'configurer'
        Puppet::Configurer.stubs(:new).returns(@configurer)
      end

      it "should set vardir to the device vardir" do
        Puppet.expects(:[]=).with(:vardir, make_absolute("/dummy/devices/device1"))
        expect { @device.main }.to exit_with 1
      end

      it "should set confdir to the device confdir" do
        Puppet.expects(:[]=).with(:confdir, make_absolute("/dummy/devices/device1"))
        expect { @device.main }.to exit_with 1
      end

      it "should set certname to the device certname" do
        Puppet.expects(:[]=).with(:certname, "device1")
        Puppet.expects(:[]=).with(:certname, "device2")
        expect { @device.main }.to exit_with 1
      end

      it "should make sure all the required folders and files are created" do
        Puppet.settings.expects(:use).with(:main, :agent, :ssl).twice
        expect { @device.main }.to exit_with 1
      end

      it "should initialize the device singleton" do
        Puppet::Util::NetworkDevice.expects(:init).with(@device_hash["device1"]).then.with(@device_hash["device2"])
        expect { @device.main }.to exit_with 1
      end

      it "should print the device url scheme, host, and port" do
        Puppet.expects(:info).with "starting applying configuration to device1 at ssh://testhost"
        Puppet.expects(:info).with "starting applying configuration to device2 at https://testhost:443/some/path"
        expect { @device.main }.to exit_with 1
      end

      it "should setup the SSL context" do
        @device.expects(:setup_host).twice
        expect { @device.main }.to exit_with 1
      end

      it "should launch a configurer for this device" do
        @configurer.expects(:run).twice
        expect { @device.main }.to exit_with 1
      end

      it "exits 1 when configurer raises error" do
        @configurer.stubs(:run).raises(Puppet::Error).then.returns(0)
        expect { @device.main }.to exit_with 1
      end

      it "exits 0 when run happens without puppet errors but with failed run" do
        @configurer.stubs(:run).returns(6,2)
        expect { @device.main }.to exit_with 0
      end

      it "exits 2 when --detailed-exitcodes and successful runs" do
        @device.options.stubs(:[]).with(:detailed_exitcodes).returns(true)
        @configurer.stubs(:run).returns(0,2)
        expect { @device.main }.to exit_with 2
      end

      it "exits 1 when --detailed-exitcodes and failed parse" do
        @configurer = stub_everything 'configurer'
        Puppet::Configurer.stubs(:new).returns(@configurer)
        @device.options.stubs(:[]).with(:detailed_exitcodes).returns(true)
        @configurer.stubs(:run).returns(6,1)
        expect { @device.main }.to exit_with 7
      end

      it "exits 6 when --detailed-exitcodes and failed run" do
        @configurer = stub_everything 'configurer'
        Puppet::Configurer.stubs(:new).returns(@configurer)
        @device.options.stubs(:[]).with(:detailed_exitcodes).returns(true)
        @configurer.stubs(:run).returns(6,2)
        expect { @device.main }.to exit_with 6
      end

      [:vardir, :confdir].each do |setting|
        it "should cleanup the #{setting} setting after the run" do
          all_devices = Set.new(@device_hash.keys.map do |device_name| make_absolute("/dummy/devices/#{device_name}") end)
          found_devices = Set.new()

          # a block to use in a few places later to validate the updated settings
          p = Proc.new do |my_setting, my_value|
            if my_setting == setting && all_devices.include?(my_value)
              found_devices.add(my_value)
              true
            else
              false
            end
          end

          seq = sequence("clean up dirs")

          all_devices.size.times do
            ## one occurrence of set / run / set("/dummy") for each device
            Puppet.expects(:[]=).with(&p).in_sequence(seq)
            @configurer.expects(:run).in_sequence(seq)
            Puppet.expects(:[]=).with(setting, make_absolute("/dummy")).in_sequence(seq)
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
          if my_setting == :certname && all_devices.include?(my_value)
            found_devices.add(my_value)
            true
          else
            false
          end
        end

        seq = sequence("clean up certname")

        all_devices.size.times do
          ## one occurrence of set / run / set("certname") for each device
          Puppet.expects(:[]=).with(&p).in_sequence(seq)
          @configurer.expects(:run).in_sequence(seq)
          Puppet.expects(:[]=).with(:certname, "certname").in_sequence(seq)
        end


        expect { @device.main }.to exit_with 1

        # make sure that we were called with each of the defined devices
        expect(found_devices).to eq(all_devices)
      end

      it "should expire all cached attributes" do
        Puppet::SSL::Host.expects(:reset).twice

        expect { @device.main }.to exit_with 1
      end
    end
  end
end
