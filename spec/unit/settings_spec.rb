#! /usr/bin/env ruby
require 'spec_helper'
require 'ostruct'
require 'puppet/settings/errors'
require 'puppet_spec/files'
require 'matchers/resource'

describe Puppet::Settings do
  include PuppetSpec::Files
  include Matchers::Resource

  let(:main_config_file_default_location) do
    File.join(Puppet::Util::RunMode[:master].conf_dir, "puppet.conf")
  end

  let(:user_config_file_default_location) do
    File.join(Puppet::Util::RunMode[:user].conf_dir, "puppet.conf")
  end

  # Return a given object's file metadata.
  def metadata(setting)
    if setting.is_a?(Puppet::Settings::FileSetting)
      {
        :owner => setting.owner,
        :group => setting.group,
        :mode => setting.mode
      }.delete_if { |key, value| value.nil? }
    else
      nil
    end
  end

  describe "when specifying defaults" do
    before do
      @settings = Puppet::Settings.new
    end

    it "should start with no defined sections or parameters" do
      # Note this relies on undocumented side effect that eachsection returns the Settings internal
      # configuration on which keys returns all parameters.
      expect(@settings.eachsection.keys.length).to eq(0)
    end

    it "should not allow specification of default values associated with a section as an array" do
      expect {
        @settings.define_settings(:section, :myvalue => ["defaultval", "my description"])
      }.to raise_error(ArgumentError, /setting definition for 'myvalue' is not a hash!/)
    end

    it "should not allow duplicate parameter specifications" do
      @settings.define_settings(:section, :myvalue => { :default => "a", :desc => "b" })
      expect { @settings.define_settings(:section, :myvalue => { :default => "c", :desc => "d" }) }.to raise_error(ArgumentError)
    end

    it "should allow specification of default values associated with a section as a hash" do
      @settings.define_settings(:section, :myvalue => {:default => "defaultval", :desc => "my description"})
    end

    it "should consider defined parameters to be valid" do
      @settings.define_settings(:section, :myvalue => { :default => "defaultval", :desc => "my description" })
      expect(@settings.valid?(:myvalue)).to be_truthy
    end

    it "should require a description when defaults are specified with a hash" do
      expect { @settings.define_settings(:section, :myvalue => {:default => "a value"}) }.to raise_error(ArgumentError)
    end

    it "should support specifying owner, group, and mode when specifying files" do
      @settings.define_settings(:section, :myvalue => {:type => :file, :default => "/some/file", :owner => "service", :mode => "boo", :group => "service", :desc => "whatever"})
    end

    it "should support specifying a short name" do
      @settings.define_settings(:section, :myvalue => {:default => "w", :desc => "b", :short => "m"})
    end

    it "should support specifying the setting type" do
      @settings.define_settings(:section, :myvalue => {:default => "/w", :desc => "b", :type => :string})
      expect(@settings.setting(:myvalue)).to be_instance_of(Puppet::Settings::StringSetting)
    end

    it "should fail if an invalid setting type is specified" do
      expect { @settings.define_settings(:section, :myvalue => {:default => "w", :desc => "b", :type => :foo}) }.to raise_error(ArgumentError)
    end

    it "should fail when short names conflict" do
      @settings.define_settings(:section, :myvalue => {:default => "w", :desc => "b", :short => "m"})
      expect { @settings.define_settings(:section, :myvalue => {:default => "w", :desc => "b", :short => "m"}) }.to raise_error(ArgumentError)
    end
  end


  describe "when initializing application defaults do" do
    let(:default_values) do
      values = {}
      PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS.keys.each do |key|
        values[key] = 'default value'
      end
      values
    end

    before do
      @settings = Puppet::Settings.new
      @settings.define_settings(:main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS)
    end

    it "should fail if the app defaults hash is missing any required values" do
      incomplete_default_values = default_values.reject { |key, _| key == :confdir }
      expect {
        @settings.initialize_app_defaults(default_values.reject { |key, _| key == :confdir })
      }.to raise_error(Puppet::Settings::SettingsError)
    end

    # ultimately I'd like to stop treating "run_mode" as a normal setting, because it has so many special
    #  case behaviors / uses.  However, until that time... we need to make sure that our private run_mode=
    #  setter method gets properly called during app initialization.
    it "sets the preferred run mode when initializing the app defaults" do
      @settings.initialize_app_defaults(default_values.merge(:run_mode => :master))

      expect(@settings.preferred_run_mode).to eq(:master)
    end

    it "creates ancestor directories for all required app settings" do
      # initialize_app_defaults is called in spec_helper, before we even
      # get here, but call it here to make it explicit what we're trying
      # to do.
      @settings.initialize_app_defaults(default_values)

      Puppet::Settings::REQUIRED_APP_SETTINGS.each do |key|
        expect(File).to exist(File.dirname(Puppet[key]))
      end
    end
  end

  describe "#call_hooks_deferred_to_application_initialization" do
    let(:good_default) { "yay" }
    let(:bad_default) { "$doesntexist" }
    before(:each) do
      @settings = Puppet::Settings.new
    end

    describe "when ignoring dependency interpolation errors" do
      let(:options) { {:ignore_interpolation_dependency_errors => true} }

      describe "if interpolation error" do
        it "should not raise an error" do
          hook_values = []
          @settings.define_settings(:section, :badhook => {:default => bad_default, :desc => "boo", :call_hook => :on_initialize_and_write, :hook => lambda { |v| hook_values << v  }})
          expect do
            @settings.send(:call_hooks_deferred_to_application_initialization, options)
          end.to_not raise_error
        end
      end
      describe "if no interpolation error" do
        it "should not raise an error" do
          hook_values = []
          @settings.define_settings(:section, :goodhook => {:default => good_default, :desc => "boo", :call_hook => :on_initialize_and_write, :hook => lambda { |v| hook_values << v  }})
          expect do
            @settings.send(:call_hooks_deferred_to_application_initialization, options)
          end.to_not raise_error
        end
      end
    end

    describe "when not ignoring dependency interpolation errors" do
      [ {}, {:ignore_interpolation_dependency_errors => false}].each do |options|
        describe "if interpolation error" do
          it "should raise an error" do
            hook_values = []
            @settings.define_settings(
              :section,
              :badhook => {
                :default => bad_default,
                :desc => "boo",
                :call_hook => :on_initialize_and_write,
                :hook => lambda { |v| hook_values << v }
              }
            )
            expect do
              @settings.send(:call_hooks_deferred_to_application_initialization, options)
            end.to raise_error(Puppet::Settings::InterpolationError)
          end
          it "should contain the setting name in error message" do
            hook_values = []
            @settings.define_settings(
              :section,
              :badhook => {
                :default => bad_default,
                :desc => "boo",
                :call_hook => :on_initialize_and_write,
                :hook => lambda { |v| hook_values << v }
              }
            )
            expect do
              @settings.send(:call_hooks_deferred_to_application_initialization, options)
            end.to raise_error(Puppet::Settings::InterpolationError, /badhook/)
          end
        end
        describe "if no interpolation error" do
          it "should not raise an error" do
            hook_values = []
            @settings.define_settings(
              :section,
              :goodhook => {
                :default => good_default,
                :desc => "boo",
                :call_hook => :on_initialize_and_write,
                :hook => lambda { |v| hook_values << v }
              }
            )
            expect do
              @settings.send(:call_hooks_deferred_to_application_initialization, options)
            end.to_not raise_error
          end
        end
      end
    end
  end

  describe "when setting values" do
    before do
      @settings = Puppet::Settings.new
      @settings.define_settings :main, :myval => { :default => "val", :desc => "desc" }
      @settings.define_settings :main, :bool => { :type => :boolean, :default => true, :desc => "desc" }
    end

    it "should provide a method for setting values from other objects" do
      @settings[:myval] = "something else"
      expect(@settings[:myval]).to eq("something else")
    end

    it "should support a getopt-specific mechanism for setting values" do
      @settings.handlearg("--myval", "newval")
      expect(@settings[:myval]).to eq("newval")
    end

    it "should support a getopt-specific mechanism for turning booleans off" do
      @settings.override_default(:bool, true)
      @settings.handlearg("--no-bool", "")
      expect(@settings[:bool]).to eq(false)
    end

    it "should support a getopt-specific mechanism for turning booleans on" do
      # Turn it off first
      @settings.override_default(:bool, false)
      @settings.handlearg("--bool", "")
      expect(@settings[:bool]).to eq(true)
    end

    it "should consider a cli setting with no argument to be a boolean" do
      # Turn it off first
      @settings.override_default(:bool, false)
      @settings.handlearg("--bool")
      expect(@settings[:bool]).to eq(true)
    end

    it "should consider a cli setting with an empty string as an argument to be an empty argument, if the setting itself is not a boolean" do
      @settings.override_default(:myval, "bob")
      @settings.handlearg("--myval", "")
      expect(@settings[:myval]).to eq("")
    end

    it "should consider a cli setting with a boolean as an argument to be a boolean" do
      # Turn it off first
      @settings.override_default(:bool, false)
      @settings.handlearg("--bool", "true")
      expect(@settings[:bool]).to eq(true)
    end

    it "should not consider a cli setting of a non boolean with a boolean as an argument to be a boolean" do
      @settings.override_default(:myval, "bob")
      @settings.handlearg("--no-myval", "")
      expect(@settings[:myval]).to eq("")
    end

    it "should flag string settings from the CLI" do
      @settings.handlearg("--myval", "12")
      expect(@settings.set_by_cli?(:myval)).to be_truthy
    end

    it "should flag bool settings from the CLI" do
      @settings.handlearg("--bool")
      expect(@settings.set_by_cli?(:bool)).to be_truthy
    end

    it "should not flag settings memory as from CLI" do
      @settings[:myval] = "12"
      expect(@settings.set_by_cli?(:myval)).to be_falsey
    end

    it "should find no configured settings by default" do
      expect(@settings.set_by_config?(:myval)).to be_falsey
    end

    it "should identify configured settings in memory" do
      @settings.instance_variable_get(:@value_sets)[:memory].expects(:lookup).with(:myval).returns('foo')
      expect(@settings.set_by_config?(:myval)).to be_truthy
    end

    it "should identify configured settings from CLI" do
      @settings.instance_variable_get(:@value_sets)[:cli].expects(:lookup).with(:myval).returns('foo')
      expect(@settings.set_by_config?(:myval)).to be_truthy
    end

    it "should not identify configured settings from environment by default" do
      Puppet.lookup(:environments).expects(:get_conf).with(Puppet[:environment].to_sym).never
      expect(@settings.set_by_config?(:manifest)).to be_falsey
    end

    it "should identify configured settings from environment by when an environment is specified" do
      foo = mock('environment', :manifest => 'foo')
      Puppet.lookup(:environments).expects(:get_conf).with(Puppet[:environment].to_sym).returns(foo)
      expect(@settings.set_by_config?(:manifest, Puppet[:environment])).to be_truthy
    end

    it "should identify configured settings from the preferred run mode" do
      user_config_text = "[#{@settings.preferred_run_mode}]\nmyval = foo"
      seq = sequence "config_file_sequence"

      Puppet.features.stubs(:root?).returns(false)
      Puppet::FileSystem.expects(:exist?).
        with(user_config_file_default_location).
        returns(true).in_sequence(seq)
      @settings.expects(:read_file).
        with(user_config_file_default_location).
        returns(user_config_text).in_sequence(seq)

      @settings.send(:parse_config_files)
      expect(@settings.set_by_config?(:myval)).to be_truthy
    end

    it "should identify configured settings from the specified run mode" do
      user_config_text = "[master]\nmyval = foo"
      seq = sequence "config_file_sequence"

      Puppet.features.stubs(:root?).returns(false)
      Puppet::FileSystem.expects(:exist?).
        with(user_config_file_default_location).
        returns(true).in_sequence(seq)
      @settings.expects(:read_file).
        with(user_config_file_default_location).
        returns(user_config_text).in_sequence(seq)

      @settings.send(:parse_config_files)
      expect(@settings.set_by_config?(:myval, nil, :master)).to be_truthy
    end

    it "should not identify configured settings from an unspecified run mode" do
      user_config_text = "[zaz]\nmyval = foo"
      seq = sequence "config_file_sequence"

      Puppet.features.stubs(:root?).returns(false)
      Puppet::FileSystem.expects(:exist?).
        with(user_config_file_default_location).
        returns(true).in_sequence(seq)
      @settings.expects(:read_file).
        with(user_config_file_default_location).
        returns(user_config_text).in_sequence(seq)

      @settings.send(:parse_config_files)
      expect(@settings.set_by_config?(:myval)).to be_falsey
    end

    it "should identify configured settings from the main section" do
      user_config_text = "[main]\nmyval = foo"
      seq = sequence "config_file_sequence"

      Puppet.features.stubs(:root?).returns(false)
      Puppet::FileSystem.expects(:exist?).
        with(user_config_file_default_location).
        returns(true).in_sequence(seq)
      @settings.expects(:read_file).
        with(user_config_file_default_location).
        returns(user_config_text).in_sequence(seq)

      @settings.send(:parse_config_files)
      expect(@settings.set_by_config?(:myval)).to be_truthy
    end

    it "should clear the cache when setting getopt-specific values" do
      @settings.define_settings :mysection,
          :one => { :default => "whah", :desc => "yay" },
          :two => { :default => "$one yay", :desc => "bah" }
      @settings.expects(:unsafe_flush_cache)
      expect(@settings[:two]).to eq("whah yay")
      @settings.handlearg("--one", "else")
      expect(@settings[:two]).to eq("else yay")
    end

    it "should clear the cache when the preferred_run_mode is changed" do
      @settings.expects(:flush_cache)
      @settings.preferred_run_mode = :master
    end

    it "should not clear other values when setting getopt-specific values" do
      @settings[:myval] = "yay"
      @settings.handlearg("--no-bool", "")
      expect(@settings[:myval]).to eq("yay")
    end

    it "should clear the list of used sections" do
      @settings.expects(:clearused)
      @settings[:myval] = "yay"
    end

    describe "call_hook" do
      Puppet::Settings::StringSetting.available_call_hook_values.each do |val|
        describe "when :#{val}" do
          describe "and definition invalid" do
            it "should raise error if no hook defined" do
              expect do
                @settings.define_settings(:section, :hooker => {:default => "yay", :desc => "boo", :call_hook => val})
              end.to raise_error(ArgumentError, /no :hook/)
            end
            it "should include the setting name in the error message" do
              expect do
                @settings.define_settings(:section, :hooker => {:default => "yay", :desc => "boo", :call_hook => val})
              end.to raise_error(ArgumentError, /for :hooker/)
            end
          end
          describe "and definition valid" do
            before(:each) do
              hook_values = []
              @settings.define_settings(:section, :hooker => {:default => "yay", :desc => "boo", :call_hook => val, :hook => lambda { |v| hook_values << v  }})
            end

            it "should call the hook when value written" do
              @settings.setting(:hooker).expects(:handle).with("something").once
              @settings[:hooker] = "something"
            end
          end
        end
      end

      it "should have a default value of :on_write_only" do
        @settings.define_settings(:section, :hooker => {:default => "yay", :desc => "boo", :hook => lambda { |v| hook_values << v  }})
        expect(@settings.setting(:hooker).call_hook).to eq(:on_write_only)
      end

      describe "when nil" do
        it "should generate a warning" do
          Puppet.expects(:warning)
          @settings.define_settings(:section, :hooker => {:default => "yay", :desc => "boo", :call_hook => nil, :hook => lambda { |v| hook_values << v  }})
        end
        it "should use default" do
          @settings.define_settings(:section, :hooker => {:default => "yay", :desc => "boo", :call_hook => nil, :hook => lambda { |v| hook_values << v  }})
          expect(@settings.setting(:hooker).call_hook).to eq(:on_write_only)
        end
      end

      describe "when invalid" do
        it "should raise an error" do
          expect do
            @settings.define_settings(:section, :hooker => {:default => "yay", :desc => "boo", :call_hook => :foo, :hook => lambda { |v| hook_values << v  }})
          end.to raise_error(ArgumentError, /invalid.*call_hook/i)
        end
      end

      describe "when :on_define_and_write" do
        it "should call the hook at definition" do
          hook_values = []
          @settings.define_settings(:section, :hooker => {:default => "yay", :desc => "boo", :call_hook => :on_define_and_write, :hook => lambda { |v| hook_values << v  }})
          expect(@settings.setting(:hooker).call_hook).to eq(:on_define_and_write)
          expect(hook_values).to eq(%w{yay})
        end
      end

      describe "when :on_initialize_and_write" do
        before(:each) do
          @hook_values = []
          @settings.define_settings(:section, :hooker => {:default => "yay", :desc => "boo", :call_hook => :on_initialize_and_write, :hook => lambda { |v| @hook_values << v  }})
        end

        it "should not call the hook at definition" do
          expect(@hook_values).to eq([])
          expect(@hook_values).not_to eq(%w{yay})
        end

        it "should call the hook at initialization" do
          app_defaults = {}
          Puppet::Settings::REQUIRED_APP_SETTINGS.each do |key|
            app_defaults[key] = "foo"
          end
          app_defaults[:run_mode] = :user
          @settings.define_settings(:main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS)

          @settings.setting(:hooker).expects(:handle).with("yay").once

          @settings.initialize_app_defaults app_defaults
        end
      end
    end

    it "should call passed blocks when values are set" do
      values = []
      @settings.define_settings(:section, :hooker => {:default => "yay", :desc => "boo", :hook => lambda { |v| values << v }})
      expect(values).to eq([])

      @settings[:hooker] = "something"
      expect(values).to eq(%w{something})
    end

    it "should call passed blocks when values are set via the command line" do
      values = []
      @settings.define_settings(:section, :hooker => {:default => "yay", :desc => "boo", :hook => lambda { |v| values << v }})
      expect(values).to eq([])

      @settings.handlearg("--hooker", "yay")

      expect(values).to eq(%w{yay})
    end

    it "should provide an option to call passed blocks during definition" do
      values = []
      @settings.define_settings(:section, :hooker => {:default => "yay", :desc => "boo", :call_hook => :on_define_and_write, :hook => lambda { |v| values << v }})
      expect(values).to eq(%w{yay})
    end

    it "should pass the fully interpolated value to the hook when called on definition" do
      values = []
      @settings.define_settings(:section, :one => { :default => "test", :desc => "a" })
      @settings.define_settings(:section, :hooker => {:default => "$one/yay", :desc => "boo", :call_hook => :on_define_and_write, :hook => lambda { |v| values << v }})
      expect(values).to eq(%w{test/yay})
    end

    it "should munge values using the setting-specific methods" do
      @settings[:bool] = "false"
      expect(@settings[:bool]).to eq(false)
    end

    it "should prefer values set in ruby to values set on the cli" do
      @settings[:myval] = "memarg"
      @settings.handlearg("--myval", "cliarg")

      expect(@settings[:myval]).to eq("memarg")
    end

    it "should raise an error if we try to set a setting that hasn't been defined'" do
      expect{
        @settings[:why_so_serious] = "foo"
      }.to raise_error(ArgumentError, /unknown setting/)
    end

    it "allows overriding cli args based on the cli-set value" do
      @settings.handlearg("--myval", "cliarg")
      @settings.patch_value(:myval, "modified #{@settings[:myval]}", :cli)
      expect(@settings[:myval]).to eq("modified cliarg")
    end
  end

  describe "when returning values" do
    before do
      @settings = Puppet::Settings.new
      @settings.define_settings :section,
          :config => { :type => :file, :default => "/my/file", :desc => "eh" },
          :one    => { :default => "ONE", :desc => "a" },
          :two    => { :default => "$one TWO", :desc => "b"},
          :three  => { :default => "$one $two THREE", :desc => "c"},
          :four   => { :default => "$two $three FOUR", :desc => "d"},
          :five   => { :default => nil, :desc => "e" }
      Puppet::FileSystem.stubs(:exist?).returns true
    end

    it "should provide a mechanism for returning set values" do
      @settings[:one] = "other"
      expect(@settings[:one]).to eq("other")
    end

    it "setting a value to nil causes it to return to its default" do
      default_values = { :one => "skipped value" }
      [:logdir, :confdir, :codedir, :vardir].each do |key|
        default_values[key] = 'default value'
      end
      @settings.define_settings :main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS
      @settings.initialize_app_defaults(default_values)
      @settings[:one] = "value will disappear"

      @settings[:one] = nil

      expect(@settings[:one]).to eq("ONE")
    end

    it "should interpolate default values for other parameters into returned parameter values" do
      expect(@settings[:one]).to eq("ONE")
      expect(@settings[:two]).to eq("ONE TWO")
      expect(@settings[:three]).to eq("ONE ONE TWO THREE")
    end

    it "should interpolate default values that themselves need to be interpolated" do
      expect(@settings[:four]).to eq("ONE TWO ONE ONE TWO THREE FOUR")
    end

    it "should provide a method for returning uninterpolated values" do
      @settings[:two] = "$one tw0"
      expect(@settings.value(:two, nil, true)).to  eq("$one tw0")
      expect(@settings.value(:four, nil, true)).to eq("$two $three FOUR")
    end

    it "should interpolate set values for other parameters into returned parameter values" do
      @settings[:one] = "on3"
      @settings[:two] = "$one tw0"
      @settings[:three] = "$one $two thr33"
      @settings[:four] = "$one $two $three f0ur"
      expect(@settings[:one]).to eq("on3")
      expect(@settings[:two]).to eq("on3 tw0")
      expect(@settings[:three]).to eq("on3 on3 tw0 thr33")
      expect(@settings[:four]).to eq("on3 on3 tw0 on3 on3 tw0 thr33 f0ur")
    end

    it "should not cache interpolated values such that stale information is returned" do
      expect(@settings[:two]).to eq("ONE TWO")
      @settings[:one] = "one"
      expect(@settings[:two]).to eq("one TWO")
    end

    it "should have a run_mode that defaults to user" do
      expect(@settings.preferred_run_mode).to eq(:user)
    end

    it "interpolates a boolean false without raising an error" do
      @settings.define_settings(:section,
          :trip_wire => { :type => :boolean, :default => false, :desc => "a trip wire" },
          :tripping => { :default => '$trip_wire', :desc => "once tripped if interpolated was false" })
      expect(@settings[:tripping]).to eq("false")
    end
  end

  describe "when choosing which value to return" do
    before do
      @settings = Puppet::Settings.new
      @settings.define_settings :section,
        :config => { :type => :file, :default => "/my/file", :desc => "a" },
        :one => { :default => "ONE", :desc => "a" },
        :two => { :default => "TWO", :desc => "b" }
      Puppet::FileSystem.stubs(:exist?).returns true
      @settings.preferred_run_mode = :agent
    end

    it "should return default values if no values have been set" do
      expect(@settings[:one]).to eq("ONE")
    end

    it "should return values set on the cli before values set in the configuration file" do
      text = "[main]\none = fileval\n"
      @settings.stubs(:read_file).returns(text)
      @settings.handlearg("--one", "clival")
      @settings.send(:parse_config_files)

      expect(@settings[:one]).to eq("clival")
    end

    it "should return values set in the mode-specific section before values set in the main section" do
      text = "[main]\none = mainval\n[agent]\none = modeval\n"
      @settings.stubs(:read_file).returns(text)
      @settings.send(:parse_config_files)

      expect(@settings[:one]).to eq("modeval")
    end

    it "should not return values outside of its search path" do
      text = "[other]\none = oval\n"
      file = "/some/file"
      @settings.stubs(:read_file).returns(text)
      @settings.send(:parse_config_files)
      expect(@settings[:one]).to eq("ONE")
    end

    it 'should use the current environment for $environment' do
      @settings.define_settings :main, :config_version => { :default => "$environment/foo", :desc => "mydocs" }

      expect(@settings.value(:config_version, "myenv")).to eq("myenv/foo")
    end
  end

  describe "when locating config files" do
    before do
      @settings = Puppet::Settings.new
    end

    describe "when root" do
      it "should look for the main config file default location config settings haven't been overridden'" do
        Puppet.features.stubs(:root?).returns(true)
        Puppet::FileSystem.expects(:exist?).with(main_config_file_default_location).returns(false)
        Puppet::FileSystem.expects(:exist?).with(user_config_file_default_location).never

        @settings.send(:parse_config_files)
      end
    end

    describe "when not root" do
      it "should look for user config file default location if config settings haven't been overridden'" do
        Puppet.features.stubs(:root?).returns(false)

        seq = sequence "load config files"
        Puppet::FileSystem.expects(:exist?).with(user_config_file_default_location).returns(false).in_sequence(seq)

        @settings.send(:parse_config_files)
      end
    end
  end

  describe "when parsing its configuration" do
    before do
      @settings = Puppet::Settings.new
      @settings.stubs(:service_user_available?).returns true
      @settings.stubs(:service_group_available?).returns true
      @file = make_absolute("/some/file")
      @userconfig = make_absolute("/test/userconfigfile")
      @settings.define_settings :section, :user => { :default => "suser", :desc => "doc" }, :group => { :default => "sgroup", :desc => "doc" }
      @settings.define_settings :section,
          :config => { :type => :file, :default => @file, :desc => "eh" },
          :one => { :default => "ONE", :desc => "a" },
          :two => { :default => "$one TWO", :desc => "b" },
          :three => { :default => "$one $two THREE", :desc => "c" }
      @settings.stubs(:user_config_file).returns(@userconfig)
      Puppet::FileSystem.stubs(:exist?).with(@file).returns true
      Puppet::FileSystem.stubs(:exist?).with(@userconfig).returns false
    end

    it "should not ignore the report setting" do
      @settings.define_settings :section, :report => { :default => "false", :desc => "a" }
      # This is needed in order to make sure we pass on windows
      myfile = File.expand_path(@file)
      @settings[:config] = myfile
      text = <<-CONF
        [puppetd]
          report=true
      CONF
      Puppet::FileSystem.expects(:exist?).with(myfile).returns(true)
      @settings.expects(:read_file).returns(text)
      @settings.send(:parse_config_files)
      expect(@settings[:report]).to be_truthy
    end

    it "should use its current ':config' value for the file to parse" do
      myfile = make_absolute("/my/file") # do not stub expand_path here, as this leads to a stack overflow, when mocha tries to use it
      @settings[:config] = myfile

      Puppet::FileSystem.expects(:exist?).with(myfile).returns(true)

      Puppet::FileSystem.expects(:read).with(myfile, :encoding => 'utf-8').returns "[main]"

      @settings.send(:parse_config_files)
    end

    it "should not try to parse non-existent files" do
      Puppet::FileSystem.expects(:exist?).with(@file).returns false

      File.expects(:read).with(@file).never

      @settings.send(:parse_config_files)
    end

    it "should return values set in the configuration file" do
      text = "[main]
      one = fileval
      "
      @settings.expects(:read_file).returns(text)
      @settings.send(:parse_config_files)
      expect(@settings[:one]).to eq("fileval")
    end

    #484 - this should probably be in the regression area
    it "should not throw an exception on unknown parameters" do
      text = "[main]\nnosuchparam = mval\n"
      @settings.expects(:read_file).returns(text)
      expect { @settings.send(:parse_config_files) }.not_to raise_error
    end

    it "should convert booleans in the configuration file into Ruby booleans" do
      text = "[main]
      one = true
      two = false
      "
      @settings.expects(:read_file).returns(text)
      @settings.send(:parse_config_files)
      expect(@settings[:one]).to eq(true)
      expect(@settings[:two]).to eq(false)
    end

    it "should convert integers in the configuration file into Ruby Integers" do
      text = "[main]
      one = 65
      "
      @settings.expects(:read_file).returns(text)
      @settings.send(:parse_config_files)
      expect(@settings[:one]).to eq(65)
    end

    it "should support specifying all metadata (owner, group, mode) in the configuration file" do
      @settings.define_settings :section, :myfile => { :type => :file, :default => make_absolute("/myfile"), :desc => "a" }

      otherfile = make_absolute("/other/file")
      @settings.parse_config(<<-CONF)
      [main]
      myfile = #{otherfile} {owner = service, group = service, mode = 644}
      CONF

      expect(@settings[:myfile]).to eq(otherfile)
      expect(metadata(@settings.setting(:myfile))).to eq({:owner => "suser", :group => "sgroup", :mode => "644"})
    end

    it "should support specifying a single piece of metadata (owner, group, or mode) in the configuration file" do
      @settings.define_settings :section, :myfile => { :type => :file, :default => make_absolute("/myfile"), :desc => "a" }

      otherfile = make_absolute("/other/file")
      @settings.parse_config(<<-CONF)
      [main]
      myfile = #{otherfile} {owner = service}
      CONF

      expect(@settings[:myfile]).to eq(otherfile)
      expect(metadata(@settings.setting(:myfile))).to eq({:owner => "suser"})
    end

    it "should support loading metadata (owner, group, or mode) from a run_mode section in the configuration file" do
      default_values = {}
      PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS.keys.each do |key|
        default_values[key] = 'default value'
      end
      @settings.define_settings :main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS
      @settings.define_settings :master, :myfile => { :type => :file, :default => make_absolute("/myfile"), :desc => "a" }

      otherfile = make_absolute("/other/file")
      text = "[master]
      myfile = #{otherfile} {mode = 664}
      "
      @settings.expects(:read_file).returns(text)

      # will start initialization as user
      expect(@settings.preferred_run_mode).to eq(:user)
      @settings.send(:parse_config_files)

      # change app run_mode to master
      @settings.initialize_app_defaults(default_values.merge(:run_mode => :master))
      expect(@settings.preferred_run_mode).to eq(:master)

      # initializing the app should have reloaded the metadata based on run_mode
      expect(@settings[:myfile]).to eq(otherfile)
      expect(metadata(@settings.setting(:myfile))).to eq({:mode => "664"})
    end

    it "does not use the metadata from the same setting in a different section" do
      default_values = {}
      PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS.keys.each do |key|
        default_values[key] = 'default value'
      end

      file = make_absolute("/file")
      default_mode = "0600"
      @settings.define_settings :main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS
      @settings.define_settings :master, :myfile => { :type => :file, :default => file, :desc => "a", :mode => default_mode }

      text = "[master]
      myfile = #{file}/foo
      [agent]
      myfile = #{file} {mode = 664}
      "
      @settings.expects(:read_file).returns(text)

      # will start initialization as user
      expect(@settings.preferred_run_mode).to eq(:user)
      @settings.send(:parse_config_files)

      # change app run_mode to master
      @settings.initialize_app_defaults(default_values.merge(:run_mode => :master))
      expect(@settings.preferred_run_mode).to eq(:master)

      # initializing the app should have reloaded the metadata based on run_mode
      expect(@settings[:myfile]).to eq("#{file}/foo")
      expect(metadata(@settings.setting(:myfile))).to eq({ :mode => default_mode })
    end

    it "should call hooks associated with values set in the configuration file" do
      values = []
      @settings.define_settings :section, :mysetting => {:default => "defval", :desc => "a", :hook => proc { |v| values << v }}

      text = "[main]
      mysetting = setval
      "
      @settings.expects(:read_file).returns(text)
      @settings.send(:parse_config_files)
      expect(values).to eq(["setval"])
    end

    it "should not call the same hook for values set multiple times in the configuration file" do
      values = []
      @settings.define_settings :section, :mysetting => {:default => "defval", :desc => "a", :hook => proc { |v| values << v }}

      text = "[user]
      mysetting = setval
      [main]
      mysetting = other
      "
      @settings.expects(:read_file).returns(text)
      @settings.send(:parse_config_files)
      expect(values).to eq(["setval"])
    end

    it "should pass the interpolated value to the hook when one is available" do
      values = []
      @settings.define_settings :section, :base => {:default => "yay", :desc => "a", :hook => proc { |v| values << v }}
      @settings.define_settings :section, :mysetting => {:default => "defval", :desc => "a", :hook => proc { |v| values << v }}

      text = "[main]
      mysetting = $base/setval
      "
      @settings.expects(:read_file).returns(text)
      @settings.send(:parse_config_files)
      expect(values).to eq(["yay/setval"])
    end

    it "should allow hooks invoked at parse time to be deferred" do
      hook_invoked = false
      @settings.define_settings :section, :deferred  => {:desc => '',
                                                         :hook => proc { |v| hook_invoked = true },
                                                         :call_hook => :on_initialize_and_write, }

      @settings.define_settings(:main,
        :logdir       => { :type => :directory, :default => nil, :desc => "logdir" },
        :confdir      => { :type => :directory, :default => nil, :desc => "confdir" },
        :codedir      => { :type => :directory, :default => nil, :desc => "codedir" },
        :vardir       => { :type => :directory, :default => nil, :desc => "vardir" })

      text = <<-EOD
      [main]
      deferred=$confdir/goose
      EOD

      @settings.stubs(:read_file).returns(text)
      @settings.initialize_global_settings

      expect(hook_invoked).to be_falsey

      @settings.initialize_app_defaults(:logdir => '/path/to/logdir', :confdir => '/path/to/confdir', :vardir => '/path/to/vardir', :codedir => '/path/to/codedir')

      expect(hook_invoked).to be_truthy
      expect(@settings[:deferred]).to eq(File.expand_path('/path/to/confdir/goose'))
    end

    it "does not require the value for a setting without a hook to resolve during global setup" do
      hook_invoked = false
      @settings.define_settings :section, :can_cause_problems  => {:desc => '' }

      @settings.define_settings(:main,
        :logdir       => { :type => :directory, :default => nil, :desc => "logdir" },
        :confdir      => { :type => :directory, :default => nil, :desc => "confdir" },
        :codedir      => { :type => :directory, :default => nil, :desc => "codedir" },
        :vardir       => { :type => :directory, :default => nil, :desc => "vardir" })

      text = <<-EOD
      [main]
      can_cause_problems=$confdir/goose
      EOD

      @settings.stubs(:read_file).returns(text)
      @settings.initialize_global_settings
      @settings.initialize_app_defaults(:logdir => '/path/to/logdir', :confdir => '/path/to/confdir', :vardir => '/path/to/vardir', :codedir => '/path/to/codedir')

      expect(@settings[:can_cause_problems]).to eq(File.expand_path('/path/to/confdir/goose'))
    end

    it "should allow empty values" do
      @settings.define_settings :section, :myarg => { :default => "myfile", :desc => "a" }

      text = "[main]
      myarg =
      "
      @settings.stubs(:read_file).returns(text)
      @settings.send(:parse_config_files)
      expect(@settings[:myarg]).to eq("")
    end

    describe "deprecations" do
      let(:settings) { Puppet::Settings.new }
      let(:app_defaults) {
        {
          :logdir     => "/dev/null",
          :confdir    => "/dev/null",
          :codedir    => "/dev/null",
          :vardir     => "/dev/null",
        }
      }

      def assert_accessing_setting_is_deprecated(settings, setting)
        Puppet.expects(:deprecation_warning).with("Accessing '#{setting}' as a setting is deprecated.")
        Puppet.expects(:deprecation_warning).with("Modifying '#{setting}' as a setting is deprecated.")
        settings[setting.intern] = apath = File.expand_path('foo')
        expect(settings[setting.intern]).to eq(apath)
      end

      before(:each) do
        settings.define_settings(:main, {
          :logdir => { :default => 'a', :desc => 'a' },
          :confdir => { :default => 'b', :desc => 'b' },
          :vardir => { :default => 'c', :desc => 'c' },
          :codedir => { :default => 'd', :desc => 'd' },
        })
      end

      context "complete" do
        let(:completely_deprecated_settings) do
          settings.define_settings(:main, {
            :completely_deprecated_setting => {
              :default => 'foo',
              :desc    => 'a deprecated setting',
              :deprecated => :completely,
            }
          })
          settings
        end

        it "warns when set in puppet.conf" do
          Puppet.expects(:deprecation_warning).with(regexp_matches(/completely_deprecated_setting is deprecated\./), 'setting-completely_deprecated_setting')

          completely_deprecated_settings.parse_config(<<-CONF)
            completely_deprecated_setting='should warn'
          CONF
          completely_deprecated_settings.initialize_app_defaults(app_defaults)
        end

        it "warns when set on the commandline" do
          Puppet.expects(:deprecation_warning).with(regexp_matches(/completely_deprecated_setting is deprecated\./), 'setting-completely_deprecated_setting')

          args = ["--completely_deprecated_setting", "/some/value"]
          completely_deprecated_settings.send(:parse_global_options, args)
          completely_deprecated_settings.initialize_app_defaults(app_defaults)
        end

        it "warns when set in code" do
          assert_accessing_setting_is_deprecated(completely_deprecated_settings, 'completely_deprecated_setting')
        end
      end

      context "partial" do
        let(:partially_deprecated_settings) do
          settings.define_settings(:main, {
            :partially_deprecated_setting => {
              :default => 'foo',
              :desc    => 'a partially deprecated setting',
              :deprecated => :allowed_on_commandline,
            }
          })
          settings
        end

        it "warns for a deprecated setting allowed on the command line set in puppet.conf" do
          Puppet.expects(:deprecation_warning).with(regexp_matches(/partially_deprecated_setting is deprecated in puppet\.conf/), 'puppet-conf-setting-partially_deprecated_setting')
          partially_deprecated_settings.parse_config(<<-CONF)
            partially_deprecated_setting='should warn'
          CONF
          partially_deprecated_settings.initialize_app_defaults(app_defaults)
        end

        it "does not warn when manifest is set on command line" do
          Puppet.expects(:deprecation_warning).never

          args = ["--partially_deprecated_setting", "/some/value"]
          partially_deprecated_settings.send(:parse_global_options, args)
          partially_deprecated_settings.initialize_app_defaults(app_defaults)
        end

        it "warns when set in code" do
          assert_accessing_setting_is_deprecated(partially_deprecated_settings, 'partially_deprecated_setting')
        end
      end
    end
  end

  describe "when there are multiple config files" do
    let(:main_config_text) { "[main]\none = main\ntwo = main2" }
    let(:user_config_text) { "[main]\none = user\n" }
    let(:seq) { sequence "config_file_sequence" }

    before :each do
      @settings = Puppet::Settings.new
      @settings.define_settings(:section,
          { :confdir => { :default => nil,                    :desc => "Conf dir" },
            :config  => { :default => "$confdir/puppet.conf", :desc => "Config" },
            :one     => { :default => "ONE",                  :desc => "a" },
            :two     => { :default => "TWO",                  :desc => "b" }, })
    end

    context "running non-root without explicit config file" do
      before :each do
        Puppet.features.stubs(:root?).returns(false)
        Puppet::FileSystem.expects(:exist?).
          with(user_config_file_default_location).
          returns(true).in_sequence(seq)
        @settings.expects(:read_file).
          with(user_config_file_default_location).
          returns(user_config_text).in_sequence(seq)
      end

      it "should return values from the user config file" do
        @settings.send(:parse_config_files)
        expect(@settings[:one]).to eq("user")
      end

      it "should not return values from the main config file" do
        @settings.send(:parse_config_files)
        expect(@settings[:two]).to eq("TWO")
      end
    end

    context "running as root without explicit config file" do
      before :each do
        Puppet.features.stubs(:root?).returns(true)
        Puppet::FileSystem.expects(:exist?).
          with(main_config_file_default_location).
          returns(true).in_sequence(seq)
        @settings.expects(:read_file).
          with(main_config_file_default_location).
          returns(main_config_text).in_sequence(seq)
      end

      it "should return values from the main config file" do
        @settings.send(:parse_config_files)
        expect(@settings[:one]).to eq("main")
      end

      it "should not return values from the user config file" do
        @settings.send(:parse_config_files)
        expect(@settings[:two]).to eq("main2")
      end
    end

    context "running with an explicit config file as a user (e.g. Apache + Passenger)" do
      before :each do
        Puppet.features.stubs(:root?).returns(false)
        @settings[:confdir] = File.dirname(main_config_file_default_location)
        Puppet::FileSystem.expects(:exist?).
          with(main_config_file_default_location).
          returns(true).in_sequence(seq)
        @settings.expects(:read_file).
          with(main_config_file_default_location).
          returns(main_config_text).in_sequence(seq)
      end

      it "should return values from the main config file" do
        @settings.send(:parse_config_files)
        expect(@settings[:one]).to eq("main")
      end

      it "should not return values from the user config file" do
        @settings.send(:parse_config_files)
        expect(@settings[:two]).to eq("main2")
      end
    end
  end

  describe "when reparsing its configuration" do
    before do
      @file = make_absolute("/test/file")
      @userconfig = make_absolute("/test/userconfigfile")
      @settings = Puppet::Settings.new
      @settings.define_settings :section,
          :config => { :type => :file, :default => @file, :desc => "a" },
          :one => { :default => "ONE", :desc => "a" },
          :two => { :default => "$one TWO", :desc => "b" },
          :three => { :default => "$one $two THREE", :desc => "c" }
      Puppet::FileSystem.stubs(:exist?).with(@file).returns true
      Puppet::FileSystem.stubs(:exist?).with(@userconfig).returns false
      @settings.stubs(:user_config_file).returns(@userconfig)
    end

    it "does not create the WatchedFile instance and should not parse if the file does not exist" do
      Puppet::FileSystem.expects(:exist?).with(@file).returns false
      Puppet::Util::WatchedFile.expects(:new).never

      @settings.expects(:parse_config_files).never

      @settings.reparse_config_files
    end

    context "and watched file exists" do
      before do
        @watched_file = Puppet::Util::WatchedFile.new(@file)
        Puppet::Util::WatchedFile.expects(:new).with(@file).returns @watched_file
      end

      it "uses a WatchedFile instance to determine if the file has changed" do
        @watched_file.expects(:changed?)

        @settings.reparse_config_files
      end

      it "does not reparse if the file has not changed" do
        @watched_file.expects(:changed?).returns false

        @settings.expects(:parse_config_files).never

        @settings.reparse_config_files
      end

      it "reparses if the file has changed" do
        @watched_file.expects(:changed?).returns true

        @settings.expects(:parse_config_files)

        @settings.reparse_config_files
      end

      it "replaces in-memory values with on-file values" do
        @watched_file.stubs(:changed?).returns(true)
        @settings[:one] = "init"

        # Now replace the value
        text = "[main]\none = disk-replace\n"
        @settings.stubs(:read_file).returns(text)
        @settings.reparse_config_files
        expect(@settings[:one]).to eq("disk-replace")
      end
    end

    it "should retain parameters set by cli when configuration files are reparsed" do
      @settings.handlearg("--one", "clival")

      text = "[main]\none = on-disk\n"
      @settings.stubs(:read_file).returns(text)
      @settings.send(:parse_config_files)

      expect(@settings[:one]).to eq("clival")
    end

    it "should remove in-memory values that are no longer set in the file" do
      # Init the value
      text = "[main]\none = disk-init\n"
      @settings.expects(:read_file).returns(text)
      @settings.send(:parse_config_files)
      expect(@settings[:one]).to eq("disk-init")

      # Now replace the value
      text = "[main]\ntwo = disk-replace\n"
      @settings.expects(:read_file).returns(text)
      @settings.send(:parse_config_files)

      # The originally-overridden value should be replaced with the default
      expect(@settings[:one]).to eq("ONE")

      # and we should now have the new value in memory
      expect(@settings[:two]).to eq("disk-replace")
    end

    it "should retain in-memory values if the file has a syntax error" do
      # Init the value
      text = "[main]\none = initial-value\n"
      @settings.expects(:read_file).with(@file).returns(text)
      @settings.send(:parse_config_files)
      expect(@settings[:one]).to eq("initial-value")

      # Now replace the value with something bogus
      text = "[main]\nkenny = killed-by-what-follows\n1 is 2, blah blah florp\n"
      @settings.expects(:read_file).with(@file).returns(text)
      @settings.send(:parse_config_files)

      # The originally-overridden value should not be replaced with the default
      expect(@settings[:one]).to eq("initial-value")

      # and we should not have the new value in memory
      expect(@settings[:kenny]).to be_nil
    end
  end

  it "should provide a method for creating a catalog of resources from its configuration" do
    expect(Puppet::Settings.new).to respond_to(:to_catalog)
  end

  describe "when creating a catalog" do
    before do
      @settings = Puppet::Settings.new
      @settings.stubs(:service_user_available?).returns true
      @prefix = Puppet.features.posix? ? "" : "C:"
    end

    it "should add all file resources to the catalog if no sections have been specified" do
      @settings.define_settings :main,
          :maindir => { :type => :directory, :default => @prefix+"/maindir", :desc => "a"},
          :seconddir => { :type => :directory, :default => @prefix+"/seconddir", :desc => "a"}
      @settings.define_settings :other,
          :otherdir => { :type => :directory, :default => @prefix+"/otherdir", :desc => "a" }

      catalog = @settings.to_catalog

      [@prefix+"/maindir", @prefix+"/seconddir", @prefix+"/otherdir"].each do |path|
        expect(catalog.resource(:file, path)).to be_instance_of(Puppet::Resource)
      end
    end

    it "should add only files in the specified sections if section names are provided" do
      @settings.define_settings :main, :maindir => { :type => :directory, :default => @prefix+"/maindir", :desc => "a" }
      @settings.define_settings :other, :otherdir => { :type => :directory, :default => @prefix+"/otherdir", :desc => "a" }
      catalog = @settings.to_catalog(:main)
      expect(catalog.resource(:file, @prefix+"/otherdir")).to be_nil
      expect(catalog.resource(:file, @prefix+"/maindir")).to be_instance_of(Puppet::Resource)
    end

    it "should not try to add the same file twice" do
      @settings.define_settings :main, :maindir => { :type => :directory, :default => @prefix+"/maindir", :desc => "a" }
      @settings.define_settings :other, :otherdir => { :type => :directory, :default => @prefix+"/maindir", :desc => "a" }
      expect { @settings.to_catalog }.not_to raise_error
    end

    it "should ignore files whose :to_resource method returns nil" do
      @settings.define_settings :main, :maindir => { :type => :directory, :default => @prefix+"/maindir", :desc => "a" }
      @settings.setting(:maindir).expects(:to_resource).returns nil

      Puppet::Resource::Catalog.any_instance.expects(:add_resource).never
      @settings.to_catalog
    end

    describe "on Microsoft Windows" do
      before :each do
        Puppet.features.stubs(:root?).returns true
        Puppet.features.stubs(:microsoft_windows?).returns true

        @settings.define_settings :foo,
            :mkusers => { :type => :boolean, :default => true, :desc => "e" },
            :user => { :default => "suser", :desc => "doc" },
            :group => { :default => "sgroup", :desc => "doc" }
        @settings.define_settings :other,
            :otherdir => { :type => :directory, :default => "/otherdir", :desc => "a", :owner => "service", :group => "service"}

        @catalog = @settings.to_catalog
      end

      it "it should not add users and groups to the catalog" do
        expect(@catalog.resource(:user, "suser")).to be_nil
        expect(@catalog.resource(:group, "sgroup")).to be_nil
      end
    end

    describe "adding default directory environment to the catalog" do
      let(:tmpenv) { tmpdir("envs") }
      let(:default_path) { "#{tmpenv}/environments" }
      before(:each) do
        @settings.define_settings :main,
          :environment     => { :default => "production", :desc => "env"},
          :environmentpath => { :type => :path, :default => default_path, :desc => "envpath"}
      end

      it "adds if environmentpath exists" do
        envpath = "#{tmpenv}/custom_envpath"
        @settings[:environmentpath] = envpath
        Dir.mkdir(envpath)
        catalog = @settings.to_catalog
        expect(catalog.resource_keys).to include(["File", "#{envpath}/production"])
      end

      it "adds the first directory of environmentpath" do
        envdir = "#{tmpenv}/custom_envpath"
        envpath = "#{envdir}#{File::PATH_SEPARATOR}/some/other/envdir"
        @settings[:environmentpath] = envpath
        Dir.mkdir(envdir)
        catalog = @settings.to_catalog
        expect(catalog.resource_keys).to include(["File", "#{envdir}/production"])
      end

      it "handles a non-existent environmentpath" do
        catalog = @settings.to_catalog
        expect(catalog.resource_keys).to be_empty
      end

      it "handles a default environmentpath" do
        Dir.mkdir(default_path)
        catalog = @settings.to_catalog
        expect(catalog.resource_keys).to include(["File", "#{default_path}/production"])
      end

      it "does not add if the path to the default directory environment exists as a symlink", :if => Puppet.features.manages_symlinks? do
        Dir.mkdir(default_path)
        Puppet::FileSystem.symlink("#{tmpenv}/nowhere", File.join(default_path, 'production'))
        catalog = @settings.to_catalog
        expect(catalog.resource_keys).to_not include(["File", "#{default_path}/production"])
      end
    end

    describe "when adding users and groups to the catalog" do
      before do
        Puppet.features.stubs(:root?).returns true
        Puppet.features.stubs(:microsoft_windows?).returns false

        @settings.define_settings :foo,
            :mkusers => { :type => :boolean, :default => true, :desc => "e" },
            :user => { :default => "suser", :desc => "doc" },
            :group => { :default => "sgroup", :desc => "doc" }
        @settings.define_settings :other, :otherdir => {:type => :directory, :default => "/otherdir", :desc => "a", :owner => "service", :group => "service"}

        @catalog = @settings.to_catalog
      end

      it "should add each specified user and group to the catalog if :mkusers is a valid setting, is enabled, and we're running as root" do
        expect(@catalog.resource(:user, "suser")).to be_instance_of(Puppet::Resource)
        expect(@catalog.resource(:group, "sgroup")).to be_instance_of(Puppet::Resource)
      end

      it "should only add users and groups to the catalog from specified sections" do
        @settings.define_settings :yay, :yaydir => { :type => :directory, :default => "/yaydir", :desc => "a", :owner => "service", :group => "service"}
        catalog = @settings.to_catalog(:other)
        expect(catalog.resource(:user, "jane")).to be_nil
        expect(catalog.resource(:group, "billy")).to be_nil
      end

      it "should not add users or groups to the catalog if :mkusers not running as root" do
        Puppet.features.stubs(:root?).returns false

        catalog = @settings.to_catalog
        expect(catalog.resource(:user, "suser")).to be_nil
        expect(catalog.resource(:group, "sgroup")).to be_nil
      end

      it "should not add users or groups to the catalog if :mkusers is not a valid setting" do
        Puppet.features.stubs(:root?).returns true
        settings = Puppet::Settings.new
        settings.define_settings :other, :otherdir => {:type => :directory, :default => "/otherdir", :desc => "a", :owner => "service", :group => "service"}

        catalog = settings.to_catalog
        expect(catalog.resource(:user, "suser")).to be_nil
        expect(catalog.resource(:group, "sgroup")).to be_nil
      end

      it "should not add users or groups to the catalog if :mkusers is a valid setting but is disabled" do
        @settings[:mkusers] = false

        catalog = @settings.to_catalog
        expect(catalog.resource(:user, "suser")).to be_nil
        expect(catalog.resource(:group, "sgroup")).to be_nil
      end

      it "should not try to add users or groups to the catalog twice" do
        @settings.define_settings :yay, :yaydir => {:type => :directory, :default => "/yaydir", :desc => "a", :owner => "service", :group => "service"}

        # This would fail if users/groups were added twice
        expect { @settings.to_catalog }.not_to raise_error
      end

      it "should set :ensure to :present on each created user and group" do
        expect(@catalog.resource(:user, "suser")[:ensure]).to eq(:present)
        expect(@catalog.resource(:group, "sgroup")[:ensure]).to eq(:present)
      end

      it "should set each created user's :gid to the service group" do
        expect(@settings.to_catalog.resource(:user, "suser")[:gid]).to eq("sgroup")
      end

      it "should not attempt to manage the root user" do
        Puppet.features.stubs(:root?).returns true
        @settings.define_settings :foo, :foodir => {:type => :directory, :default => "/foodir", :desc => "a", :owner => "root", :group => "service"}

        expect(@settings.to_catalog.resource(:user, "root")).to be_nil
      end
    end
  end

  it "should be able to be converted to a manifest" do
    expect(Puppet::Settings.new).to respond_to(:to_manifest)
  end

  describe "when being converted to a manifest" do
    it "should produce a string with the code for each resource joined by two carriage returns" do
      @settings = Puppet::Settings.new
      @settings.define_settings :main,
          :maindir => { :type => :directory, :default => "/maindir", :desc => "a"},
          :seconddir => { :type => :directory, :default => "/seconddir", :desc => "a"}

      main = stub 'main_resource', :ref => "File[/maindir]"
      main.expects(:to_manifest).returns "maindir"
      second = stub 'second_resource', :ref => "File[/seconddir]"
      second.expects(:to_manifest).returns "seconddir"
      @settings.setting(:maindir).expects(:to_resource).returns main
      @settings.setting(:seconddir).expects(:to_resource).returns second

      expect(@settings.to_manifest.split("\n\n").sort).to eq(%w{maindir seconddir})
    end
  end

  describe "when using sections of the configuration to manage the local host" do
    before do
      @settings = Puppet::Settings.new
      @settings.stubs(:service_user_available?).returns true
      @settings.stubs(:service_group_available?).returns true
      @settings.define_settings :main, :noop => { :default => false, :desc => "", :type => :boolean }
      @settings.define_settings :main,
          :maindir => { :type => :directory, :default => make_absolute("/maindir"), :desc => "a" },
          :seconddir => { :type => :directory, :default => make_absolute("/seconddir"), :desc => "a"}
      @settings.define_settings :main, :user => { :default => "suser", :desc => "doc" }, :group => { :default => "sgroup", :desc => "doc" }
      @settings.define_settings :other, :otherdir => {:type => :directory, :default => make_absolute("/otherdir"), :desc => "a", :owner => "service", :group => "service", :mode => '0755'}
      @settings.define_settings :third, :thirddir => { :type => :directory, :default => make_absolute("/thirddir"), :desc => "b"}
      @settings.define_settings :files, :myfile => {:type => :file, :default => make_absolute("/myfile"), :desc => "a", :mode => '0755'}
    end

    it "should create a catalog with the specified sections" do
      @settings.expects(:to_catalog).with(:main, :other).returns Puppet::Resource::Catalog.new("foo")
      @settings.use(:main, :other)
    end

    it "should canonicalize the sections" do
      @settings.expects(:to_catalog).with(:main, :other).returns Puppet::Resource::Catalog.new("foo")
      @settings.use("main", "other")
    end

    it "should ignore sections that have already been used" do
      @settings.expects(:to_catalog).with(:main).returns Puppet::Resource::Catalog.new("foo")
      @settings.use(:main)
      @settings.expects(:to_catalog).with(:other).returns Puppet::Resource::Catalog.new("foo")
      @settings.use(:main, :other)
    end

    it "should convert the created catalog to a RAL catalog" do
      @catalog = Puppet::Resource::Catalog.new("foo")
      @settings.expects(:to_catalog).with(:main).returns @catalog

      @catalog.expects(:to_ral).returns @catalog
      @settings.use(:main)
    end

    it "should specify that it is not managing a host catalog" do
      catalog = Puppet::Resource::Catalog.new("foo")
      catalog.expects(:apply)
      @settings.expects(:to_catalog).returns catalog

      catalog.stubs(:to_ral).returns catalog

      catalog.expects(:host_config=).with false

      @settings.use(:main)
    end

    it "should support a method for re-using all currently used sections" do
      @settings.expects(:to_catalog).with(:main, :third).times(2).returns Puppet::Resource::Catalog.new("foo")

      @settings.use(:main, :third)
      @settings.reuse
    end

    it "should fail with an appropriate message if any resources fail" do
      @catalog = Puppet::Resource::Catalog.new("foo")
      @catalog.stubs(:to_ral).returns @catalog
      @settings.expects(:to_catalog).returns @catalog

      @trans = mock("transaction")
      @catalog.expects(:apply).yields(@trans)

      @trans.expects(:any_failed?).returns(true)

      resource = Puppet::Type.type(:notify).new(:title => 'failed')
      status = Puppet::Resource::Status.new(resource)
      event = Puppet::Transaction::Event.new(
        :name => 'failure',
        :status => 'failure',
        :message => 'My failure')
      status.add_event(event)

      report = Puppet::Transaction::Report.new('apply')
      report.add_resource_status(status)

      @trans.expects(:report).returns report

      @settings.expects(:raise).with(includes("My failure"))
      @settings.use(:whatever)
    end
  end

  describe "when dealing with printing configs" do
    before do
      @settings = Puppet::Settings.new
      #these are the magic default values
      @settings.stubs(:value).with(:configprint).returns("")
      @settings.stubs(:value).with(:genconfig).returns(false)
      @settings.stubs(:value).with(:genmanifest).returns(false)
      @settings.stubs(:value).with(:environment).returns(nil)
    end

    describe "when checking print_config?" do
      it "should return false when the :configprint, :genconfig and :genmanifest are not set" do
        expect(@settings.print_configs?).to be_falsey
      end

      it "should return true when :configprint has a value" do
        @settings.stubs(:value).with(:configprint).returns("something")
        expect(@settings.print_configs?).to be_truthy
      end

      it "should return true when :genconfig has a value" do
        @settings.stubs(:value).with(:genconfig).returns(true)
        expect(@settings.print_configs?).to be_truthy
      end

      it "should return true when :genmanifest has a value" do
        @settings.stubs(:value).with(:genmanifest).returns(true)
        expect(@settings.print_configs?).to be_truthy
      end
    end

    describe "when printing configs" do
      describe "when :configprint has a value" do
        it "should call print_config_options" do
          @settings.stubs(:value).with(:configprint).returns("something")
          @settings.expects(:print_config_options)
          @settings.print_configs
        end

        it "should get the value of the option using the environment" do
          @settings.stubs(:value).with(:configprint).returns("something")
          @settings.stubs(:include?).with("something").returns(true)
          @settings.expects(:value).with(:environment).returns("env")
          @settings.expects(:value).with("something", "env").returns("foo")
          @settings.stubs(:puts).with("foo")
          @settings.print_configs
        end

        it "should print the value of the option" do
          @settings.stubs(:value).with(:configprint).returns("something")
          @settings.stubs(:include?).with("something").returns(true)
          @settings.stubs(:value).with("something", nil).returns("foo")
          @settings.expects(:puts).with("foo")
          @settings.print_configs
        end

        it "should print the value pairs if there are multiple options" do
          @settings.stubs(:value).with(:configprint).returns("bar,baz")
          @settings.stubs(:include?).with("bar").returns(true)
          @settings.stubs(:include?).with("baz").returns(true)
          @settings.stubs(:value).with("bar", nil).returns("foo")
          @settings.stubs(:value).with("baz", nil).returns("fud")
          @settings.expects(:puts).with("bar = foo")
          @settings.expects(:puts).with("baz = fud")
          @settings.print_configs
        end

        it "should return true after printing" do
          @settings.stubs(:value).with(:configprint).returns("something")
          @settings.stubs(:include?).with("something").returns(true)
          @settings.stubs(:value).with("something", nil).returns("foo")
          @settings.stubs(:puts).with("foo")
          expect(@settings.print_configs).to be_truthy
        end

        it "should return false if a config param is not found" do
          @settings.stubs :puts
          @settings.stubs(:value).with(:configprint).returns("something")
          @settings.stubs(:include?).with("something").returns(false)
          expect(@settings.print_configs).to be_falsey
        end
      end

      describe "when genconfig is true" do
        before do
          @settings.stubs :puts
        end

        it "should call to_config" do
          @settings.stubs(:value).with(:genconfig).returns(true)
          @settings.expects(:to_config)
          @settings.print_configs
        end

        it "should return true from print_configs" do
          @settings.stubs(:value).with(:genconfig).returns(true)
          @settings.stubs(:to_config)
          expect(@settings.print_configs).to be_truthy
        end
      end

      describe "when genmanifest is true" do
        before do
          @settings.stubs :puts
        end

        it "should call to_config" do
          @settings.stubs(:value).with(:genmanifest).returns(true)
          @settings.expects(:to_manifest)
          @settings.print_configs
        end

        it "should return true from print_configs" do
          @settings.stubs(:value).with(:genmanifest).returns(true)
          @settings.stubs(:to_manifest)
          expect(@settings.print_configs).to be_truthy
        end
      end
    end
  end

  describe "when determining if the service user is available" do
    let(:settings) do
      settings = Puppet::Settings.new
      settings.define_settings :main, :user => { :default => nil, :desc => "doc" }
      settings
    end

    def a_user_type_for(username)
      user = mock 'user'
      Puppet::Type.type(:user).expects(:new).with { |args| args[:name] == username }.returns user
      user
    end

    it "should return false if there is no user setting" do
      expect(settings).not_to be_service_user_available
    end

    it "should return false if the user provider says the user is missing" do
      settings[:user] = "foo"

      a_user_type_for("foo").expects(:exists?).returns false

      expect(settings).not_to be_service_user_available
    end

    it "should return true if the user provider says the user is present" do
      settings[:user] = "foo"

      a_user_type_for("foo").expects(:exists?).returns true

      expect(settings).to be_service_user_available
    end

    it "caches the result of determining if the user is present" do
      settings[:user] = "foo"

      a_user_type_for("foo").expects(:exists?).returns true
      expect(settings).to be_service_user_available

      expect(settings).to be_service_user_available
    end
  end

  describe "when determining if the service group is available" do
    let(:settings) do
      settings = Puppet::Settings.new
      settings.define_settings :main, :group => { :default => nil, :desc => "doc" }
      settings
    end

    def a_group_type_for(groupname)
      group = mock 'group'
      Puppet::Type.type(:group).expects(:new).with { |args| args[:name] == groupname }.returns group
      group
    end

    it "should return false if there is no group setting" do
      expect(settings).not_to be_service_group_available
    end

    it "should return false if the group provider says the group is missing" do
      settings[:group] = "foo"

      a_group_type_for("foo").expects(:exists?).returns false

      expect(settings).not_to be_service_group_available
    end

    it "should return true if the group provider says the group is present" do
      settings[:group] = "foo"

      a_group_type_for("foo").expects(:exists?).returns true

      expect(settings).to be_service_group_available
    end

    it "caches the result of determining if the group is present" do
      settings[:group] = "foo"

      a_group_type_for("foo").expects(:exists?).returns true
      expect(settings).to be_service_group_available

      expect(settings).to be_service_group_available
    end
  end

  describe "when dealing with command-line options" do
    let(:settings) { Puppet::Settings.new }

    it "should get options from Puppet.settings.optparse_addargs" do
      settings.expects(:optparse_addargs).returns([])

      settings.send(:parse_global_options, [])
    end

    it "should add options to OptionParser" do
      settings.stubs(:optparse_addargs).returns( [["--option","-o", "Funny Option", :NONE]])
      settings.expects(:handlearg).with("--option", true)
      settings.send(:parse_global_options, ["--option"])
    end

    it "should not die if it sees an unrecognized option, because the app/face may handle it later" do
      expect { settings.send(:parse_global_options, ["--topuppet", "value"]) } .to_not raise_error
    end

    it "should not pass an unrecognized option to handleargs" do
      settings.expects(:handlearg).with("--topuppet", "value").never
      expect { settings.send(:parse_global_options, ["--topuppet", "value"]) } .to_not raise_error
    end

    it "should pass valid puppet settings options to handlearg even if they appear after an unrecognized option" do
      settings.stubs(:optparse_addargs).returns( [["--option","-o", "Funny Option", :NONE]])
      settings.expects(:handlearg).with("--option", true)
      settings.send(:parse_global_options, ["--invalidoption", "--option"])
    end

    it "should transform boolean option to normal form" do
      expect(Puppet::Settings.clean_opt("--[no-]option", true)).to eq(["--option", true])
    end

    it "should transform boolean option to no- form" do
      expect(Puppet::Settings.clean_opt("--[no-]option", false)).to eq(["--no-option", false])
    end

    it "should set preferred run mode from --run_mode <foo> string without error" do
      args = ["--run_mode", "master"]
      settings.expects(:handlearg).with("--run_mode", "master").never
      expect { settings.send(:parse_global_options, args) } .to_not raise_error
      expect(Puppet.settings.preferred_run_mode).to eq(:master)
      expect(args.empty?).to eq(true)
    end

    it "should set preferred run mode from --run_mode=<foo> string without error" do
      args = ["--run_mode=master"]
      settings.expects(:handlearg).with("--run_mode", "master").never
      expect { settings.send(:parse_global_options, args) } .to_not raise_error
      expect(Puppet.settings.preferred_run_mode).to eq(:master)
      expect(args.empty?).to eq(true)
    end
  end

  describe "default_certname" do
    describe "using hostname and domain" do
      before :each do
        Puppet::Settings.stubs(:hostname_fact).returns("testhostname")
        Puppet::Settings.stubs(:domain_fact).returns("domain.test.")
      end

      it "should use both to generate fqdn" do
        expect(Puppet::Settings.default_certname).to match(/testhostname\.domain\.test/)
      end
      it "should remove trailing dots from fqdn" do
        expect(Puppet::Settings.default_certname).to eq('testhostname.domain.test')
      end
    end

    describe "using just hostname" do
      before :each do
        Puppet::Settings.stubs(:hostname_fact).returns("testhostname")
        Puppet::Settings.stubs(:domain_fact).returns("")
      end

      it "should use only hostname to generate fqdn" do
        expect(Puppet::Settings.default_certname).to eq("testhostname")
      end
      it "should removing trailing dots from fqdn" do
        expect(Puppet::Settings.default_certname).to eq("testhostname")
      end
    end
  end
end
