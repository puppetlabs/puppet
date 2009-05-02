#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/application/puppetqd'

describe "puppetqd" do
    before :each do
        @puppetqd = Puppet::Application[:puppetqd]
        @puppetqd.stubs(:puts)
        @daemon = stub_everything 'daemon', :daemonize => nil
        Puppet::Util::Log.stubs(:newdestination)
        Puppet::Util::Log.stubs(:level=)

        Puppet::Resource::Catalog.stubs(:terminus_class=)
    end

    it "should ask Puppet::Application to parse Puppet configuration file" do
        @puppetqd.should_parse_config?.should be_true
    end

    it "should declare a main command" do
        @puppetqd.should respond_to(:main)
    end

    it "should declare a preinit block" do
        @puppetqd.should respond_to(:run_preinit)
    end

    describe "in preinit" do
        before :each do
            @puppetqd.stubs(:trap)
        end

        it "should catch INT" do
            @puppetqd.expects(:trap).with { |arg,block| arg == :INT }

            @puppetqd.run_preinit
        end

        it "should init :verbose to false" do
            @puppetqd.run_preinit

            @puppetqd.options[:verbose].should be_false
        end

        it "should init :debug to false" do
            @puppetqd.run_preinit

            @puppetqd.options[:debug].should be_false
        end

        it "should create a Daemon instance and copy ARGV to it" do
            ARGV.expects(:dup).returns "eh"
            daemon = mock("daemon")
            daemon.expects(:argv=).with("eh")
            Puppet::Daemon.expects(:new).returns daemon
            @puppetqd.run_preinit
        end
    end

    describe "when handling options" do

        [:debug, :verbose].each do |option|
            it "should declare handle_#{option} method" do
                @puppetqd.should respond_to("handle_#{option}".to_sym)
            end

            it "should store argument value when calling handle_#{option}" do
                @puppetqd.options.expects(:[]=).with(option, 'arg')
                @puppetqd.send("handle_#{option}".to_sym, 'arg')
            end
        end
    end

    describe "during setup" do
        before :each do
            @puppetqd.options.stubs(:[])
            @puppetqd.daemon.stubs(:daemonize)
            Puppet.stubs(:info)
            Puppet.features.stubs(:stomp?).returns true
            Puppet::Resource::Catalog.stubs(:terminus_class=)
            Puppet.stubs(:settraps)
            Puppet.settings.stubs(:print_config?)
            Puppet.settings.stubs(:print_config)
        end

        it "should fail if the stomp feature is missing" do
            Puppet.features.expects(:stomp?).returns false
            lambda { @puppetqd.run_setup }.should raise_error(ArgumentError)
        end

        it "should print puppet config if asked to in Puppet config" do
            @puppetqd.stubs(:exit)
            Puppet.settings.stubs(:print_configs?).returns(true)

            Puppet.settings.expects(:print_configs)

            @puppetqd.run_setup
        end

        it "should exit after printing puppet config if asked to in Puppet config" do
            Puppet.settings.stubs(:print_configs?).returns(true)

            lambda { @puppetqd.run_setup }.should raise_error(SystemExit)
        end

        it "should call setup_logs" do
            @puppetqd.expects(:setup_logs)
            @puppetqd.run_setup
        end

        describe "when setting up logs" do
            before :each do
                Puppet::Util::Log.stubs(:newdestination)
            end

            it "should set log level to debug if --debug was passed" do
                @puppetqd.options.stubs(:[]).with(:debug).returns(true)

                Puppet::Util::Log.expects(:level=).with(:debug)

                @puppetqd.setup_logs
            end

            it "should set log level to info if --verbose was passed" do
                @puppetqd.options.stubs(:[]).with(:verbose).returns(true)

                Puppet::Util::Log.expects(:level=).with(:info)

                @puppetqd.setup_logs
            end

            [:verbose, :debug].each do |level|
                it "should set console as the log destination with level #{level}" do
                    @puppetqd.options.stubs(:[]).with(level).returns(true)

                    Puppet::Util::Log.expects(:newdestination).with(:console)

                    @puppetqd.setup_logs
                end
            end
        end

        it "should configure the Catalog class to use ActiveRecord" do
            Puppet::Resource::Catalog.expects(:terminus_class=).with(:active_record)

            @puppetqd.run_setup
        end

        it "should daemonize if needed" do
            Puppet.expects(:[]).with(:daemonize).returns(true)

            @puppetqd.daemon.expects(:daemonize)

            @puppetqd.run_setup
        end
    end

    describe "when running" do
        before :each do
            @puppetqd.stubs(:sleep_forever)
            Puppet::Resource::Catalog::Queue.stubs(:subscribe)
        end

        it "should subscribe to the queue" do
            Puppet::Resource::Catalog::Queue.expects(:subscribe)
            @puppetqd.main
        end

        it "should log and save each catalog passed by the queue" do
            catalog = mock 'catalog', :name => 'eh'
            catalog.expects(:save)

            Puppet::Resource::Catalog::Queue.expects(:subscribe).yields(catalog)
            Puppet.expects(:notice)
            @puppetqd.main
        end

        it "should loop and sleep forever" do
            @puppetqd.expects(:sleep_forever)
            @puppetqd.main
        end
    end
end
