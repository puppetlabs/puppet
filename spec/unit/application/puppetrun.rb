#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/util/ldap/connection'
require 'puppet/application/puppetrun'

describe "puppetrun" do
    before :each do
        Puppet::Util::Ldap::Connection.stubs(:new).returns(stub_everything)
        @puppetrun = Puppet::Application[:puppetrun]
        Puppet::Util::Log.stubs(:newdestination)
        Puppet::Util::Log.stubs(:level=)
    end

    it "should ask Puppet::Application to not parse Puppet configuration file" do
        @puppetrun.should_parse_config?.should be_false
    end

    it "should declare a main command" do
        @puppetrun.should respond_to(:main)
    end

    it "should declare a test command" do
        @puppetrun.should respond_to(:test)
    end

    it "should declare a preinit block" do
        @puppetrun.should respond_to(:run_preinit)
    end

    describe "during preinit" do
        before :each do
            @puppetrun.stubs(:trap)
        end

        it "should catch INT and TERM" do
            @puppetrun.stubs(:trap).with { |arg,block| arg == :INT or arg == :TERM }

            @puppetrun.run_preinit
        end

        it "should set parallel option to 1" do
            @puppetrun.run_preinit

            @puppetrun.options[:parallel].should == 1
        end

        it "should set verbose by default" do
            @puppetrun.run_preinit

            @puppetrun.options[:verbose].should be_true
        end

        it "should set fqdn by default" do
            @puppetrun.run_preinit

            @puppetrun.options[:fqdn].should be_true
        end

        it "should set ignoreschedules to 'false'" do
            @puppetrun.run_preinit

            @puppetrun.options[:ignoreschedules].should be_false
        end

        it "should set foreground to 'false'" do
            @puppetrun.run_preinit

            @puppetrun.options[:foreground].should be_false
        end
    end

    describe "when applying options" do

        [:all, :foreground, :debug, :ping, :test].each do |option|
            it "should declare handle_#{option} method" do
                @puppetrun.should respond_to("handle_#{option}".to_sym)
            end

            it "should store argument value when calling handle_#{option}" do
                @puppetrun.options.expects(:[]=).with(option, 'arg')
                @puppetrun.send("handle_#{option}".to_sym, 'arg')
            end
        end

        it "should add to the host list with the host option" do
            @puppetrun.handle_host('host')

            @puppetrun.hosts.should == ['host']
        end

        it "should add to the tag list with the tag option" do
            @puppetrun.handle_tag('tag')

            @puppetrun.tags.should == ['tag']
        end

        it "should add to the class list with the class option" do
            @puppetrun.handle_class('class')

            @puppetrun.classes.should == ['class']
        end
    end

    describe "during setup" do

        before :each do
            @puppetrun.classes = []
            @puppetrun.tags = []
            @puppetrun.hosts = []
            Puppet::Log.stubs(:level=)
            @puppetrun.stubs(:trap)
            @puppetrun.stubs(:puts)
            Puppet.stubs(:parse_config)

            @puppetrun.options.stubs(:[]).with(any_parameters)
        end

        it "should set log level to debug if --debug was passed" do
            @puppetrun.options.stubs(:[]).with(:debug).returns(true)

            Puppet::Log.expects(:level=).with(:debug)

            @puppetrun.run_setup
        end

        it "should set log level to info if --verbose was passed" do
            @puppetrun.options.stubs(:[]).with(:verbose).returns(true)

            Puppet::Log.expects(:level=).with(:info)

            @puppetrun.run_setup
        end

        it "should Parse puppet config" do
            Puppet.expects(:parse_config)

            @puppetrun.run_setup
        end

        describe "when using the ldap node terminus" do
            before :each do
                Puppet.stubs(:[]).with(:node_terminus).returns("ldap")
            end

            it "should pass the fqdn option to search" do
                @puppetrun.options.stubs(:[]).with(:fqdn).returns(:something)
                @puppetrun.options.stubs(:[]).with(:all).returns(true)
                @puppetrun.stubs(:puts)

                Puppet::Node.expects(:search).with("whatever",:fqdn => :something).returns([])

                @puppetrun.run_setup
            end

            it "should search for all nodes if --all" do
                @puppetrun.options.stubs(:[]).with(:all).returns(true)
                @puppetrun.stubs(:puts)

                Puppet::Node.expects(:search).with("whatever",:fqdn => nil).returns([])

                @puppetrun.run_setup
            end

            it "should search for nodes including given classes" do
                @puppetrun.options.stubs(:[]).with(:all).returns(false)
                @puppetrun.stubs(:puts)
                @puppetrun.classes = ['class']

                Puppet::Node.expects(:search).with("whatever", :class => "class", :fqdn => nil).returns([])

                @puppetrun.run_setup
            end
        end

        describe "when using regular nodes" do
            it "should fail if some classes have been specified" do
                $stderr.stubs(:puts)
                @puppetrun.classes = ['class']

                @puppetrun.expects(:exit).with(24)

                @puppetrun.run_setup
            end
        end
    end

    describe "when running" do
        before :each do
            @puppetrun.stubs(:puts)
        end

        it "should dispatch to test if --test is used" do
            @puppetrun.options.stubs(:[]).with(:test).returns(true)

            @puppetrun.get_command.should == :test
        end

        it "should dispatch to main if --test is not used" do
            @puppetrun.options.stubs(:[]).with(:test).returns(false)

            @puppetrun.get_command.should == :main
        end

        describe "the test command" do
            it "should exit with exit code 0 " do
                @puppetrun.expects(:exit).with(0)

                @puppetrun.test
            end
        end

        describe "the main command" do
            before :each do
                @client = stub_everything 'client'
                @client.stubs(:run).returns("success")
                Puppet::Network::Client.runner.stubs(:new).returns(@client)
                @puppetrun.options.stubs(:[]).with(:parallel).returns(1)
                @puppetrun.options.stubs(:[]).with(:ping).returns(false)
                @puppetrun.options.stubs(:[]).with(:ignoreschedules).returns(false)
                @puppetrun.options.stubs(:[]).with(:foreground).returns(false)
                @puppetrun.stubs(:print)
                @puppetrun.stubs(:exit)
                $stderr.stubs(:puts)
            end

            it "should create as much childs as --parallel" do
                @puppetrun.options.stubs(:[]).with(:parallel).returns(3)
                @puppetrun.hosts = ['host1', 'host2', 'host3']
                @puppetrun.stubs(:exit).raises(SystemExit)
                Process.stubs(:wait).returns(1).then.returns(2).then.returns(3).then.raises(Errno::ECHILD)

                @puppetrun.expects(:fork).times(3).returns(1).then.returns(2).then.returns(3)

                lambda { @puppetrun.main }.should raise_error
            end

            it "should delegate to run_for_host per host" do
                @puppetrun.hosts = ['host1', 'host2']
                @puppetrun.stubs(:exit).raises(SystemExit)
                @puppetrun.stubs(:fork).returns(1).yields
                Process.stubs(:wait).returns(1).then.raises(Errno::ECHILD)

                @puppetrun.expects(:run_for_host).times(2)

                lambda { @puppetrun.main }.should raise_error
            end

            describe "during call of run_for_host" do
                it "should create a Runner Client per given host" do
                    Puppet::Network::Client.runner.expects(:new).returns(@client)

                    @puppetrun.run_for_host('host')
                end

                it "should call Client.run for the given host" do
                    @client.expects(:run)

                    @puppetrun.run_for_host('host')
                end

                it "should exit the child with 0 on success" do
                    @client.stubs(:run).returns("success")

                    @puppetrun.expects(:exit).with(0)

                    @puppetrun.run_for_host('host')
                end

                it "should exit the child with 3 on running" do
                    @client.stubs(:run).returns("running")

                    @puppetrun.expects(:exit).with(3)

                    @puppetrun.run_for_host('host')
                end

                it "should exit the child with 12 on unknown answer" do
                    @client.stubs(:run).returns("whatever")

                    @puppetrun.expects(:exit).with(12)

                    @puppetrun.run_for_host('host')
                end
            end
        end
    end
end
