require 'spec_helper'

require 'puppet/application'
require 'puppet'
require 'getoptlong'
require 'timeout'

describe Puppet::Application do
  before(:each) do
    @app = Class.new(Puppet::Application).new
    @appclass = @app.class

    allow(@app).to receive(:name).and_return("test_app")
  end

  describe "application commandline" do
    it "should not pick up changes to the array of arguments" do
      args = %w{subcommand --arg}
      command_line = Puppet::Util::CommandLine.new('puppet', args)
      app = Puppet::Application.new(command_line)

      args[0] = 'different_subcommand'
      args[1] = '--other-arg'

      expect(app.command_line.subcommand_name).to eq('subcommand')
      expect(app.command_line.args).to eq(['--arg'])
    end
  end

  describe "application defaults" do
    it "should fail if required app default values are missing" do
      allow(@app).to receive(:app_defaults).and_return({ :foo => 'bar' })
      expect(Puppet).to receive(:send_log).with(:err, /missing required app default setting/)
      expect {
        @app.run
      }.to exit_with(1)
    end
  end

  describe "finding" do
    before do
      @klass = Puppet::Application
      allow(@klass).to receive(:puts)
    end

    it "should find classes in the namespace" do
      expect(@klass.find("Agent")).to eq(@klass::Agent)
    end

    it "should not find classes outside the namespace" do
      expect { @klass.find("String") }.to raise_error(LoadError)
    end

    it "should error if it can't find a class" do
      expect(Puppet).to receive(:send_log) do |_level, message|
        expect(message).to match(/Unable to find application 'ThisShallNeverEverEverExist'/)
        expect(message).to match(/puppet\/application\/thisshallneverevereverexist/)
        expect(message).to match(/no such file to load|cannot load such file/)
      end

      expect {
        @klass.find("ThisShallNeverEverEverExist")
      }.to raise_error(LoadError)
    end
  end

  describe "#available_application_names" do
    it 'should be able to find available application names' do
      apps =  %w{describe filebucket kick queue resource agent cert apply doc master}
      expect(Puppet::Util::Autoload).to receive(:files_to_load).and_return(apps)

      expect(Puppet::Application.available_application_names).to match_array(apps)
    end

    it 'should find applications from multiple paths' do
      expect(Puppet::Util::Autoload).to receive(:files_to_load).with(
        'puppet/application',
        be_a(Puppet::Node::Environment)
      ).and_return(%w{ /a/foo.rb /b/bar.rb })

      expect(Puppet::Application.available_application_names).to match_array(%w{ foo bar })
    end

    it 'should return unique application names' do
      expect(Puppet::Util::Autoload).to receive(:files_to_load).with(
        'puppet/application',
        be_a(Puppet::Node::Environment)
      ).and_return(%w{ /a/foo.rb /b/foo.rb })

      expect(Puppet::Application.available_application_names).to eq(%w{ foo })
    end

    it 'finds the application using the configured environment' do
      Puppet[:environment] = 'production'
      expect(Puppet::Util::Autoload).to receive(:files_to_load) do |_, env|
        expect(env.name).to eq(:production)
      end.and_return(%w{ /a/foo.rb })

      expect(Puppet::Application.available_application_names).to eq(%w{ foo })
    end

    it "falls back to the current environment if the configured environment doesn't exist" do
      Puppet[:environment] = 'doesnotexist'
      expect(Puppet::Util::Autoload).to receive(:files_to_load) do |_, env|
        expect(env.name).to eq(:'*root*')
      end.and_return(%w[a/foo.rb])

      expect(Puppet::Application.available_application_names).to eq(%w[foo])
    end
  end

  describe ".run_mode" do
    it "should default to user" do
      expect(@appclass.run_mode.name).to eq(:user)
    end

    it "should set and get a value" do
      @appclass.run_mode :agent
      expect(@appclass.run_mode.name).to eq(:agent)
    end

    it "considers :server to be master" do
      @appclass.run_mode :server
      expect(@appclass.run_mode).to be_master
    end
  end

  describe ".environment_mode" do
    it "should default to :local" do
      expect(@appclass.get_environment_mode).to eq(:local)
    end

    it "should set and get a value" do
      @appclass.environment_mode :remote
      expect(@appclass.get_environment_mode).to eq(:remote)
    end

    it "should error if given a random symbol" do
      expect{@appclass.environment_mode :foo}.to raise_error(/Invalid environment mode/)
    end

    it "should error if given a string" do
      expect{@appclass.environment_mode 'local'}.to raise_error(/Invalid environment mode/)
    end
  end


  # These tests may look a little weird and repetative in its current state;
  #  it used to illustrate several ways that the run_mode could be changed
  #  at run time; there are fewer ways now, but it would still be nice to
  #  get to a point where it was entirely impossible.
  describe "when dealing with run_mode" do

    class TestApp < Puppet::Application
      run_mode :server
      def run_command
        # no-op
      end
    end

    it "should sadly and frighteningly allow run_mode to change at runtime via #initialize_app_defaults" do
      allow(Puppet.features).to receive(:syslog?).and_return(true)

      app = TestApp.new
      app.initialize_app_defaults

      expect(Puppet.run_mode).to be_server
    end

    it "should sadly and frighteningly allow run_mode to change at runtime via #run" do
      app = TestApp.new
      app.run

      expect(app.class.run_mode.name).to eq(:server)

      expect(Puppet.run_mode).to be_server
    end
  end

  it "should explode when an invalid run mode is set at runtime, for great victory" do
    expect {
      class InvalidRunModeTestApp < Puppet::Application
        run_mode :abracadabra
        def run_command
          # no-op
        end
      end
    }.to raise_error(Puppet::Settings::ValidationError, /Invalid run mode/)
  end

  it "should have a run entry-point" do
    expect(@app).to respond_to(:run)
  end

  it "should have a read accessor to options" do
    expect(@app).to respond_to(:options)
  end

  it "should include a default setup method" do
    expect(@app).to respond_to(:setup)
  end

  it "should include a default preinit method" do
    expect(@app).to respond_to(:preinit)
  end

  it "should include a default run_command method" do
    expect(@app).to respond_to(:run_command)
  end

  it "should invoke main as the default" do
    expect(@app).to receive(:main)
    @app.run_command
  end

  describe 'when invoking clear!' do
    before :each do
      Puppet::Application.run_status = :stop_requested
      Puppet::Application.clear!
    end

    it 'should have nil run_status' do
      expect(Puppet::Application.run_status).to be_nil
    end

    it 'should return false for restart_requested?' do
      expect(Puppet::Application.restart_requested?).to be_falsey
    end

    it 'should return false for stop_requested?' do
      expect(Puppet::Application.stop_requested?).to be_falsey
    end

    it 'should return false for interrupted?' do
      expect(Puppet::Application.interrupted?).to be_falsey
    end

    it 'should return true for clear?' do
      expect(Puppet::Application.clear?).to be_truthy
    end
  end

  describe 'after invoking stop!' do
    before :each do
      Puppet::Application.run_status = nil
      Puppet::Application.stop!
    end

    after :each do
      Puppet::Application.run_status = nil
    end

    it 'should have run_status of :stop_requested' do
      expect(Puppet::Application.run_status).to eq(:stop_requested)
    end

    it 'should return true for stop_requested?' do
      expect(Puppet::Application.stop_requested?).to be_truthy
    end

    it 'should return false for restart_requested?' do
      expect(Puppet::Application.restart_requested?).to be_falsey
    end

    it 'should return true for interrupted?' do
      expect(Puppet::Application.interrupted?).to be_truthy
    end

    it 'should return false for clear?' do
      expect(Puppet::Application.clear?).to be_falsey
    end
  end

  describe 'when invoking restart!' do
    before :each do
      Puppet::Application.run_status = nil
      Puppet::Application.restart!
    end

    after :each do
      Puppet::Application.run_status = nil
    end

    it 'should have run_status of :restart_requested' do
      expect(Puppet::Application.run_status).to eq(:restart_requested)
    end

    it 'should return true for restart_requested?' do
      expect(Puppet::Application.restart_requested?).to be_truthy
    end

    it 'should return false for stop_requested?' do
      expect(Puppet::Application.stop_requested?).to be_falsey
    end

    it 'should return true for interrupted?' do
      expect(Puppet::Application.interrupted?).to be_truthy
    end

    it 'should return false for clear?' do
      expect(Puppet::Application.clear?).to be_falsey
    end
  end

  describe 'when performing a controlled_run' do
    it 'should not execute block if not :clear?' do
      Puppet::Application.run_status = :stop_requested
      target = double('target')
      expect(target).not_to receive(:some_method)
      Puppet::Application.controlled_run do
        target.some_method
      end
    end

    it 'should execute block if :clear?' do
      Puppet::Application.run_status = nil
      target = double('target')
      expect(target).to receive(:some_method).once
      Puppet::Application.controlled_run do
        target.some_method
      end
    end

    describe 'on POSIX systems', :if => (Puppet.features.posix? && RUBY_PLATFORM != 'java') do
      it 'should signal process with HUP after block if restart requested during block execution' do
        Timeout::timeout(3) do  # if the signal doesn't fire, this causes failure.

          has_run = false
          old_handler = trap('HUP') { has_run = true }

          begin
            Puppet::Application.controlled_run do
              Puppet::Application.run_status = :restart_requested
            end

            # Ruby 1.9 uses a separate OS level thread to run the signal
            # handler, so we have to poll - ideally, in a way that will kick
            # the OS into running other threads - for a while.
            #
            # You can't just use the Ruby Thread yield thing either, because
            # that is just an OS hint, and Linux ... doesn't take that
            # seriously. --daniel 2012-03-22
            sleep 0.001 while not has_run
          ensure
            trap('HUP', old_handler)
          end
        end
      end
    end

    after :each do
      Puppet::Application.run_status = nil
    end
  end

  describe "when parsing command-line options" do
    before :each do
      allow(@app.command_line).to receive(:args).and_return([])

      allow(Puppet.settings).to receive(:optparse_addargs).and_return([])
    end

    it "should pass the banner to the option parser" do
      option_parser = double("option parser")
      allow(option_parser).to receive(:on)
      allow(option_parser).to receive(:parse!)
      @app.class.instance_eval do
        banner "banner"
      end

      expect(OptionParser).to receive(:new).with("banner").and_return(option_parser)

      @app.parse_options
    end

    it "should ask OptionParser to parse the command-line argument" do
      allow(@app.command_line).to receive(:args).and_return(%w{ fake args })
      expect_any_instance_of(OptionParser).to receive(:parse!).with(%w{ fake args })

      @app.parse_options
    end

    describe "when using --help" do
      it "should call exit" do
        allow(@app).to receive(:puts)
        expect { @app.handle_help(nil) }.to exit_with 0
      end
    end

    describe "when using --version" do
      it "should declare a version option" do
        expect(@app).to respond_to(:handle_version)
      end

      it "should exit after printing the version" do
        allow(@app).to receive(:puts)
        expect { @app.handle_version(nil) }.to exit_with 0
      end
    end

    describe "when dealing with an argument not declared directly by the application" do
      it "should pass it to handle_unknown if this method exists" do
        allow(Puppet.settings).to receive(:optparse_addargs).and_return([["--not-handled", :REQUIRED]])

        expect(@app).to receive(:handle_unknown).with("--not-handled", "value").and_return(true)
        allow(@app.command_line).to receive(:args).and_return(["--not-handled", "value"])
        @app.parse_options
      end

      it "should transform boolean option to normal form for Puppet.settings" do
        expect(@app).to receive(:handle_unknown).with("--option", true)
        @app.send(:handlearg, "--[no-]option", true)
      end

      it "should transform boolean option to no- form for Puppet.settings" do
        expect(@app).to receive(:handle_unknown).with("--no-option", false)
        @app.send(:handlearg, "--[no-]option", false)
      end
    end
  end

  describe "when calling default setup" do
    before :each do
      allow(@app.options).to receive(:[])
    end

    [ :debug, :verbose ].each do |level|
      it "should honor option #{level}" do
        allow(@app.options).to receive(:[]).with(level).and_return(true)
        allow(Puppet::Util::Log).to receive(:newdestination)
        @app.setup
        expect(Puppet::Util::Log.level).to eq(level == :verbose ? :info : :debug)
      end
    end

    it "should honor setdest option" do
      allow(@app.options).to receive(:[]).with(:setdest).and_return(false)

      expect(Puppet::Util::Log).to receive(:setup_default)

      @app.setup
    end

    it "sets the log destination if provided via settings" do
      allow(@app.options).to receive(:[]).and_call_original
      Puppet[:logdest] = "set_via_config"
      expect(Puppet::Util::Log).to receive(:newdestination).with("set_via_config")

      @app.setup
    end

    it "does not downgrade the loglevel when --verbose is specified" do
      Puppet[:log_level] = :debug
      allow(@app.options).to receive(:[]).with(:verbose).and_return(true)
      @app.setup_logs

      expect(Puppet::Util::Log.level).to eq(:debug)
    end

    it "allows the loglevel to be specified as an argument" do
      @app.set_log_level(:debug => true)

      expect(Puppet::Util::Log.level).to eq(:debug)
    end
  end

  describe "when configuring routes" do
    include PuppetSpec::Files

    before :each do
      Puppet::Node.indirection.reset_terminus_class
    end

    after :each do
      Puppet::Node.indirection.reset_terminus_class
    end

    it "should use the routes specified for only the active application" do
      Puppet[:route_file] = tmpfile('routes')
      File.open(Puppet[:route_file], 'w') do |f|
        f.print <<-ROUTES
          test_app:
            node:
              terminus: exec
          other_app:
            node:
              terminus: plain
            catalog:
              terminus: invalid
        ROUTES
      end

      @app.configure_indirector_routes

      expect(Puppet::Node.indirection.terminus_class).to eq('exec')
    end

    it "should not fail if the route file doesn't exist" do
      Puppet[:route_file] = "/dev/null/non-existent"

      expect { @app.configure_indirector_routes }.to_not raise_error
    end

    it "should raise an error if the routes file is invalid" do
      Puppet[:route_file] = tmpfile('routes')
      File.open(Puppet[:route_file], 'w') do |f|
        f.print <<-ROUTES
         invalid : : yaml
        ROUTES
      end

      expect { @app.configure_indirector_routes }.to raise_error(Puppet::Error, /mapping values are not allowed/)
    end

    it "should treat master routes on server application" do
      allow(@app).to receive(:name).and_return("server")

      Puppet[:route_file] = tmpfile('routes')
      File.open(Puppet[:route_file], 'w') do |f|
        f.print <<-ROUTES
          master:
            node:
              terminus: exec
        ROUTES
      end

      @app.configure_indirector_routes

      expect(Puppet::Node.indirection.terminus_class).to eq('exec')
    end

    it "should treat server routes on master application" do
      allow(@app).to receive(:name).and_return("master")

      Puppet[:route_file] = tmpfile('routes')
      File.open(Puppet[:route_file], 'w') do |f|
        f.print <<-ROUTES
          server:
            node:
              terminus: exec
        ROUTES
      end

      @app.configure_indirector_routes

      expect(Puppet::Node.indirection.terminus_class).to eq('exec')
    end
  end

  describe "when running" do
    before :each do
      allow(@app).to receive(:preinit)
      allow(@app).to receive(:setup)
      allow(@app).to receive(:parse_options)
    end

    it "should call preinit" do
      allow(@app).to receive(:run_command)

      expect(@app).to receive(:preinit)

      @app.run
    end

    it "should call parse_options" do
      allow(@app).to receive(:run_command)

      expect(@app).to receive(:parse_options)

      @app.run
    end

    it "should call run_command" do
      expect(@app).to receive(:run_command)

      @app.run
    end

    it "should call run_command" do
      expect(@app).to receive(:run_command)

      @app.run
    end

    it "should call main as the default command" do
      expect(@app).to receive(:main)

      @app.run
    end

    it "should warn and exit if no command can be called" do
      expect(Puppet).to receive(:send_log).with(:err, "Could not run: No valid command or main")
      expect { @app.run }.to exit_with 1
    end

    it "should raise an error if dispatch returns no command" do
      allow(@app).to receive(:get_command).and_return(nil)
      expect(Puppet).to receive(:send_log).with(:err, "Could not run: No valid command or main")
      expect { @app.run }.to exit_with 1
    end

    it "should raise an error if dispatch returns an invalid command" do
      allow(@app).to receive(:get_command).and_return(:this_function_doesnt_exist)
      expect(Puppet).to receive(:send_log).with(:err, "Could not run: No valid command or main")
      expect { @app.run }.to exit_with 1
    end
  end

  describe "when metaprogramming" do
    describe "when calling option" do
      it "should create a new method named after the option" do
        @app.class.option("--test1","-t") do
        end

        expect(@app).to respond_to(:handle_test1)
      end

      it "should transpose in option name any '-' into '_'" do
        @app.class.option("--test-dashes-again","-t") do
        end

        expect(@app).to respond_to(:handle_test_dashes_again)
      end

      it "should create a new method called handle_test2 with option(\"--[no-]test2\")" do
        @app.class.option("--[no-]test2","-t") do
        end

        expect(@app).to respond_to(:handle_test2)
      end

      describe "when a block is passed" do
        it "should create a new method with it" do
          @app.class.option("--[no-]test2","-t") do
            raise "I can't believe it, it works!"
          end

          expect { @app.handle_test2 }.to raise_error(RuntimeError, /I can't believe it, it works!/)
        end

        it "should declare the option to OptionParser" do
          allow_any_instance_of(OptionParser).to receive(:on)
          expect_any_instance_of(OptionParser).to receive(:on).with("--[no-]test3", anything)

          @app.class.option("--[no-]test3","-t") do
          end

          @app.parse_options
        end

        it "should pass a block that calls our defined method" do
          allow_any_instance_of(OptionParser).to receive(:on)
          allow_any_instance_of(OptionParser).to receive(:on).with('--test4', '-t').and_yield(nil)

          expect(@app).to receive(:send).with(:handle_test4, nil)

          @app.class.option("--test4","-t") do
          end

          @app.parse_options
        end
      end

      describe "when no block is given" do
        it "should declare the option to OptionParser" do
          allow_any_instance_of(OptionParser).to receive(:on)
          expect_any_instance_of(OptionParser).to receive(:on).with("--test4", "-t")

          @app.class.option("--test4","-t")

          @app.parse_options
        end

        it "should give to OptionParser a block that adds the value to the options array" do
          allow_any_instance_of(OptionParser).to receive(:on)
          allow_any_instance_of(OptionParser).to receive(:on).with("--test4", "-t").and_yield(nil)

          expect(@app.options).to receive(:[]=).with(:test4, nil)

          @app.class.option("--test4","-t")

          @app.parse_options
        end
      end
    end
  end

  describe "#handle_logdest_arg" do
    let(:test_arg) { "arg_test_logdest" }

    it "should log an exception that is raised" do
      our_exception = Puppet::DevError.new("test exception")
      expect(Puppet::Util::Log).to receive(:newdestination).with(test_arg).and_raise(our_exception)
      expect(Puppet).to receive(:log_and_raise).with(our_exception, anything)
      @app.handle_logdest_arg(test_arg)
    end

    it "should exit when an exception is raised" do
      our_exception = Puppet::DevError.new("test exception")
      expect(Puppet::Util::Log).to receive(:newdestination).with(test_arg).and_raise(our_exception)
      expect(Puppet).to receive(:log_and_raise).with(our_exception, anything).and_raise(our_exception)
      expect { @app.handle_logdest_arg(test_arg) }.to raise_error(Puppet::DevError)
    end

    it "should set the new log destination" do
      expect(Puppet::Util::Log).to receive(:newdestination).with(test_arg)
      @app.handle_logdest_arg(test_arg)
    end

    it "should set the flag that a destination is set in the options hash" do
      allow(Puppet::Util::Log).to receive(:newdestination).with(test_arg)
      @app.handle_logdest_arg(test_arg)
      expect(@app.options[:setdest]).to be_truthy
    end

    it "does not set the log destination if arg is nil" do
      expect(Puppet::Util::Log).not_to receive(:newdestination)

      @app.handle_logdest_arg(nil)
    end
  end
end
