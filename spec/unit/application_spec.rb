#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/application'
require 'puppet'
require 'getoptlong'

describe Puppet::Application do

  before do
    @app = Class.new(Puppet::Application).new
    @appclass = @app.class

    @app.stubs(:name).returns("test_app")
    # avoid actually trying to parse any settings
    Puppet.settings.stubs(:parse)
  end

  describe "finding" do
    before do
      @klass = Puppet::Application
      @klass.stubs(:puts)
    end

    it "should find classes in the namespace" do
      @klass.find("Agent").should == @klass::Agent
    end

    it "should not find classes outside the namespace", :'fails_on_ruby_1.9.2' => true do
      expect { @klass.find("String") }.to exit_with 1
    end

    it "should exit if it can't find a class" do
      expect { @klass.find("ThisShallNeverEverEverExist") }.to exit_with 1
    end
  end

  describe ".run_mode" do
    it "should default to user" do
      @appclass.run_mode.name.should == :user
    end

    it "should set and get a value" do
      @appclass.run_mode :agent
      @appclass.run_mode.name.should == :agent
    end
  end

  it "should sadly and frighteningly allow run_mode to change at runtime" do
    class TestApp < Puppet::Application
      run_mode :master
      def run_command
        # This is equivalent to calling these methods externally to the
        # instance, but since this is what "real world" code is likely to do
        # (and we need the class anyway) we may as well test that. --daniel 2011-02-03
        set_run_mode self.class.run_mode "agent"
      end
    end

    Puppet[:run_mode].should == "user"

    expect {
      app = TestApp.new

      Puppet[:run_mode].should == "master"

      app.run

      app.class.run_mode.name.should == :agent
      $puppet_application_mode.name.should == :agent
    }.should_not raise_error

    Puppet[:run_mode].should == "agent"
  end

  it "it should not allow run mode to be set multiple times" do
    pending "great floods of tears, you can do this right now" # --daniel 2011-02-03
    app = Puppet::Application.new
    expect {
      app.set_run_mode app.class.run_mode "master"
      $puppet_application_mode.name.should == :master
      app.set_run_mode app.class.run_mode "agent"
      $puppet_application_mode.name.should == :agent
    }.should raise_error
  end

  it "should explode when an invalid run mode is set at runtime, for great victory"
  # ...but you can, and while it will explode, that only happens too late for
  # us to easily test. --daniel 2011-02-03

  it "should have a run entry-point" do
    @app.should respond_to(:run)
  end

  it "should have a read accessor to options" do
    @app.should respond_to(:options)
  end

  it "should include a default setup method" do
    @app.should respond_to(:setup)
  end

  it "should include a default preinit method" do
    @app.should respond_to(:preinit)
  end

  it "should include a default run_command method" do
    @app.should respond_to(:run_command)
  end

  it "should invoke main as the default" do
    @app.expects( :main )
    @app.run_command
  end

  describe 'when invoking clear!' do
    before :each do
      Puppet::Application.run_status = :stop_requested
      Puppet::Application.clear!
    end

    it 'should have nil run_status' do
      Puppet::Application.run_status.should be_nil
    end

    it 'should return false for restart_requested?' do
      Puppet::Application.restart_requested?.should be_false
    end

    it 'should return false for stop_requested?' do
      Puppet::Application.stop_requested?.should be_false
    end

    it 'should return false for interrupted?' do
      Puppet::Application.interrupted?.should be_false
    end

    it 'should return true for clear?' do
      Puppet::Application.clear?.should be_true
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
      Puppet::Application.run_status.should == :stop_requested
    end

    it 'should return true for stop_requested?' do
      Puppet::Application.stop_requested?.should be_true
    end

    it 'should return false for restart_requested?' do
      Puppet::Application.restart_requested?.should be_false
    end

    it 'should return true for interrupted?' do
      Puppet::Application.interrupted?.should be_true
    end

    it 'should return false for clear?' do
      Puppet::Application.clear?.should be_false
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
      Puppet::Application.run_status.should == :restart_requested
    end

    it 'should return true for restart_requested?' do
      Puppet::Application.restart_requested?.should be_true
    end

    it 'should return false for stop_requested?' do
      Puppet::Application.stop_requested?.should be_false
    end

    it 'should return true for interrupted?' do
      Puppet::Application.interrupted?.should be_true
    end

    it 'should return false for clear?' do
      Puppet::Application.clear?.should be_false
    end
  end

  describe 'when performing a controlled_run' do
    it 'should not execute block if not :clear?' do
      Puppet::Application.run_status = :stop_requested
      target = mock 'target'
      target.expects(:some_method).never
      Puppet::Application.controlled_run do
        target.some_method
      end
    end

    it 'should execute block if :clear?' do
      Puppet::Application.run_status = nil
      target = mock 'target'
      target.expects(:some_method).once
      Puppet::Application.controlled_run do
        target.some_method
      end
    end

    describe 'on POSIX systems', :if => Puppet.features.posix? do
      it 'should signal process with HUP after block if restart requested during block execution', :'fails_on_ruby_1.9.2' => true do
        Puppet::Application.run_status = nil
        target = mock 'target'
        target.expects(:some_method).once
        old_handler = trap('HUP') { target.some_method }
        begin
          Puppet::Application.controlled_run do
            Puppet::Application.run_status = :restart_requested
          end
        ensure
          trap('HUP', old_handler)
        end
      end
    end

    after :each do
      Puppet::Application.run_status = nil
    end
  end

  describe "when parsing command-line options" do

    before :each do
      @app.command_line.stubs(:args).returns([])

      Puppet.settings.stubs(:optparse_addargs).returns([])
    end

    it "should pass the banner to the option parser" do
      option_parser = stub "option parser"
      option_parser.stubs(:on)
      option_parser.stubs(:parse!)
      @app.class.instance_eval do
        banner "banner"
      end

      OptionParser.expects(:new).with("banner").returns(option_parser)

      @app.parse_options
    end

    it "should get options from Puppet.settings.optparse_addargs" do
      Puppet.settings.expects(:optparse_addargs).returns([])

      @app.parse_options
    end

    it "should add Puppet.settings options to OptionParser" do
      Puppet.settings.stubs(:optparse_addargs).returns( [["--option","-o", "Funny Option"]])
      Puppet.settings.expects(:handlearg).with("--option", 'true')
      @app.command_line.stubs(:args).returns(["--option"])
      @app.parse_options
    end

    it "should ask OptionParser to parse the command-line argument" do
      @app.command_line.stubs(:args).returns(%w{ fake args })
      OptionParser.any_instance.expects(:parse!).with(%w{ fake args })

      @app.parse_options
    end

    describe "when using --help" do

      it "should call exit" do
        @app.stubs(:puts)
        expect { @app.handle_help(nil) }.to exit_with 0
      end

    end

    describe "when using --version" do
      it "should declare a version option" do
        @app.should respond_to(:handle_version)
      end

      it "should exit after printing the version" do
        @app.stubs(:puts)
        expect { @app.handle_version(nil) }.to exit_with 0
      end
    end

    describe "when dealing with an argument not declared directly by the application" do
      it "should pass it to handle_unknown if this method exists" do
        Puppet.settings.stubs(:optparse_addargs).returns([["--not-handled", :REQUIRED]])

        @app.expects(:handle_unknown).with("--not-handled", "value").returns(true)
        @app.command_line.stubs(:args).returns(["--not-handled", "value"])
        @app.parse_options
      end

      it "should pass it to Puppet.settings if handle_unknown says so" do
        Puppet.settings.stubs(:optparse_addargs).returns([["--topuppet", :REQUIRED]])

        @app.stubs(:handle_unknown).with("--topuppet", "value").returns(false)

        Puppet.settings.expects(:handlearg).with("--topuppet", "value")
        @app.command_line.stubs(:args).returns(["--topuppet", "value"])
        @app.parse_options
      end

      it "should pass it to Puppet.settings if there is no handle_unknown method" do
        Puppet.settings.stubs(:optparse_addargs).returns([["--topuppet", :REQUIRED]])

        @app.stubs(:respond_to?).returns(false)

        Puppet.settings.expects(:handlearg).with("--topuppet", "value")
        @app.command_line.stubs(:args).returns(["--topuppet", "value"])
        @app.parse_options
      end

      it "should transform boolean false value to string for Puppet.settings" do
        Puppet.settings.expects(:handlearg).with("--option", "false")
        @app.handlearg("--option", false)
      end

      it "should transform boolean true value to string for Puppet.settings" do
        Puppet.settings.expects(:handlearg).with("--option", "true")
        @app.handlearg("--option", true)
      end

      it "should transform boolean option to normal form for Puppet.settings" do
        Puppet.settings.expects(:handlearg).with("--option", "true")
        @app.handlearg("--[no-]option", true)
      end

      it "should transform boolean option to no- form for Puppet.settings" do
        Puppet.settings.expects(:handlearg).with("--no-option", "false")
        @app.handlearg("--[no-]option", false)
      end

    end
  end

  describe "when calling default setup" do

    before :each do
      @app.stubs(:should_parse_config?).returns(false)
      @app.options.stubs(:[])
    end

    [ :debug, :verbose ].each do |level|
      it "should honor option #{level}" do
        @app.options.stubs(:[]).with(level).returns(true)
        Puppet::Util::Log.stubs(:newdestination)
        @app.setup
        Puppet::Util::Log.level.should == (level == :verbose ? :info : :debug)
      end
    end

    it "should honor setdest option" do
      @app.options.stubs(:[]).with(:setdest).returns(false)

      Puppet::Util::Log.expects(:newdestination).with(:syslog)

      @app.setup
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

      Puppet::Node.indirection.terminus_class.should == 'exec'
    end

    it "should not fail if the route file doesn't exist" do
      Puppet[:route_file] = "/dev/null/non-existent"

      expect { @app.configure_indirector_routes }.should_not raise_error
    end

    it "should raise an error if the routes file is invalid" do
      Puppet[:route_file] = tmpfile('routes')
      File.open(Puppet[:route_file], 'w') do |f|
        f.print <<-ROUTES
         invalid : : yaml
        ROUTES
      end

      expect { @app.configure_indirector_routes }.should raise_error
    end
  end

  describe "when running" do

    before :each do
      @app.stubs(:preinit)
      @app.stubs(:setup)
      @app.stubs(:parse_options)
    end

    it "should call preinit" do
      @app.stubs(:run_command)

      @app.expects(:preinit)

      @app.run
    end

    it "should call parse_options" do
      @app.stubs(:run_command)

      @app.expects(:parse_options)

      @app.run
    end

    it "should call run_command" do

      @app.expects(:run_command)

      @app.run
    end

    it "should parse Puppet configuration if should_parse_config is called" do
      @app.stubs(:run_command)
      @app.class.should_parse_config

      Puppet.settings.expects(:parse)

      @app.run
    end

    it "should not parse_option if should_not_parse_config is called" do
      @app.stubs(:run_command)
      @app.class.should_not_parse_config

      Puppet.settings.expects(:parse).never

      @app.run
    end

    it "should parse Puppet configuration if needed" do
      @app.stubs(:run_command)
      @app.stubs(:should_parse_config?).returns(true)

      Puppet.settings.expects(:parse)

      @app.run
    end

    it "should call run_command" do
      @app.expects(:run_command)

      @app.run
    end

    it "should call main as the default command" do
      @app.expects(:main)

      @app.run
    end

    it "should warn and exit if no command can be called" do
      $stderr.expects(:puts)
      expect { @app.run }.to exit_with 1
    end

    it "should raise an error if dispatch returns no command" do
      @app.stubs(:get_command).returns(nil)
      $stderr.expects(:puts)
      expect { @app.run }.to exit_with 1
    end

    it "should raise an error if dispatch returns an invalid command" do
      @app.stubs(:get_command).returns(:this_function_doesnt_exist)
      $stderr.expects(:puts)
      expect { @app.run }.to exit_with 1
    end
  end

  describe "when metaprogramming" do

    describe "when calling option" do
      it "should create a new method named after the option" do
        @app.class.option("--test1","-t") do
        end

        @app.should respond_to(:handle_test1)
      end

      it "should transpose in option name any '-' into '_'" do
        @app.class.option("--test-dashes-again","-t") do
        end

        @app.should respond_to(:handle_test_dashes_again)
      end

      it "should create a new method called handle_test2 with option(\"--[no-]test2\")" do
        @app.class.option("--[no-]test2","-t") do
        end

        @app.should respond_to(:handle_test2)
      end

      describe "when a block is passed" do
        it "should create a new method with it" do
          @app.class.option("--[no-]test2","-t") do
            raise "I can't believe it, it works!"
          end

          lambda { @app.handle_test2 }.should raise_error
        end

        it "should declare the option to OptionParser" do
          OptionParser.any_instance.stubs(:on)
          OptionParser.any_instance.expects(:on).with { |*arg| arg[0] == "--[no-]test3" }

          @app.class.option("--[no-]test3","-t") do
          end

          @app.parse_options
        end

        it "should pass a block that calls our defined method" do
          OptionParser.any_instance.stubs(:on)
          OptionParser.any_instance.stubs(:on).with('--test4','-t').yields(nil)

          @app.expects(:send).with(:handle_test4, nil)

          @app.class.option("--test4","-t") do
          end

          @app.parse_options
        end
      end

      describe "when no block is given" do
        it "should declare the option to OptionParser" do
          OptionParser.any_instance.stubs(:on)
          OptionParser.any_instance.expects(:on).with("--test4","-t")

          @app.class.option("--test4","-t")

          @app.parse_options
        end

        it "should give to OptionParser a block that adds the the value to the options array" do
          OptionParser.any_instance.stubs(:on)
          OptionParser.any_instance.stubs(:on).with("--test4","-t").yields(nil)

          @app.options.expects(:[]=).with(:test4,nil)

          @app.class.option("--test4","-t")

          @app.parse_options
        end
      end
    end

  end
end
