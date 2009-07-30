#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/application'
require 'puppet'
require 'getoptlong'

describe Puppet::Application do

    before :each do
        @app = Puppet::Application.new(:test)
    end

    it "should have a run entry-point" do
        @app.should respond_to(:run)
    end

    it "should have a read accessor to options" do
        @app.should respond_to(:options)
    end

    it "should create a default run_setup method" do
        @app.should respond_to(:run_setup)
    end

    it "should create a default run_preinit method" do
        @app.should respond_to(:run_preinit)
    end

    it "should create a default get_command method" do
        @app.should respond_to(:get_command)
    end

    it "should return :main as default get_command" do
        @app.get_command.should == :main
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

    describe 'when working with class-level run status properties' do
        it 'should set run status and predicate appropriately on stop!' do
        end

        it 'should set run status and predicate appropriately on restart!' do
        end


    end

    describe "when parsing command-line options" do

        before :each do
            @argv_bak = ARGV.dup
            ARGV.clear

            Puppet.settings.stubs(:optparse_addargs).returns([])
            @app = Puppet::Application.new(:test)
        end

        after :each do
            ARGV.clear
            ARGV << @argv_bak
        end

        it "should get options from Puppet.settings.optparse_addargs" do
            Puppet.settings.expects(:optparse_addargs).returns([])

            @app.parse_options
        end

        it "should add Puppet.settings options to OptionParser" do
            Puppet.settings.stubs(:optparse_addargs).returns( [["--option","-o", "Funny Option"]])

            @app.opt_parser.expects(:on).with { |*arg| arg == ["--option","-o", "Funny Option"] }

            @app.parse_options
        end

        it "should ask OptionParser to parse the command-line argument" do
            @app.opt_parser.expects(:parse!)

            @app.parse_options
        end

        describe "when using --help" do
            confine "rdoc" => Puppet.features.usage?

            it "should call RDoc::usage and exit" do
                @app.expects(:exit)
                RDoc.expects(:usage).returns(true)

                @app.handle_help(nil)
            end

        end

        describe "when using --version" do
            it "should declare a version option" do
                @app.should respond_to(:handle_version)
            end

            it "should exit after printing the version" do
                @app.stubs(:puts)

                lambda { @app.handle_version(nil) }.should raise_error(SystemExit)
            end
        end

        describe "when dealing with an argument not declared directly by the application" do
            it "should pass it to handle_unknown if this method exists" do
                Puppet.settings.stubs(:optparse_addargs).returns([["--not-handled"]])
                @app.opt_parser.stubs(:on).yields("value")

                @app.expects(:handle_unknown).with("--not-handled", "value").returns(true)

                @app.parse_options
            end

            it "should pass it to Puppet.settings if handle_unknown says so" do
                Puppet.settings.stubs(:optparse_addargs).returns([["--topuppet"]])
                @app.opt_parser.stubs(:on).yields("value")

                @app.stubs(:handle_unknown).with("--topuppet", "value").returns(false)

                Puppet.settings.expects(:handlearg).with("--topuppet", "value")
                @app.parse_options
            end

            it "should pass it to Puppet.settings if there is no handle_unknown method" do
                Puppet.settings.stubs(:optparse_addargs).returns([["--topuppet"]])
                @app.opt_parser.stubs(:on).yields("value")

                @app.stubs(:respond_to?).returns(false)

                Puppet.settings.expects(:handlearg).with("--topuppet", "value")
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

        it "should exit if OptionParser raises an error" do
            $stderr.stubs(:puts)
            @app.opt_parser.stubs(:parse!).raises(OptionParser::ParseError.new("blah blah"))

            @app.expects(:exit)

            lambda { @app.parse_options }.should_not raise_error
        end

    end

    describe "when calling default setup" do

        before :each do
            @app = Puppet::Application.new(:test)
            @app.stubs(:should_parse_config?).returns(false)
            @app.options.stubs(:[])
        end

        [ :debug, :verbose ].each do |level|
            it "should honor option #{level}" do
                @app.options.stubs(:[]).with(level).returns(true)
                Puppet::Util::Log.stubs(:newdestination)

                Puppet::Util::Log.expects(:level=).with(level == :verbose ? :info : :debug)

                @app.run_setup
            end
        end

        it "should honor setdest option" do
            @app.options.stubs(:[]).with(:setdest).returns(false)

            Puppet::Util::Log.expects(:newdestination).with(:syslog)

            @app.run_setup
        end

    end

    describe "when running" do

        before :each do
            @app = Puppet::Application.new(:test)
            @app.stubs(:run_preinit)
            @app.stubs(:run_setup)
            @app.stubs(:parse_options)
        end

        it "should call run_preinit" do
            @app.stubs(:run_command)

            @app.expects(:run_preinit)

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
            @app.should_parse_config

            Puppet.settings.expects(:parse)

            @app.run
        end

        it "should not parse_option if should_not_parse_config is called" do
            @app.stubs(:run_command)
            @app.should_not_parse_config

            Puppet.settings.expects(:parse).never

            @app.run
        end

        it "should parse Puppet configuration if needed" do
            @app.stubs(:run_command)
            @app.stubs(:should_parse_config?).returns(true)

            Puppet.settings.expects(:parse)

            @app.run
        end

        it "should call the action matching what returned command" do
            @app.stubs(:get_command).returns(:backup)
            @app.stubs(:respond_to?).with(:backup).returns(true)

            @app.expects(:backup)

            @app.run
        end

        it "should call main as the default command" do
            @app.expects(:main)

            @app.run
        end

        it "should warn and exit if no command can be called" do
            $stderr.expects(:puts)
            @app.expects(:exit).with(1)
            @app.run
        end

        it "should raise an error if dispatch returns no command" do
            @app.stubs(:get_command).returns(nil)
            $stderr.expects(:puts)
            @app.expects(:exit).with(1)
            @app.run
        end

        it "should raise an error if dispatch returns an invalid command" do
            @app.stubs(:get_command).returns(:this_function_doesnt_exist)
            $stderr.expects(:puts)
            @app.expects(:exit).with(1)
            @app.run
        end
    end

    describe "when metaprogramming" do

        before :each do
            @app = Puppet::Application.new(:test)
        end

        it "should create a new method with command" do
            @app.command(:test) do
            end

            @app.should respond_to(:test)
        end

        describe "when calling attr_accessor" do
            it "should create a reader method" do
                @app.attr_accessor(:attribute)

                @app.should respond_to(:attribute)
            end

            it "should create a reader that delegates to instance_variable_get" do
                @app.attr_accessor(:attribute)

                @app.expects(:instance_variable_get).with(:@attribute)
                @app.attribute
            end

            it "should create a writer method" do
                @app.attr_accessor(:attribute)

                @app.should respond_to(:attribute=)
            end

            it "should create a writer that delegates to instance_variable_set" do
                @app.attr_accessor(:attribute)

                @app.expects(:instance_variable_set).with(:@attribute, 1234)
                @app.attribute=1234
            end
        end

        describe "when calling option" do
            it "should create a new method named after the option" do
                @app.option("--test1","-t") do
                end

                @app.should respond_to(:handle_test1)
            end

            it "should transpose in option name any '-' into '_'" do
                @app.option("--test-dashes-again","-t") do
                end

                @app.should respond_to(:handle_test_dashes_again)
            end

            it "should create a new method called handle_test2 with option(\"--[no-]test2\")" do
                @app.option("--[no-]test2","-t") do
                end

                @app.should respond_to(:handle_test2)
            end

            describe "when a block is passed" do
                it "should create a new method with it" do
                    @app.option("--[no-]test2","-t") do
                        raise "I can't believe it, it works!"
                    end

                    lambda { @app.handle_test2 }.should raise_error
                end

                it "should declare the option to OptionParser" do
                    @app.opt_parser.expects(:on).with { |*arg| arg[0] == "--[no-]test3" }

                    @app.option("--[no-]test3","-t") do
                    end
                end

                it "should pass a block that calls our defined method" do
                    @app.opt_parser.stubs(:on).yields(nil)

                    @app.expects(:send).with(:handle_test4, nil)

                    @app.option("--test4","-t") do
                    end
                end
            end

            describe "when no block is given" do
                it "should declare the option to OptionParser" do
                    @app.opt_parser.expects(:on).with("--test4","-t")

                    @app.option("--test4","-t")
                end

                it "should give to OptionParser a block that adds the the value to the options array" do
                    @app.opt_parser.stubs(:on).with("--test4","-t").yields(nil)

                    @app.options.expects(:[]=).with(:test4,nil)

                    @app.option("--test4","-t")
                end
            end
        end

        it "should create a method called run_setup with setup" do
            @app.setup do
            end

            @app.should respond_to(:run_setup)
        end

        it "should create a method called run_preinit with preinit" do
            @app.preinit do
            end

            @app.should respond_to(:run_preinit)
        end

        it "should create a method called handle_unknown with unknown" do
            @app.unknown do
            end

            @app.should respond_to(:handle_unknown)
        end


        it "should create a method called get_command with dispatch" do
            @app.dispatch do
            end

            @app.should respond_to(:get_command)
        end
    end
end
