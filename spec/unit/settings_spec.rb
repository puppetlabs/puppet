require 'spec_helper'
require 'ostruct'
require 'puppet/settings/errors'
require 'puppet_spec/files'
require 'matchers/resource'

describe Puppet::Settings do
  include PuppetSpec::Files
  include Matchers::Resource

  let(:main_config_file_default_location) do
    File.join(Puppet::Util::RunMode[:server].conf_dir, "puppet.conf")
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
    before do
      @settings = Puppet::Settings.new
      @settings.define_settings(:main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS)
    end

    it "should fail if the app defaults hash is missing any required values" do
      expect {
        @settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES.reject { |key, _| key == :confdir })
      }.to raise_error(Puppet::Settings::SettingsError)
    end

    # ultimately I'd like to stop treating "run_mode" as a normal setting, because it has so many special
    #  case behaviors / uses.  However, until that time... we need to make sure that our private run_mode=
    #  setter method gets properly called during app initialization.
    it "sets the preferred run mode when initializing the app defaults" do
      @settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES.merge(:run_mode => :server))

      expect(@settings.preferred_run_mode).to eq(:server)
    end

    it "creates ancestor directories for all required app settings" do
      # initialize_app_defaults is called in spec_helper, before we even
      # get here, but call it here to make it explicit what we're trying
      # to do.
      @settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES)

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
      expect(@settings.instance_variable_get(:@value_sets)[:memory]).to receive(:lookup).with(:myval).and_return('foo')
      expect(@settings.set_by_config?(:myval)).to be_truthy
    end

    it "should identify configured settings from CLI" do
      expect(@settings.instance_variable_get(:@value_sets)[:cli]).to receive(:lookup).with(:myval).and_return('foo')
      expect(@settings.set_by_config?(:myval)).to be_truthy
    end

    it "should not identify configured settings from environment by default" do
      expect(Puppet.lookup(:environments)).not_to receive(:get_conf).with(Puppet[:environment].to_sym)
      expect(@settings.set_by_config?(:manifest)).to be_falsey
    end

    it "should identify configured settings from environment by when an environment is specified" do
      foo = double('environment', :manifest => 'foo')
      expect(Puppet.lookup(:environments)).to receive(:get_conf).with(Puppet[:environment].to_sym).and_return(foo)
      expect(@settings.set_by_config?(:manifest, Puppet[:environment])).to be_truthy
    end

    it "should identify configured settings from the preferred run mode" do
      user_config_text = "[#{@settings.preferred_run_mode}]\nmyval = foo"

      allow(Puppet.features).to receive(:root?).and_return(false)
      expect(Puppet::FileSystem).to receive(:exist?).
        with(user_config_file_default_location).
        and_return(true).ordered
      expect(@settings).to receive(:read_file).
        with(user_config_file_default_location).
        and_return(user_config_text).ordered

      @settings.send(:parse_config_files)
      expect(@settings.set_by_config?(:myval)).to be_truthy
    end

    it "should identify configured settings from the specified run mode" do
      user_config_text = "[server]\nmyval = foo"

      allow(Puppet.features).to receive(:root?).and_return(false)
      expect(Puppet::FileSystem).to receive(:exist?).
        with(user_config_file_default_location).
        and_return(true).ordered
      expect(@settings).to receive(:read_file).
        with(user_config_file_default_location).
        and_return(user_config_text).ordered

      @settings.send(:parse_config_files)
      expect(@settings.set_by_config?(:myval, nil, :server)).to be_truthy
    end

    it "should not identify configured settings from an unspecified run mode" do
      user_config_text = "[zaz]\nmyval = foo"

      allow(Puppet.features).to receive(:root?).and_return(false)
      expect(Puppet::FileSystem).to receive(:exist?).
        with(user_config_file_default_location).
        and_return(true).ordered
      expect(@settings).to receive(:read_file).
        with(user_config_file_default_location).
        and_return(user_config_text).ordered

      @settings.send(:parse_config_files)
      expect(@settings.set_by_config?(:myval)).to be_falsey
    end

    it "should identify configured settings from the main section" do
      user_config_text = "[main]\nmyval = foo"

      allow(Puppet.features).to receive(:root?).and_return(false)
      expect(Puppet::FileSystem).to receive(:exist?).
        with(user_config_file_default_location).
        and_return(true).ordered
      expect(@settings).to receive(:read_file).
        with(user_config_file_default_location).
        and_return(user_config_text).ordered

      @settings.send(:parse_config_files)
      expect(@settings.set_by_config?(:myval)).to be_truthy
    end

    it "should clear the cache when setting getopt-specific values" do
      @settings.define_settings :mysection,
          :one => { :default => "whah", :desc => "yay" },
          :two => { :default => "$one yay", :desc => "bah" }
      expect(@settings).to receive(:unsafe_flush_cache)
      expect(@settings[:two]).to eq("whah yay")
      @settings.handlearg("--one", "else")
      expect(@settings[:two]).to eq("else yay")
    end

    it "should clear the cache when the preferred_run_mode is changed" do
      expect(@settings).to receive(:flush_cache)
      @settings.preferred_run_mode = :server
    end

    it "should not clear other values when setting getopt-specific values" do
      @settings[:myval] = "yay"
      @settings.handlearg("--no-bool", "")
      expect(@settings[:myval]).to eq("yay")
    end

    it "should clear the list of used sections" do
      expect(@settings).to receive(:clearused)
      @settings[:myval] = "yay"
    end

    describe "call_hook" do
      let(:config_file) { tmpfile('config') }

      before :each do
        # We can't specify the config file to read from using `Puppet[:config] =`
        # or pass it as an arg to Puppet.initialize_global_settings, because
        # both of those will set the value on the `Puppet.settings` instance
        # which is different from the `@settings` instance created in the test.
        # Instead, we define a `:config` setting and set its default value to
        # the `config_file` temp file, and then access the `config_file` within
        # each test.
        @settings.define_settings(:main, :config => { :type => :file, :desc => "config file", :default => config_file })
      end

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
              expect(@settings.setting(:hooker)).to receive(:handle).with("something").once
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
          expect(Puppet).to receive(:warning)
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

      describe "when :on_write_only" do
        it "returns its hook type" do
          @settings.define_settings(:main, :hooker => {:default => "yay", :desc => "boo", :hook => lambda { |_| }})

          expect(@settings.setting(:hooker).call_hook).to eq(:on_write_only)
        end

        it "should not call the hook at definition" do
          hook_values = []
          @settings.define_settings(:main, :hooker => {:default => "yay", :desc => "boo", :hook => lambda { |v| hook_values << v  }})

          expect(hook_values).to eq(%w[])
        end

        it "calls the hook when initializing global defaults with the value from the `main` section" do
          hook_values = []
          @settings.define_settings(:main, :hooker => {:default => "yay", :desc => "boo", :hook => lambda { |v| hook_values << v  }})

          File.write(config_file, <<~END)
            [main]
            hooker=in_main
          END
          @settings.initialize_global_settings

          expect(@settings[:hooker]).to eq('in_main')
          expect(hook_values).to eq(%w[in_main])
        end

        it "doesn't call the hook when initializing app defaults" do
          hook_values = []
          @settings.define_settings(:main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS)
          @settings.define_settings(:main, :hooker => {:default => "yay", :desc => "boo", :hook => lambda { |v| hook_values << v }})

          File.write(config_file, <<~END)
            [main]
            hooker=in_main
            [agent]
            hooker=in_agent
          END
          @settings.initialize_global_settings

          hook_values.clear

          @settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES)

          expect(@settings[:hooker]).to eq('in_main')
          expect(hook_values).to eq(%w[])
        end

        it "doesn't call the hook with value from a section that matches the run_mode" do
          hook_values = []
          @settings.define_settings(:main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS)
          @settings.define_settings(:main, :hooker => {:default => "yay", :desc => "boo", :hook => lambda { |v| hook_values << v  }})

          File.write(config_file, <<~END)
            [main]
            hooker=in_main
            [agent]
            hooker=in_agent
          END
          @settings.initialize_global_settings

          hook_values.clear

          @settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES.merge(:run_mode => :agent))

          expect(@settings[:hooker]).to eq('in_agent')
          expect(hook_values).to eq(%w[])
        end
      end

      describe "when :on_define_and_write" do
        it "returns its hook type" do
          @settings.define_settings(:main, :hooker => {:default => "yay", :desc => "boo", :call_hook => :on_define_and_write, :hook => lambda { |_| }})

          expect(@settings.setting(:hooker).call_hook).to eq(:on_define_and_write)
        end

        it "should call the hook at definition with the default value" do
          hook_values = []
          @settings.define_settings(:main, :hooker => {:default => "yay", :desc => "boo", :call_hook => :on_define_and_write, :hook => lambda { |v| hook_values << v  }})

          expect(hook_values).to eq(%w[yay])
        end

        it "calls the hook when initializing global defaults with the value from the `main` section" do
          hook_values = []
          @settings.define_settings(:main, :hooker => {:default => "yay", :desc => "boo", :call_hook => :on_define_and_write, :hook => lambda { |v| hook_values << v  }})

          File.write(config_file, <<~END)
            [main]
            hooker=in_main
          END
          @settings.initialize_global_settings

          expect(@settings[:hooker]).to eq('in_main')
          expect(hook_values).to eq(%w[yay in_main])
        end

        it "doesn't call the hook when initializing app defaults" do
          hook_values = []
          @settings.define_settings(:main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS)
          @settings.define_settings(:main, :hooker => {:default => "yay", :desc => "boo", :call_hook => :on_define_and_write, :hook => lambda { |v| hook_values << v  }})

          File.write(config_file, <<~END)
            [main]
            hooker=in_main
            [agent]
            hooker=in_agent
          END
          @settings.initialize_global_settings

          hook_values.clear

          @settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES)

          expect(@settings[:hooker]).to eq('in_main')
          expect(hook_values).to eq([])
        end

        it "doesn't call the hook with value from a section that matches the run_mode" do
          hook_values = []
          @settings.define_settings(:main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS)
          @settings.define_settings(:main, :hooker => {:default => "yay", :desc => "boo", :call_hook => :on_define_and_write, :hook => lambda { |v| hook_values << v  }})

          File.write(config_file, <<~END)
            [main]
            hooker=in_main
            [agent]
            hooker=in_agent
          END

          @settings.initialize_global_settings

          hook_values.clear

          @settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES.merge(:run_mode => :agent))

          # The correct value is returned
          expect(@settings[:hooker]).to eq('in_agent')

          # but the hook is never called, seems like a bug!
          expect(hook_values).to eq([])
        end
      end

      describe "when :on_initialize_and_write" do
        it "returns its hook type" do
          @settings.define_settings(:main, :hooker => {:default => "yay", :desc => "boo", :call_hook => :on_initialize_and_write, :hook => lambda { |_| }})

          expect(@settings.setting(:hooker).call_hook).to eq(:on_initialize_and_write)
        end

        it "should not call the hook at definition" do
          hook_values = []
          @settings.define_settings(:main, :hooker => {:default => "yay", :desc => "boo", :call_hook => :on_initialize_and_write, :hook => lambda { |v| hook_values << v }})
          expect(hook_values).to eq([])
        end

        it "calls the hook when initializing global defaults with the value from the `main` section" do
          hook_values = []
          @settings.define_settings(:main, :hooker => {:default => "yay", :desc => "boo", :call_hook => :on_initialize_and_write, :hook => lambda { |v| hook_values << v }})

          File.write(config_file, <<~END)
            [main]
            hooker=in_main
          END
          @settings.initialize_global_settings

          expect(@settings[:hooker]).to eq('in_main')
          expect(hook_values).to eq(%w[in_main])
        end

        it "calls the hook when initializing app defaults" do
          hook_values = []
          @settings.define_settings(:main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS)
          @settings.define_settings(:main, :hooker => {:default => "yay", :desc => "boo", :call_hook => :on_initialize_and_write, :hook => lambda { |v| hook_values << v }})

          File.write(config_file, <<~END)
            [main]
            hooker=in_main
            [agent]
            hooker=in_agent
          END
          @settings.initialize_global_settings

          hook_values.clear

          @settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES)

          expect(@settings[:hooker]).to eq('in_main')
          expect(hook_values).to eq(%w[in_main])
        end

        it "calls the hook with the overridden value from a section that matches the run_mode" do
          hook_values = []
          @settings.define_settings(:main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS)
          @settings.define_settings(:main, :hooker => {:default => "yay", :desc => "boo", :call_hook => :on_initialize_and_write, :hook => lambda { |v| hook_values << v  }})

          File.write(config_file, <<~END)
            [main]
            hooker=in_main
            [agent]
            hooker=in_agent
          END
          @settings.initialize_global_settings

          hook_values.clear

          @settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES.merge(:run_mode => :agent))

          expect(@settings[:hooker]).to eq('in_agent')
          expect(hook_values).to eq(%w[in_agent])
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
          :five   => { :default => nil, :desc => "e" },
          :code   => { :default => "", :desc => "my code"}
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
    end

    it "should provide a mechanism for returning set values" do
      @settings[:one] = "other"
      expect(@settings[:one]).to eq("other")
    end

    it "setting a value to nil causes it to return to its default" do
      @settings.define_settings :main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS
      @settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES.merge(:one => "skipped value"))
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

    it "should not interpolate the value of the :code setting" do
      @code = @settings.setting(:code)
      expect(@code).not_to receive(:munge)

      expect(@settings[:code]).to eq("")
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
    let(:config_file) { tmpfile('settings') }

    before do
      @settings = Puppet::Settings.new
      @settings.define_settings :section,
        :config => { :type => :file, :default => config_file, :desc => "a" },
        :one => { :default => "ONE", :desc => "a" },
        :two => { :default => "TWO", :desc => "b" }
      @settings.preferred_run_mode = :agent
    end

    it "should return default values if no values have been set" do
      expect(@settings[:one]).to eq("ONE")
    end

    it "should return values set on the cli before values set in the configuration file" do
      File.write(config_file, "[main]\none = fileval\n")
      @settings.handlearg("--one", "clival")
      @settings.initialize_global_settings

      expect(@settings[:one]).to eq("clival")
    end

    it "should return values set in the mode-specific section before values set in the main section" do
      File.write(config_file, "[main]\none = mainval\n[agent]\none = modeval\n")
      @settings.initialize_global_settings

      expect(@settings[:one]).to eq("modeval")
    end

    [:master, :server].each do |run_mode|
      describe "when run mode is '#{run_mode}'" do
        before(:each) { @settings.preferred_run_mode = run_mode }

        it "returns values set in the 'master' section if the 'server' section does not exist" do
          File.write(config_file, "[main]\none = mainval\n[master]\none = modeval\n")
          @settings.initialize_global_settings

          expect(@settings[:one]).to eq("modeval")
        end

        it "prioritizes values set in the 'server' section if set" do
          File.write(config_file,  "[main]\none = mainval\n[server]\none = serverval\n[master]\none = masterval\n")
          @settings.initialize_global_settings

          expect(@settings[:one]).to eq("serverval")
        end
      end
    end

    it "should not return values outside of its search path" do
      File.write(config_file, "[other]\none = oval\n")
      @settings.initialize_global_settings

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
        allow(Puppet.features).to receive(:root?).and_return(true)
        expect(Puppet::FileSystem).to receive(:exist?).with(main_config_file_default_location).and_return(false)
        expect(Puppet::FileSystem).not_to receive(:exist?).with(user_config_file_default_location)

        @settings.initialize_global_settings
      end
    end

    describe "when not root" do
      it "should look for user config file default location if config settings haven't been overridden'" do
        allow(Puppet.features).to receive(:root?).and_return(false)

        expect(Puppet::FileSystem).to receive(:exist?).with(user_config_file_default_location).and_return(false)

        @settings.initialize_global_settings
      end
    end

    describe "when the file exists" do
      it "fails if the file is not readable" do
        expect(Puppet::FileSystem).to receive(:exist?).with(user_config_file_default_location).and_return(true)
        expect(@settings).to receive(:read_file).and_raise('Permission denied')

        expect{ @settings.initialize_global_settings }.to raise_error(RuntimeError, /Could not load #{user_config_file_default_location}: Permission denied/)
      end

      it "does not fail if the file is not readable and when `require_config` is false" do
        expect(Puppet::FileSystem).to receive(:exist?).with(user_config_file_default_location).and_return(true)
        expect(@settings).to receive(:read_file).and_raise('Permission denied')

        expect(@settings).not_to receive(:parse_config)
        expect(Puppet).to receive(:log_exception)

        expect{ @settings.initialize_global_settings([], false) }.not_to raise_error
      end

      it "reads the file if it is readable" do
        expect(Puppet::FileSystem).to receive(:exist?).with(user_config_file_default_location).and_return(true)
        expect(@settings).to receive(:read_file).and_return('server = host.string')
        expect(@settings).to receive(:parse_config)

        @settings.initialize_global_settings
      end
    end

    describe "when the file does not exist" do
      it "does not attempt to parse the config file" do
        expect(Puppet::FileSystem).to receive(:exist?).with(user_config_file_default_location).and_return(false)
        expect(@settings).not_to receive(:parse_config)

        @settings.initialize_global_settings
      end
    end
  end

  describe "when parsing its configuration" do
    before do
      @settings = Puppet::Settings.new
      allow(@settings).to receive(:service_user_available?).and_return(true)
      allow(@settings).to receive(:service_group_available?).and_return(true)
      @file = tmpfile("somefile")
      @settings.define_settings :section, :user => { :default => "suser", :desc => "doc" }, :group => { :default => "sgroup", :desc => "doc" }
      @settings.define_settings :section,
          :config => { :type => :file, :default => @file, :desc => "eh" },
          :one => { :default => "ONE", :desc => "a" },
          :two => { :default => "$one TWO", :desc => "b" },
          :three => { :default => "$one $two THREE", :desc => "c" }

      userconfig = tmpfile("userconfig")
      allow(@settings).to receive(:user_config_file).and_return(userconfig)
    end

    it "should not ignore the report setting" do
      @settings.define_settings :section, :report => { :default => "false", :desc => "a" }
      File.write(@file, <<~CONF)
        [puppetd]
        report=true
      CONF

      @settings.initialize_global_settings

      expect(@settings[:report]).to be_truthy
    end

    it "should use its current ':config' value for the file to parse" do
      myfile = tmpfile('myfile')
      File.write(myfile, <<~CONF)
        [main]
        one=myfile
      CONF

      @settings[:config] = myfile
      @settings.initialize_global_settings

      expect(@settings[:one]).to eq('myfile')
    end

    it "should not try to parse non-existent files" do
      expect(Puppet::FileSystem).to receive(:exist?).with(@file).and_return(false)

      expect(File).not_to receive(:read).with(@file)

      @settings.initialize_global_settings
    end

    it "should return values set in the configuration file" do
      File.write(@file, <<~CONF)
        [main]
        one = fileval
      CONF

      @settings.initialize_global_settings
      expect(@settings[:one]).to eq("fileval")
    end

    #484 - this should probably be in the regression area
    it "should not throw an exception on unknown parameters" do
      File.write(@file, <<~CONF)
        [main]
        nosuchparam = mval
      CONF

      expect { @settings.initialize_global_settings }.not_to raise_error
    end

    it "should convert booleans in the configuration file into Ruby booleans" do
      File.write(@file, <<~CONF)
        [main]
        one = true
        two = false
      CONF

      @settings.initialize_global_settings

      expect(@settings[:one]).to eq(true)
      expect(@settings[:two]).to eq(false)
    end

    it "should convert integers in the configuration file into Ruby Integers" do
      File.write(@file, <<~CONF)
        [main]
        one = 65
      CONF

      @settings.initialize_global_settings

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
      @settings.define_settings :main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS
      @settings.define_settings :server, :myfile => { :type => :file, :default => make_absolute("/myfile"), :desc => "a" }

      otherfile = make_absolute("/other/file")
      File.write(@file, <<~CONF)
        [server]
        myfile = #{otherfile} {mode = 664}
      CONF

      # will start initialization as user
      expect(@settings.preferred_run_mode).to eq(:user)
      @settings.initialize_global_settings

      # change app run_mode to server
      @settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES.merge(:run_mode => :server))
      expect(@settings.preferred_run_mode).to eq(:server)

      # initializing the app should have reloaded the metadata based on run_mode
      expect(@settings[:myfile]).to eq(otherfile)
      expect(metadata(@settings.setting(:myfile))).to eq({:mode => "664"})
    end

    context "when setting serverport and masterport" do
      before(:each) do
        @settings.define_settings :main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS
        @settings.define_settings :server, :masterport => { :desc => "a", :default => 1000 }
        @settings.define_settings :server, :serverport => { :desc => "a", :default => 1000 }
        @settings.define_settings :server, :ca_port => { :desc => "a", :default => "$serverport" }
        @settings.define_settings :server, :report_port => { :desc => "a", :default => "$serverport" }

        config_file = tmpfile('config')
        @settings[:config] = config_file
        File.write(config_file, text)

        @settings.initialize_global_settings
        @settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES.merge(:run_mode => :agent))
        expect(@settings.preferred_run_mode).to eq(:agent)
      end

      context 'with serverport in main and masterport in agent' do
        let(:text) do
          "[main]
      serverport = 444
      [agent]
      masterport = 445
      "
        end

        it { expect(@settings[:serverport]).to eq(445) }
        it { expect(@settings[:ca_port]).to eq("445") }
        it { expect(@settings[:report_port]).to eq("445") }
      end

      context 'with serverport and masterport in main' do
        let(:text) do
          "[main]
      serverport = 445
      masterport = 444
      "
        end

        it { expect(@settings[:serverport]).to eq(445) }
        it { expect(@settings[:ca_port]).to eq("445") }
        it { expect(@settings[:report_port]).to eq("445") }
      end

      context 'with serverport and masterport in agent' do
        let(:text) do
          "[agent]
      serverport = 445
      masterport = 444
      "
        end

        it { expect(@settings[:serverport]).to eq(445) }
        it { expect(@settings[:ca_port]).to eq("445") }
        it { expect(@settings[:report_port]).to eq("445") }
      end

      context 'with both serverport and masterport in main and agent' do
        let(:text) do
          "[main]
      serverport = 447
      masterport = 442
      [agent]
      serverport = 445
      masterport = 444
      "
        end

        it { expect(@settings[:serverport]).to eq(445) }
        it { expect(@settings[:ca_port]).to eq("445") }
        it { expect(@settings[:report_port]).to eq("445") }
      end

      context 'with serverport in agent and masterport in main' do
        let(:text) do
          "[agent]
      serverport = 444
      [main]
      masterport = 445
      "
        end

        it { expect(@settings[:serverport]).to eq(444) }
        it { expect(@settings[:ca_port]).to eq("444") }
        it { expect(@settings[:report_port]).to eq("444") }
      end

      context 'with masterport in main' do
        let(:text) do
          "[main]
      masterport = 445
      "
        end

        it { expect(@settings[:serverport]).to eq(445) }
        it { expect(@settings[:ca_port]).to eq("445") }
        it { expect(@settings[:report_port]).to eq("445") }
      end

      context 'with masterport in agent' do
        let(:text) do
          "[agent]
      masterport = 445
      "
        end

        it { expect(@settings[:serverport]).to eq(445) }
        it { expect(@settings[:ca_port]).to eq("445") }
        it { expect(@settings[:report_port]).to eq("445") }
      end

      context 'with serverport in agent' do
        let(:text) do
          "[agent]
      serverport = 445
      "
        end

        it { expect(@settings[:serverport]).to eq(445) }
        it { expect(@settings[:masterport]).to eq(445) }
        it { expect(@settings[:ca_port]).to eq("445") }
        it { expect(@settings[:report_port]).to eq("445") }
      end

      context 'with serverport in main' do
        let(:text) do
          "[main]
      serverport = 445
      "
        end

        it { expect(@settings[:serverport]).to eq(445) }
        it { expect(@settings[:masterport]).to eq(445) }
        it { expect(@settings[:ca_port]).to eq("445") }
        it { expect(@settings[:report_port]).to eq("445") }
      end
    end

    it "does not use the metadata from the same setting in a different section" do
      file = make_absolute("/file")
      default_mode = "0600"
      @settings.define_settings :main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS
      @settings.define_settings :server, :myfile => { :type => :file, :default => file, :desc => "a", :mode => default_mode }

      File.write(@file, <<~CONF)
        [server]
        myfile = #{file}/foo
        [agent]
        myfile = #{file} {mode = 664}
      CONF

      # will start initialization as user
      expect(@settings.preferred_run_mode).to eq(:user)
      @settings.initialize_global_settings

      # change app run_mode to server
      @settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES.merge(:run_mode => :server))
      expect(@settings.preferred_run_mode).to eq(:server)

      # initializing the app should have reloaded the metadata based on run_mode
      expect(@settings[:myfile]).to eq("#{file}/foo")
      expect(metadata(@settings.setting(:myfile))).to eq({ :mode => default_mode })
    end

    it "should call hooks associated with values set in the configuration file" do
      values = []
      @settings.define_settings :section, :mysetting => {:default => "defval", :desc => "a", :hook => proc { |v| values << v }}

      File.write(@file, <<~CONF)
        [main]
        mysetting = setval
      CONF
      @settings.initialize_global_settings

      expect(values).to eq(["setval"])
    end

    it "should not call the same hook for values set multiple times in the configuration file" do
      values = []
      @settings.define_settings :section, :mysetting => {:default => "defval", :desc => "a", :hook => proc { |v| values << v }}

      File.write(@file, <<~CONF)
        [user]
        mysetting = setval
        [main]
        mysetting = other
      CONF
      @settings.initialize_global_settings

      expect(values).to eq(["setval"])
    end

    it "should pass the interpolated value to the hook when one is available" do
      values = []
      @settings.define_settings :section, :base => {:default => "yay", :desc => "a", :hook => proc { |v| values << v }}
      @settings.define_settings :section, :mysetting => {:default => "defval", :desc => "a", :hook => proc { |v| values << v }}

      File.write(@file, <<~CONF)
        [main]
        mysetting = $base/setval
      CONF
      @settings.initialize_global_settings

      expect(values).to eq(["yay/setval"])
    end

    it "should allow hooks invoked at parse time to be deferred" do
      hook_invoked = false
      @settings.define_settings :section, :deferred  => {:desc => '',
                                                         :hook => proc { |v| hook_invoked = true },
                                                         :call_hook => :on_initialize_and_write, }

      # This test relies on `confdir` defaulting to nil which causes the default
      # value of `deferred=$confdir/goose` to raise an interpolation error during
      # global initialization, and the hook to be skipped
      @settings.define_settings(:main,
                                PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS.merge(
                                  :confdir => { :type => :directory, :default => nil, :desc => "confdir" }))

      File.write(@file, <<~EOD)
        [main]
        deferred=$confdir/goose
      EOD

      @settings.initialize_global_settings

      expect(hook_invoked).to be_falsey

      # And now that we initialize app defaults with `confdir`, then `deferred`
      # can be interpolated and its hook called
      @settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES.merge(:confdir => '/path/to/confdir'))

      expect(hook_invoked).to be_truthy
      expect(@settings[:deferred]).to eq(File.expand_path('/path/to/confdir/goose'))
    end

    it "does not require the value for a setting without a hook to resolve during global setup" do
      @settings.define_settings :section, :can_cause_problems  => {:desc => '' }

      @settings.define_settings(:main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS)

      File.write(@file, <<~EOD)
      [main]
      can_cause_problems=$confdir/goose
      EOD

      @settings.initialize_global_settings
      @settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES.merge(:confdir => '/path/to/confdir'))

      expect(@settings[:can_cause_problems]).to eq('/path/to/confdir/goose')
    end

    it "should allow empty values" do
      @settings.define_settings :section, :myarg => { :default => "myfile", :desc => "a" }

      File.write(@file, <<~CONF)
        [main]
        myarg =
      CONF
      @settings.initialize_global_settings

      expect(@settings[:myarg]).to eq("")
    end

    describe "deprecations" do
      let(:settings) { Puppet::Settings.new }

      def assert_accessing_setting_is_deprecated(settings, setting)
        expect(Puppet).to receive(:deprecation_warning).with("Accessing '#{setting}' as a setting is deprecated.")
        expect(Puppet).to receive(:deprecation_warning).with("Modifying '#{setting}' as a setting is deprecated.")
        settings[setting.intern] = apath = File.expand_path('foo')
        expect(settings[setting.intern]).to eq(apath)
      end

      before(:each) do
        settings.define_settings(:main, PuppetSpec::Settings::TEST_APP_DEFAULT_DEFINITIONS)
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
          expect(Puppet).to receive(:deprecation_warning).with(/completely_deprecated_setting is deprecated\./, 'setting-completely_deprecated_setting')

          completely_deprecated_settings.parse_config(<<-CONF)
            completely_deprecated_setting='should warn'
          CONF
          completely_deprecated_settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES)
        end

        it "warns when set on the commandline" do
          expect(Puppet).to receive(:deprecation_warning).with(/completely_deprecated_setting is deprecated\./, 'setting-completely_deprecated_setting')

          args = ["--completely_deprecated_setting", "/some/value"]
          completely_deprecated_settings.send(:parse_global_options, args)
          completely_deprecated_settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES)
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
          expect(Puppet).to receive(:deprecation_warning).with(/partially_deprecated_setting is deprecated in puppet\.conf/, 'puppet-conf-setting-partially_deprecated_setting')
          partially_deprecated_settings.parse_config(<<-CONF)
            partially_deprecated_setting='should warn'
          CONF
          partially_deprecated_settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES)
        end

        it "does not warn when manifest is set on command line" do
          expect(Puppet).not_to receive(:deprecation_warning)

          args = ["--partially_deprecated_setting", "/some/value"]
          partially_deprecated_settings.send(:parse_global_options, args)
          partially_deprecated_settings.initialize_app_defaults(PuppetSpec::Settings::TEST_APP_DEFAULT_VALUES)
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
        allow(Puppet.features).to receive(:root?).and_return(false)
        expect(Puppet::FileSystem).to receive(:exist?).
          with(user_config_file_default_location).
          and_return(true).ordered
        expect(@settings).to receive(:read_file).
          with(user_config_file_default_location).
          and_return(user_config_text).ordered
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
        allow(Puppet.features).to receive(:root?).and_return(true)
        expect(Puppet::FileSystem).to receive(:exist?).
          with(main_config_file_default_location).
          and_return(true).ordered
        expect(@settings).to receive(:read_file).
          with(main_config_file_default_location).
          and_return(main_config_text).ordered
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
        allow(Puppet.features).to receive(:root?).and_return(false)
        @settings[:confdir] = File.dirname(main_config_file_default_location)
        expect(Puppet::FileSystem).to receive(:exist?).
          with(main_config_file_default_location).
          and_return(true).ordered
        expect(@settings).to receive(:read_file).
          with(main_config_file_default_location).
          and_return(main_config_text).ordered
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
      @file = tmpfile("testfile")
      Puppet::FileSystem.touch(@file)

      @settings = Puppet::Settings.new
      @settings.define_settings :section,
          :config => { :type => :file, :default => @file, :desc => "a" },
          :one => { :default => "ONE", :desc => "a" },
          :two => { :default => "$one TWO", :desc => "b" },
          :three => { :default => "$one $two THREE", :desc => "c" }

      userconfig = tmpfile("userconfig")
      allow(@settings).to receive(:user_config_file).and_return(userconfig)
    end

    it "does not create the WatchedFile instance and should not parse if the file does not exist" do
      Puppet::FileSystem.unlink(@file)

      expect(Puppet::Util::WatchedFile).not_to receive(:new)
      expect(@settings).not_to receive(:parse_config_files)

      @settings.reparse_config_files
    end

    context "and watched file exists" do
      before do
        @watched_file = Puppet::Util::WatchedFile.new(@file)
        expect(Puppet::Util::WatchedFile).to receive(:new).with(@file).and_return(@watched_file)
      end

      it "uses a WatchedFile instance to determine if the file has changed" do
        expect(@watched_file).to receive(:changed?)

        @settings.reparse_config_files
      end

      it "does not reparse if the file has not changed" do
        expect(@watched_file).to receive(:changed?).and_return(false)

        expect(@settings).not_to receive(:parse_config_files)

        @settings.reparse_config_files
      end

      it "reparses if the file has changed" do
        expect(@watched_file).to receive(:changed?).and_return(true)

        expect(@settings).to receive(:parse_config_files)

        @settings.reparse_config_files
      end

      it "replaces in-memory values with on-file values" do
        allow(@watched_file).to receive(:changed?).and_return(true)
        @settings[:one] = "init"

        # Now replace the value
        File.write(@file, "[main]\none = disk-replace\n")

        @settings.reparse_config_files
        expect(@settings[:one]).to eq("disk-replace")
      end
    end

    it "should retain parameters set by cli when configuration files are reparsed" do
      @settings.handlearg("--one", "clival")

      File.write(@file, "[main]\none = on-disk\n")
      @settings.initialize_global_settings

      expect(@settings[:one]).to eq("clival")
    end

    it "should remove in-memory values that are no longer set in the file" do
      # Init the value
      File.write(@file, "[main]\none = disk-init\n")
      @settings.send(:parse_config_files)
      expect(@settings[:one]).to eq("disk-init")

      # Now replace the value
      File.write(@file, "[main]\ntwo = disk-replace\n")
      @settings.send(:parse_config_files)

      # The originally-overridden value should be replaced with the default
      expect(@settings[:one]).to eq("ONE")

      # and we should now have the new value in memory
      expect(@settings[:two]).to eq("disk-replace")
    end

    it "should retain in-memory values if the file has a syntax error" do
      # Init the value
      File.write(@file, "[main]\none = initial-value\n")
      @settings.initialize_global_settings
      expect(@settings[:one]).to eq("initial-value")

      # Now replace the value with something bogus
      File.write(@file, "[main]\nkenny = killed-by-what-follows\n1 is 2, blah blah florp\n")
      @settings.send(:parse_config_files)

      # The originally-overridden value should not be replaced with the default
      expect(@settings[:one]).to eq("initial-value")

      # and we should not have the new value in memory
      expect(@settings[:kenny]).to be_nil
    end
  end

  it "should provide a method for creating a catalog of resources from its configuration" do
    expect(Puppet::Settings.new.to_catalog).to be_an_instance_of(Puppet::Resource::Catalog)
  end

  describe "when creating a catalog" do
    let(:maindir) { make_absolute('/maindir') }
    let(:seconddir) { make_absolute('/seconddir') }
    let(:otherdir) { make_absolute('/otherdir') }

    before do
      @settings = Puppet::Settings.new
      allow(@settings).to receive(:service_user_available?).and_return(true)
    end

    it "should add all file resources to the catalog if no sections have been specified" do
      @settings.define_settings :main,
          :maindir => { :type => :directory, :default => maindir, :desc => "a"},
          :seconddir => { :type => :directory, :default => seconddir, :desc => "a"}
      @settings.define_settings :other,
          :otherdir => { :type => :directory, :default => otherdir, :desc => "a" }

      catalog = @settings.to_catalog

      [maindir, seconddir, otherdir].each do |path|
        expect(catalog.resource(:file, path)).to be_instance_of(Puppet::Resource)
      end
    end

    it "should add only files in the specified sections if section names are provided" do
      @settings.define_settings :main, :maindir => { :type => :directory, :default => maindir, :desc => "a" }
      @settings.define_settings :other, :otherdir => { :type => :directory, :default => otherdir, :desc => "a" }
      catalog = @settings.to_catalog(:main)
      expect(catalog.resource(:file, otherdir)).to be_nil
      expect(catalog.resource(:file, maindir)).to be_instance_of(Puppet::Resource)
    end

    it "should not try to add the same file twice" do
      @settings.define_settings :main, :maindir => { :type => :directory, :default => maindir, :desc => "a" }
      @settings.define_settings :other, :otherdir => { :type => :directory, :default => maindir, :desc => "a" }
      expect { @settings.to_catalog }.not_to raise_error
    end

    it "should ignore files whose :to_resource method returns nil" do
      @settings.define_settings :main, :maindir => { :type => :directory, :default => maindir, :desc => "a" }
      expect(@settings.setting(:maindir)).to receive(:to_resource).and_return(nil)

      expect_any_instance_of(Puppet::Resource::Catalog).not_to receive(:add_resource)
      @settings.to_catalog
    end

    describe "on Microsoft Windows", :if => Puppet::Util::Platform.windows? do
      before :each do
        allow(Puppet.features).to receive(:root?).and_return(true)

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

      it 'adds the creation of the production directory when not run as root' do
        envdir = "#{tmpenv}/custom_envpath"
        envpath = "#{envdir}#{File::PATH_SEPARATOR}/some/other/envdir"
        @settings[:environmentpath] = envpath
        Dir.mkdir(envdir)
        allow(Puppet.features).to receive(:root?).and_return(false)
        catalog = @settings.to_catalog
        resource = catalog.resource('File', File.join(envdir, 'production'))
        expect(resource[:mode]).to eq('0750')
        expect(resource[:owner]).to be_nil
        expect(resource[:group]).to be_nil
      end

      it 'adds the creation of the production directory with service owner and group information when available' do
        envdir = "#{tmpenv}/custom_envpath"
        envpath = "#{envdir}#{File::PATH_SEPARATOR}/some/other/envdir"
        @settings[:environmentpath] = envpath
        Dir.mkdir(envdir)
        allow(Puppet.features).to receive(:root?).and_return(true)
        allow(@settings).to receive(:service_user_available?).and_return(true)
        allow(@settings).to receive(:service_group_available?).and_return(true)
        catalog = @settings.to_catalog
        resource = catalog.resource('File', File.join(envdir, 'production'))
        expect(resource[:mode]).to eq('0750')
        expect(resource[:owner]).to eq('puppet')
        expect(resource[:group]).to eq('puppet')
      end

      it 'adds the creation of the production directory without service owner and group when not available' do
        envdir = "#{tmpenv}/custom_envpath"
        envpath = "#{envdir}#{File::PATH_SEPARATOR}/some/other/envdir"
        @settings[:environmentpath] = envpath
        Dir.mkdir(envdir)
        allow(Puppet.features).to receive(:root?).and_return(true)
        allow(@settings).to receive(:service_user_available?).and_return(false)
        allow(@settings).to receive(:service_group_available?).and_return(false)
        catalog = @settings.to_catalog
        resource = catalog.resource('File', File.join(envdir, 'production'))
        expect(resource[:mode]).to eq('0750')
        expect(resource[:owner]).to be_nil
        expect(resource[:group]).to be_nil
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
      before :all do
        # when this spec is run in isolation to build a settings catalog
        # it will not be able to autorequire and load types for the first time
        # on Windows with windows? stubbed to false, because
        # Puppet::Util.path_to_uri is called to generate a URI to load code
        # and it manipulates the path based on OS
        # so instead we forcefully "prime" the cached types
        Puppet::Type.type(:user).new(:name => 'foo')
        Puppet::Type.type(:group).new(:name => 'bar')
        Puppet::Type.type(:file).new(:name => Dir.pwd) # appropriate for OS
      end

      before do
        allow(Puppet.features).to receive(:root?).and_return(true)
        # stubbed to false, as Windows catalogs don't add users / groups
        allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)

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
        allow(Puppet.features).to receive(:root?).and_return(false)

        catalog = @settings.to_catalog
        expect(catalog.resource(:user, "suser")).to be_nil
        expect(catalog.resource(:group, "sgroup")).to be_nil
      end

      it "should not add users or groups to the catalog if :mkusers is not a valid setting" do
        allow(Puppet.features).to receive(:root?).and_return(true)
        settings = Puppet::Settings.new
        settings.define_settings :other, :otherdir => {:type => :directory, :default => "/otherdir", :desc => "a", :owner => "service", :group => "service"}

        catalog = settings.to_catalog
        expect(catalog.resource(:user, "suser")).to be_nil
        expect(catalog.resource(:group, "sgroup")).to be_nil
      end

      it "should not add users or groups to the catalog if :mkusers is a valid setting but is disabled" do
        @settings[:mkusers] = false
        allow(@settings).to receive(:service_user_available?).and_return(false)
        allow(@settings).to receive(:service_group_available?).and_return(false)

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
        allow(Puppet.features).to receive(:root?).and_return(true)
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

      main = double('main_resource', :ref => "File[/maindir]")
      expect(main).to receive(:to_manifest).and_return("maindir")
      expect(main).to receive(:'[]').with(:alias).and_return(nil)
      second = double('second_resource', :ref => "File[/seconddir]")
      expect(second).to receive(:to_manifest).and_return("seconddir")
      expect(second).to receive(:'[]').with(:alias).and_return(nil)

      expect(@settings.setting(:maindir)).to receive(:to_resource).and_return(main)
      expect(@settings.setting(:seconddir)).to receive(:to_resource).and_return(second)

      expect(@settings.to_manifest.split("\n\n").sort).to eq(%w{maindir seconddir})
    end
  end

  describe "when using sections of the configuration to manage the local host" do
    before do
      @settings = Puppet::Settings.new
      allow(@settings).to receive(:service_user_available?).and_return(true)
      allow(@settings).to receive(:service_group_available?).and_return(true)
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
      expect(@settings).to receive(:to_catalog).with(:main, :other).and_return(Puppet::Resource::Catalog.new("foo"))
      @settings.use(:main, :other)
    end

    it "should canonicalize the sections" do
      expect(@settings).to receive(:to_catalog).with(:main, :other).and_return(Puppet::Resource::Catalog.new("foo"))
      @settings.use("main", "other")
    end

    it "should ignore sections that have already been used" do
      expect(@settings).to receive(:to_catalog).with(:main).and_return(Puppet::Resource::Catalog.new("foo"))
      @settings.use(:main)
      expect(@settings).to receive(:to_catalog).with(:other).and_return(Puppet::Resource::Catalog.new("foo"))
      @settings.use(:main, :other)
    end

    it "should convert the created catalog to a RAL catalog" do
      @catalog = Puppet::Resource::Catalog.new("foo")
      expect(@settings).to receive(:to_catalog).with(:main).and_return(@catalog)

      expect(@catalog).to receive(:to_ral).and_return(@catalog)
      @settings.use(:main)
    end

    it "should specify that it is not managing a host catalog" do
      catalog = Puppet::Resource::Catalog.new("foo")
      expect(catalog).to receive(:apply)
      expect(@settings).to receive(:to_catalog).and_return(catalog)

      allow(catalog).to receive(:to_ral).and_return(catalog)

      expect(catalog).to receive(:host_config=).with(false)

      @settings.use(:main)
    end

    it "should support a method for re-using all currently used sections" do
      expect(@settings).to receive(:to_catalog).with(:main, :third).exactly(2).times.and_return(Puppet::Resource::Catalog.new("foo"))

      @settings.use(:main, :third)
      @settings.reuse
    end

    it "should fail with an appropriate message if any resources fail" do
      @catalog = Puppet::Resource::Catalog.new("foo")
      allow(@catalog).to receive(:to_ral).and_return(@catalog)
      expect(@settings).to receive(:to_catalog).and_return(@catalog)

      @trans = double("transaction")
      expect(@catalog).to receive(:apply).and_yield(@trans)

      expect(@trans).to receive(:any_failed?).and_return(true)

      resource = Puppet::Type.type(:notify).new(:title => 'failed')
      status = Puppet::Resource::Status.new(resource)
      event = Puppet::Transaction::Event.new(
        :name => 'failure',
        :status => 'failure',
        :message => 'My failure')
      status.add_event(event)

      report = Puppet::Transaction::Report.new('apply')
      report.add_resource_status(status)

      expect(@trans).to receive(:report).and_return(report)

      expect(@settings).to receive(:raise).with(/My failure/)
      @settings.use(:whatever)
    end
  end

  describe "when dealing with printing configs" do
    before do
      @settings = Puppet::Settings.new
      #these are the magic default values
      allow(@settings).to receive(:value).with(:configprint).and_return("")
      allow(@settings).to receive(:value).with(:genconfig).and_return(false)
      allow(@settings).to receive(:value).with(:genmanifest).and_return(false)
      allow(@settings).to receive(:value).with(:environment).and_return(nil)
    end

    describe "when checking print_config?" do
      it "should return false when the :configprint, :genconfig and :genmanifest are not set" do
        expect(@settings.print_configs?).to be_falsey
      end

      it "should return true when :configprint has a value" do
        allow(@settings).to receive(:value).with(:configprint).and_return("something")
        expect(@settings.print_configs?).to be_truthy
      end

      it "should return true when :genconfig has a value" do
        allow(@settings).to receive(:value).with(:genconfig).and_return(true)
        expect(@settings.print_configs?).to be_truthy
      end

      it "should return true when :genmanifest has a value" do
        allow(@settings).to receive(:value).with(:genmanifest).and_return(true)
        expect(@settings.print_configs?).to be_truthy
      end
    end

    describe "when printing configs" do
      describe "when :configprint has a value" do
        it "should call print_config_options" do
          allow(@settings).to receive(:value).with(:configprint).and_return("something")
          expect(@settings).to receive(:print_config_options)
          @settings.print_configs
        end

        it "should get the value of the option using the environment" do
          allow(@settings).to receive(:value).with(:configprint).and_return("something")
          allow(@settings).to receive(:include?).with("something").and_return(true)
          expect(@settings).to receive(:value).with(:environment).and_return("env")
          expect(@settings).to receive(:value).with("something", "env").and_return("foo")
          allow(@settings).to receive(:puts).with("foo")
          @settings.print_configs
        end

        it "should print the value of the option" do
          allow(@settings).to receive(:value).with(:configprint).and_return("something")
          allow(@settings).to receive(:include?).with("something").and_return(true)
          allow(@settings).to receive(:value).with("something", nil).and_return("foo")
          expect(@settings).to receive(:puts).with("foo")
          @settings.print_configs
        end

        it "should print the value pairs if there are multiple options" do
          allow(@settings).to receive(:value).with(:configprint).and_return("bar,baz")
          allow(@settings).to receive(:include?).with("bar").and_return(true)
          allow(@settings).to receive(:include?).with("baz").and_return(true)
          allow(@settings).to receive(:value).with("bar", nil).and_return("foo")
          allow(@settings).to receive(:value).with("baz", nil).and_return("fud")
          expect(@settings).to receive(:puts).with("bar = foo")
          expect(@settings).to receive(:puts).with("baz = fud")
          @settings.print_configs
        end

        it "should return true after printing" do
          allow(@settings).to receive(:value).with(:configprint).and_return("something")
          allow(@settings).to receive(:include?).with("something").and_return(true)
          allow(@settings).to receive(:value).with("something", nil).and_return("foo")
          allow(@settings).to receive(:puts).with("foo")
          expect(@settings.print_configs).to be_truthy
        end

        it "should return false if a config param is not found" do
          allow(@settings).to receive(:puts)
          allow(@settings).to receive(:value).with(:configprint).and_return("something")
          allow(@settings).to receive(:include?).with("something").and_return(false)
          expect(@settings.print_configs).to be_falsey
        end
      end

      describe "when genconfig is true" do
        before do
          allow(@settings).to receive(:puts)
        end

        it "should call to_config" do
          allow(@settings).to receive(:value).with(:genconfig).and_return(true)
          expect(@settings).to receive(:to_config)
          @settings.print_configs
        end

        it "should return true from print_configs" do
          allow(@settings).to receive(:value).with(:genconfig).and_return(true)
          allow(@settings).to receive(:to_config)
          expect(@settings.print_configs).to be_truthy
        end
      end

      describe "when genmanifest is true" do
        before do
          allow(@settings).to receive(:puts)
        end

        it "should call to_config" do
          allow(@settings).to receive(:value).with(:genmanifest).and_return(true)
          expect(@settings).to receive(:to_manifest)
          @settings.print_configs
        end

        it "should return true from print_configs" do
          allow(@settings).to receive(:value).with(:genmanifest).and_return(true)
          allow(@settings).to receive(:to_manifest)
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
      user = double('user')
      expect(Puppet::Type.type(:user)).to receive(:new).with(hash_including(name: username)).and_return(user)
      user
    end

    it "should return false if there is no user setting" do
      expect(settings).not_to be_service_user_available
    end

    it "should return false if the user provider says the user is missing" do
      settings[:user] = "foo"

      expect(a_user_type_for("foo")).to receive(:exists?).and_return(false)

      expect(settings).not_to be_service_user_available
    end

    it "should return true if the user provider says the user is present" do
      settings[:user] = "foo"

      expect(a_user_type_for("foo")).to receive(:exists?).and_return(true)

      expect(settings).to be_service_user_available
    end

    it "caches the result of determining if the user is present" do
      settings[:user] = "foo"

      expect(a_user_type_for("foo")).to receive(:exists?).and_return(true)
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
      group = double('group')
      expect(Puppet::Type.type(:group)).to receive(:new).with(hash_including(name: groupname)).and_return(group)
      group
    end

    it "should return false if there is no group setting" do
      expect(settings).not_to be_service_group_available
    end

    it "should return false if the group provider says the group is missing" do
      settings[:group] = "foo"

      expect(a_group_type_for("foo")).to receive(:exists?).and_return(false)

      expect(settings).not_to be_service_group_available
    end

    it "should return true if the group provider says the group is present" do
      settings[:group] = "foo"

      expect(a_group_type_for("foo")).to receive(:exists?).and_return(true)

      expect(settings).to be_service_group_available
    end

    it "caches the result of determining if the group is present" do
      settings[:group] = "foo"

      expect(a_group_type_for("foo")).to receive(:exists?).and_return(true)
      expect(settings).to be_service_group_available

      expect(settings).to be_service_group_available
    end
  end

  describe "when dealing with command-line options" do
    let(:settings) { Puppet::Settings.new }

    it "should get options from Puppet.settings.optparse_addargs" do
      expect(settings).to receive(:optparse_addargs).and_return([])

      settings.send(:parse_global_options, [])
    end

    it "should add options to OptionParser" do
      allow(settings).to receive(:optparse_addargs).and_return([["--option","-o", "Funny Option", :NONE]])
      expect(settings).to receive(:handlearg).with("--option", true)
      settings.send(:parse_global_options, ["--option"])
    end

    it "should not die if it sees an unrecognized option, because the app/face may handle it later" do
      expect { settings.send(:parse_global_options, ["--topuppet", "value"]) } .to_not raise_error
    end

    it "should not pass an unrecognized option to handleargs" do
      expect(settings).not_to receive(:handlearg).with("--topuppet", "value")
      expect { settings.send(:parse_global_options, ["--topuppet", "value"]) } .to_not raise_error
    end

    it "should pass valid puppet settings options to handlearg even if they appear after an unrecognized option" do
      allow(settings).to receive(:optparse_addargs).and_return([["--option","-o", "Funny Option", :NONE]])
      expect(settings).to receive(:handlearg).with("--option", true)
      settings.send(:parse_global_options, ["--invalidoption", "--option"])
    end

    it "should transform boolean option to normal form" do
      expect(Puppet::Settings.clean_opt("--[no-]option", true)).to eq(["--option", true])
    end

    it "should transform boolean option to no- form" do
      expect(Puppet::Settings.clean_opt("--[no-]option", false)).to eq(["--no-option", false])
    end

    it "should set preferred run mode from --run_mode <foo> string without error" do
      args = ["--run_mode", "server"]
      expect(settings).not_to receive(:handlearg).with("--run_mode", "server")
      expect { settings.send(:parse_global_options, args) } .to_not raise_error
      expect(Puppet.settings.preferred_run_mode).to eq(:server)
      expect(args.empty?).to eq(true)
    end

    it "should set preferred run mode from --run_mode=<foo> string without error" do
      args = ["--run_mode=server"]
      expect(settings).not_to receive(:handlearg).with("--run_mode", "server")
      expect { settings.send(:parse_global_options, args) }.to_not raise_error
      expect(Puppet.settings.preferred_run_mode).to eq(:server)
      expect(args.empty?).to eq(true)
    end
  end

  describe "default_certname" do
    describe "using hostname and domain" do
      before :each do
        allow(Puppet::Settings).to receive(:hostname_fact).and_return("testhostname")
        allow(Puppet::Settings).to receive(:domain_fact).and_return("domain.test.")
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
        allow(Puppet::Settings).to receive(:hostname_fact).and_return("testhostname")
        allow(Puppet::Settings).to receive(:domain_fact).and_return("")
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
