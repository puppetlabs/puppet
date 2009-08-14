#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/application/resource'

describe "resource" do
    before :each do
        @resource = Puppet::Application[:resource]
        Puppet::Util::Log.stubs(:newdestination)
        Puppet::Util::Log.stubs(:level=)
    end

    it "should ask Puppet::Application to not parse Puppet configuration file" do
        @resource.should_parse_config?.should be_false
    end

    it "should declare a main command" do
        @resource.should respond_to(:main)
    end

    it "should declare a host option" do
        @resource.should respond_to(:handle_host)
    end

    it "should declare a types option" do
        @resource.should respond_to(:handle_types)
    end

    it "should declare a param option" do
        @resource.should respond_to(:handle_param)
    end

    it "should declare a preinit block" do
        @resource.should respond_to(:run_preinit)
    end

    describe "in preinit" do
        it "should set hosts to nil" do
            @resource.run_preinit

            @resource.host.should be_nil
        end

        it "should init extra_params to empty array" do
            @resource.run_preinit

            @resource.extra_params.should == []
        end

        it "should load Facter facts" do
          Facter.expects(:loadfacts).once
          @resource.run_preinit
        end
    end

    describe "when handling options" do

        [:debug, :verbose, :edit].each do |option|
            it "should declare handle_#{option} method" do
                @resource.should respond_to("handle_#{option}".to_sym)
            end

            it "should store argument value when calling handle_#{option}" do
                @resource.options.expects(:[]=).with(option, 'arg')
                @resource.send("handle_#{option}".to_sym, 'arg')
            end
        end

        it "should set options[:host] to given host" do
            @resource.handle_host(:whatever)

            @resource.host.should == :whatever
        end

        it "should load an display all types with types option" do
            type1 = stub_everything 'type1', :name => :type1
            type2 = stub_everything 'type2', :name => :type2
            Puppet::Type.stubs(:loadall)
            Puppet::Type.stubs(:eachtype).multiple_yields(type1,type2)
            @resource.stubs(:exit)

            @resource.expects(:puts).with(['type1','type2'])
            @resource.handle_types(nil)
        end

        it "should add param to extra_params list" do
            @resource.extra_params = [ :param1 ]
            @resource.handle_param("whatever")

            @resource.extra_params.should == [ :param1, :whatever ]
        end
    end

    describe "during setup" do
        before :each do
            Puppet::Log.stubs(:newdestination)
            Puppet::Log.stubs(:level=)
            Puppet.stubs(:parse_config)
        end


        it "should set console as the log destination" do
            Puppet::Log.expects(:newdestination).with(:console)

            @resource.run_setup
        end

        it "should set log level to debug if --debug was passed" do
            @resource.options.stubs(:[]).with(:debug).returns(true)

            Puppet::Log.expects(:level=).with(:debug)

            @resource.run_setup
        end

        it "should set log level to info if --verbose was passed" do
            @resource.options.stubs(:[]).with(:debug).returns(false)
            @resource.options.stubs(:[]).with(:verbose).returns(true)

            Puppet::Log.expects(:level=).with(:info)

            @resource.run_setup
        end

        it "should Parse puppet config" do
            Puppet.expects(:parse_config)

            @resource.run_setup
        end
    end

    describe "when running" do

        def set_args(args)
            (ARGV.clear << args).flatten!
        end

        def push_args(*args)
            @args_stack ||= []
            @args_stack << ARGV.dup
            set_args(args)
        end

        def pop_args
            set_args(@args_stack.pop)
        end

        before :each do
            @type = stub_everything 'type', :properties => []
            push_args('type')
            Puppet::Type.stubs(:type).returns(@type)
        end

        after :each do
            pop_args
        end

        it "should raise an error if no type is given" do
            push_args
            lambda { @resource.main }.should raise_error
            pop_args
        end

        it "should raise an error when editing a remote host" do
            @resource.options.stubs(:[]).with(:edit).returns(true)
            @resource.host = 'host'

            lambda { @resource.main }.should raise_error
        end

        it "should raise an error if the type is not found" do
            Puppet::Type.stubs(:type).returns(nil)

            lambda { @resource.main }.should raise_error
        end

        describe "with a host" do
            before :each do
                @resource.stubs(:puts)
                @resource.host = 'host'
                @client = stub_everything 'client'
                @client.stubs(:read_cert).returns(true)
                @client.stubs(:instances).returns([])
                Puppet::Network::Client.resource.stubs(:new).returns(@client)
            end

            it "should connect to it" do
                Puppet::Network::Client.resource.expects(:new).with { |h| h[:Server] == 'host' }.returns(@client)
                @resource.main
            end

            it "should raise an error if there are no certs" do
                @client.stubs(:read_cert).returns(nil)

                lambda { @resource.main }.should raise_error
            end

            it "should retrieve all the instances if there is no name" do
                @client.expects(:instances).returns([])

                @resource.main
            end

            it "should describe the given resource" do
                push_args('type','name')
                @client.expects(:describe).returns(stub_everything)
                @resource.main
                pop_args
            end
        end

        describe "without a host" do
            before :each do
                @resource.stubs(:puts)
                @resource.host = nil
            end

            it "should retrieve all the instances if there is no name" do
                @type.expects(:instances).returns([])

                @resource.main
            end

            describe 'but with a given name' do
                before :each do
                    push_args('type','name')
                    @type.stubs(:new).returns(:bob)
                end

                after :each do
                    pop_args
                end

                it "should retrieve a specific instance if it exists" do
                    pending
                end

                it "should create a stub instance if it doesn't exist" do
                    pending
                end

                it "should add given parameters to the object" do
                    push_args('type','name','param=temp')
                    pending
                    @object.expects(:[]=).with('param','temp')
                    @resource.main
                    pop_args
                end
            end
        end
    end
end
