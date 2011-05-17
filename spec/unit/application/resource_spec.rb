#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/application/resource'

describe Puppet::Application::Resource do
  before :each do
    @resource = Puppet::Application[:resource]
    Puppet::Util::Log.stubs(:newdestination)
    Puppet::Resource.indirection.stubs(:terminus_class=)
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
    @resource.should respond_to(:preinit)
  end

  describe "in preinit" do
    it "should set hosts to nil", :'fails_on_ruby_1.9.2' => true do
      @resource.preinit

      @resource.host.should be_nil
    end

    it "should init extra_params to empty array", :'fails_on_ruby_1.9.2' => true do
      @resource.preinit

      @resource.extra_params.should == []
    end

    it "should load Facter facts" do
      Facter.expects(:loadfacts).once
      @resource.preinit
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
      @resource.expects(:puts).with(['type1','type2'])
      expect { @resource.handle_types(nil) }.to exit_with 0
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
      Puppet.stubs(:parse_config)
    end


    it "should set console as the log destination" do
      Puppet::Log.expects(:newdestination).with(:console)

      @resource.setup
    end

    it "should set log level to debug if --debug was passed" do
      @resource.options.stubs(:[]).with(:debug).returns(true)
      @resource.setup
      Puppet::Log.level.should == :debug
    end

    it "should set log level to info if --verbose was passed" do
      @resource.options.stubs(:[]).with(:debug).returns(false)
      @resource.options.stubs(:[]).with(:verbose).returns(true)
      @resource.setup
      Puppet::Log.level.should == :info
    end

    it "should Parse puppet config" do
      Puppet.expects(:parse_config)

      @resource.setup
    end
  end

  describe "when running" do

    before :each do
      @type = stub_everything 'type', :properties => []
      @resource.command_line.stubs(:args).returns(['type'])
      Puppet::Type.stubs(:type).returns(@type)
    end

    it "should raise an error if no type is given" do
      @resource.command_line.stubs(:args).returns([])
      lambda { @resource.main }.should raise_error
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

        Puppet::Resource.indirection.stubs(:find  ).never
        Puppet::Resource.indirection.stubs(:search).never
        Puppet::Resource.indirection.stubs(:save  ).never
      end

      it "should search for resources" do
        @resource.command_line.stubs(:args).returns(['type'])
        Puppet::Resource.indirection.expects(:search).with('https://host:8139/production/resources/type/', {}).returns([])
        @resource.main
      end

      it "should describe the given resource" do
        @resource.command_line.stubs(:args).returns(['type', 'name'])
        x = stub_everything 'resource'
        Puppet::Resource.indirection.expects(:find).with('https://host:8139/production/resources/type/name').returns(x)
        @resource.main
      end

      it "should add given parameters to the object" do
        @resource.command_line.stubs(:args).returns(['type','name','param=temp'])

        res = stub "resource"
        Puppet::Resource.indirection.expects(:save).with(res, 'https://host:8139/production/resources/type/name').returns(res)
        res.expects(:collect)
        res.expects(:to_manifest)
        Puppet::Resource.expects(:new).with('type', 'name', :parameters => {'param' => 'temp'}).returns(res)

        @resource.main
      end

    end

    describe "without a host" do
      before :each do
        @resource.stubs(:puts)
        @resource.host = nil

        Puppet::Resource.indirection.stubs(:find  ).never
        Puppet::Resource.indirection.stubs(:search).never
        Puppet::Resource.indirection.stubs(:save  ).never
      end

      it "should search for resources" do
        Puppet::Resource.indirection.expects(:search).with('type/', {}).returns([])
        @resource.main
      end

      it "should describe the given resource" do
        @resource.command_line.stubs(:args).returns(['type','name'])
        x = stub_everything 'resource'
        Puppet::Resource.indirection.expects(:find).with('type/name').returns(x)
        @resource.main
      end

      it "should add given parameters to the object" do
        @resource.command_line.stubs(:args).returns(['type','name','param=temp'])

        res = stub "resource"
        Puppet::Resource.indirection.expects(:save).with(res, 'type/name').returns(res)
        res.expects(:collect)
        res.expects(:to_manifest)
        Puppet::Resource.expects(:new).with('type', 'name', :parameters => {'param' => 'temp'}).returns(res)

        @resource.main
      end

    end
  end
end
