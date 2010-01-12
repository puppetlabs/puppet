#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/application/ralsh'

describe "ralsh" do
    before :each do
        @ralsh = Puppet::Application[:ralsh]
        Puppet::Util::Log.stubs(:newdestination)
        Puppet::Util::Log.stubs(:level=)
    end

    it "should ask Puppet::Application to not parse Puppet configuration file" do
        @ralsh.should_parse_config?.should be_false
    end

    it "should declare a main command" do
        @ralsh.should respond_to(:main)
    end

    it "should declare a host option" do
        @ralsh.should respond_to(:handle_host)
    end

    it "should declare a types option" do
        @ralsh.should respond_to(:handle_types)
    end

    it "should declare a param option" do
        @ralsh.should respond_to(:handle_param)
    end

    it "should declare a preinit block" do
        @ralsh.should respond_to(:run_preinit)
    end

    describe "in preinit" do
        it "should set hosts to nil" do
            @ralsh.run_preinit

            @ralsh.host.should be_nil
        end

        it "should init extra_params to empty array" do
            @ralsh.run_preinit

            @ralsh.extra_params.should == []
        end

        it "should load Facter facts" do
          Facter.expects(:loadfacts).once
          @ralsh.run_preinit
        end
    end

    describe "when handling options" do

        [:debug, :verbose, :edit].each do |option|
            it "should declare handle_#{option} method" do
                @ralsh.should respond_to("handle_#{option}".to_sym)
            end

            it "should store argument value when calling handle_#{option}" do
                @ralsh.options.expects(:[]=).with(option, 'arg')
                @ralsh.send("handle_#{option}".to_sym, 'arg')
            end
        end

        it "should set options[:host] to given host" do
            @ralsh.handle_host(:whatever)

            @ralsh.host.should == :whatever
        end

        it "should load an display all types with types option" do
            type1 = stub_everything 'type1', :name => :type1
            type2 = stub_everything 'type2', :name => :type2
            Puppet::Type.stubs(:loadall)
            Puppet::Type.stubs(:eachtype).multiple_yields(type1,type2)
            @ralsh.stubs(:exit)

            @ralsh.expects(:puts).with(['type1','type2'])
            @ralsh.handle_types(nil)
        end

        it "should add param to extra_params list" do
            @ralsh.extra_params = [ :param1 ]
            @ralsh.handle_param("whatever")

            @ralsh.extra_params.should == [ :param1, :whatever ]
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

            @ralsh.run_setup
        end

        it "should set log level to debug if --debug was passed" do
            @ralsh.options.stubs(:[]).with(:debug).returns(true)

            Puppet::Log.expects(:level=).with(:debug)

            @ralsh.run_setup
        end

        it "should set log level to info if --verbose was passed" do
            @ralsh.options.stubs(:[]).with(:debug).returns(false)
            @ralsh.options.stubs(:[]).with(:verbose).returns(true)

            Puppet::Log.expects(:level=).with(:info)

            @ralsh.run_setup
        end

        it "should Parse puppet config" do
            Puppet.expects(:parse_config)

            @ralsh.run_setup
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
            lambda { @ralsh.main }.should raise_error
            pop_args
        end

        it "should raise an error when editing a remote host" do
            @ralsh.options.stubs(:[]).with(:edit).returns(true)
            @ralsh.host = 'host'

            lambda { @ralsh.main }.should raise_error
        end

        it "should raise an error if the type is not found" do
            Puppet::Type.stubs(:type).returns(nil)

            lambda { @ralsh.main }.should raise_error
        end

        describe "with a host" do
            before :each do
                @ralsh.stubs(:puts)
                @ralsh.host = 'host'
                @client = stub_everything 'client'
                @client.stubs(:read_cert).returns(true)
                @client.stubs(:instances).returns([])
                Puppet::Network::Client.resource.stubs(:new).returns(@client)
            end

            it "should connect to it" do
                Puppet::Network::Client.resource.expects(:new).with { |h| h[:Server] == 'host' }.returns(@client)
                @ralsh.main
            end

            it "should raise an error if there are no certs" do
                @client.stubs(:read_cert).returns(nil)

                lambda { @ralsh.main }.should raise_error
            end

            it "should retrieve all the instances if there is no name" do
                @client.expects(:instances).returns([])

                @ralsh.main
            end

            it "should describe the given resource" do
                push_args('type','name')
                @client.expects(:describe).returns(stub_everything)
                @ralsh.main
                pop_args
            end
        end

        describe "without a host" do
            before :each do
                @ralsh.stubs(:puts)
                @ralsh.host = nil
            end

            it "should retrieve all the instances if there is no name" do
                @type.expects(:instances).returns([])

                @ralsh.main
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
                    @ralsh.main
                    pop_args
                end
            end
        end
    end
end
