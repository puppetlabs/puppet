#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/util/ldap/connection'
require 'puppet/application/run'

describe "run" do
    before :each do
        Puppet::Util::Ldap::Connection.stubs(:new).returns(stub_everything)
        @run = Puppet::Application[:run]
        Puppet::Util::Log.stubs(:newdestination)
        Puppet::Util::Log.stubs(:level=)
    end

    it "should ask Puppet::Application to not parse Puppet configuration file" do
        @run.should_parse_config?.should be_false
    end

    it "should declare a main command" do
        @run.should respond_to(:main)
    end

    it "should declare a test command" do
        @run.should respond_to(:test)
    end

    it "should declare a preinit block" do
        @run.should respond_to(:run_preinit)
    end

    describe "during preinit" do
        before :each do
            @run.stubs(:trap)
        end

        it "should catch INT and TERM" do
            @run.stubs(:trap).with { |arg,block| arg == :INT or arg == :TERM }

            @run.run_preinit
        end

        it "should set parallel option to 1" do
            @run.run_preinit

            @run.options[:parallel].should == 1
        end

        it "should set verbose by default" do
            @run.run_preinit

            @run.options[:verbose].should be_true
        end

        it "should set fqdn by default" do
            @run.run_preinit

            @run.options[:fqdn].should be_true
        end

        it "should set ignoreschedules to 'false'" do
            @run.run_preinit

            @run.options[:ignoreschedules].should be_false
        end

        it "should set foreground to 'false'" do
            @run.run_preinit

            @run.options[:foreground].should be_false
        end
    end

    describe "when applying options" do

        [:all, :foreground, :debug, :ping, :test].each do |option|
            it "should declare handle_#{option} method" do
                @run.should respond_to("handle_#{option}".to_sym)
            end

            it "should store argument value when calling handle_#{option}" do
                @run.options.expects(:[]=).with(option, 'arg')
                @run.send("handle_#{option}".to_sym, 'arg')
            end
        end

        it "should add to the host list with the host option" do
            @run.handle_host('host')

            @run.hosts.should == ['host']
        end

        it "should add to the tag list with the tag option" do
            @run.handle_tag('tag')

            @run.tags.should == ['tag']
        end

        it "should add to the class list with the class option" do
            @run.handle_class('class')

            @run.classes.should == ['class']
        end
    end

    describe "during setup" do

        before :each do
            @run.classes = []
            @run.tags = []
            @run.hosts = []
            Puppet::Log.stubs(:level=)
            @run.stubs(:trap)
            @run.stubs(:puts)
            Puppet.stubs(:parse_config)

            @run.options.stubs(:[]).with(any_parameters)
        end

        it "should set log level to debug if --debug was passed" do
            @run.options.stubs(:[]).with(:debug).returns(true)

            Puppet::Log.expects(:level=).with(:debug)

            @run.run_setup
        end

        it "should set log level to info if --verbose was passed" do
            @run.options.stubs(:[]).with(:verbose).returns(true)

            Puppet::Log.expects(:level=).with(:info)

            @run.run_setup
        end

        it "should Parse puppet config" do
            Puppet.expects(:parse_config)

            @run.run_setup
        end

        describe "when using the ldap node terminus" do
            before :each do
                Puppet.stubs(:[]).with(:node_terminus).returns("ldap")
            end

            it "should pass the fqdn option to search" do
                @run.options.stubs(:[]).with(:fqdn).returns(:something)
                @run.options.stubs(:[]).with(:all).returns(true)
                @run.stubs(:puts)

                Puppet::Node.expects(:search).with("whatever",:fqdn => :something).returns([])

                @run.run_setup
            end

            it "should search for all nodes if --all" do
                @run.options.stubs(:[]).with(:all).returns(true)
                @run.stubs(:puts)

                Puppet::Node.expects(:search).with("whatever",:fqdn => nil).returns([])

                @run.run_setup
            end

            it "should search for nodes including given classes" do
                @run.options.stubs(:[]).with(:all).returns(false)
                @run.stubs(:puts)
                @run.classes = ['class']

                Puppet::Node.expects(:search).with("whatever", :class => "class", :fqdn => nil).returns([])

                @run.run_setup
            end
        end

        describe "when using regular nodes" do
            it "should fail if some classes have been specified" do
                $stderr.stubs(:puts)
                @run.classes = ['class']

                @run.expects(:exit).with(24)

                @run.run_setup
            end
        end
    end

    describe "when running" do
        before :each do
            @run.stubs(:puts)
        end

        it "should dispatch to test if --test is used" do
            @run.options.stubs(:[]).with(:test).returns(true)

            @run.get_command.should == :test
        end

        it "should dispatch to main if --test is not used" do
            @run.options.stubs(:[]).with(:test).returns(false)

            @run.get_command.should == :main
        end

        describe "the test command" do
            it "should exit with exit code 0 " do
                @run.expects(:exit).with(0)

                @run.test
            end
        end

        describe "the main command" do
            before :each do
                @run.options.stubs(:[]).with(:parallel).returns(1)
                @run.options.stubs(:[]).with(:ping).returns(false)
                @run.options.stubs(:[]).with(:ignoreschedules).returns(false)
                @run.options.stubs(:[]).with(:foreground).returns(false)
                @run.stubs(:print)
                @run.stubs(:exit)
                $stderr.stubs(:puts)
            end

            it "should create as much childs as --parallel" do
                @run.options.stubs(:[]).with(:parallel).returns(3)
                @run.hosts = ['host1', 'host2', 'host3']
                @run.stubs(:exit).raises(SystemExit)
                Process.stubs(:wait).returns(1).then.returns(2).then.returns(3).then.raises(Errno::ECHILD)

                @run.expects(:fork).times(3).returns(1).then.returns(2).then.returns(3)

                lambda { @run.main }.should raise_error
            end

            it "should delegate to run_for_host per host" do
                @run.hosts = ['host1', 'host2']
                @run.stubs(:exit).raises(SystemExit)
                @run.stubs(:fork).returns(1).yields
                Process.stubs(:wait).returns(1).then.raises(Errno::ECHILD)

                @run.expects(:run_for_host).times(2)

                lambda { @run.main }.should raise_error
            end

            describe "during call of run_for_host" do
                before do
                    require 'puppet/run'
                    options = {
                        :background => true, :ignoreschedules => false, :tags => []
                    }
                    @run = Puppet::Run.new( options.dup )
                    @run.stubs(:status).returns("success")

                    Puppet::Run.indirection.expects(:terminus_class=).with( :rest )
                    Puppet::Run.expects(:new).with( options ).returns(@run)
                end

                it "should call run on a Puppet::Run for the given host" do
                    @run.expects(:save).with('https://host:8139/production/run/host').returns(@run)

                    @run.run_for_host('host')
                end

                it "should exit the child with 0 on success" do
                    @run.stubs(:status).returns("success")

                    @run.expects(:exit).with(0)

                    @run.run_for_host('host')
                end

                it "should exit the child with 3 on running" do
                    @run.stubs(:status).returns("running")

                    @run.expects(:exit).with(3)

                    @run.run_for_host('host')
                end

                it "should exit the child with 12 on unknown answer" do
                    @run.stubs(:status).returns("whatever")

                    @run.expects(:exit).with(12)

                    @run.run_for_host('host')
                end
            end
        end
    end
end
