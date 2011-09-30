#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/application/resource'

describe Puppet::Application::Resource do
  before :each do
    @resource_app = Puppet::Application[:resource]
    Puppet::Util::Log.stubs(:newdestination)
    Puppet::Resource.indirection.stubs(:terminus_class=)
  end

  it "should ask Puppet::Application to not parse Puppet configuration file" do
    @resource_app.should_parse_config?.should be_false
  end

  describe "in preinit" do
    it "should init extra_params to empty array", :'fails_on_ruby_1.9.2' => true do
      @resource_app.preinit
      @resource_app.extra_params.should == []
    end

    it "should load Facter facts" do
      Facter.expects(:loadfacts).once
      @resource_app.preinit
    end
  end

  describe "when handling options" do
    [:debug, :verbose, :edit].each do |option|
      it "should store argument value when calling handle_#{option}" do
        @resource_app.options.expects(:[]=).with(option, 'arg')
        @resource_app.send("handle_#{option}".to_sym, 'arg')
      end
    end

    it "should set options[:host] to given host" do
      @resource_app.handle_host(:whatever)
      @resource_app.host.should == :whatever
    end

    it "should load an display all types with types option" do
      type1 = stub_everything 'type1', :name => :type1
      type2 = stub_everything 'type2', :name => :type2
      Puppet::Type.stubs(:loadall)
      Puppet::Type.stubs(:eachtype).multiple_yields(type1,type2)
      @resource_app.expects(:puts).with(['type1','type2'])
      expect { @resource_app.handle_types(nil) }.to exit_with 0
    end

    it "should add param to extra_params list" do
      @resource_app.extra_params = [ :param1 ]
      @resource_app.handle_param("whatever")

      @resource_app.extra_params.should == [ :param1, :whatever ]
    end
  end

  describe "during setup" do
    before :each do
      Puppet::Log.stubs(:newdestination)
      Puppet.stubs(:parse_config)
    end

    it "should set console as the log destination" do
      Puppet::Log.expects(:newdestination).with(:console)

      @resource_app.setup
    end

    it "should set log level to debug if --debug was passed" do
      @resource_app.options.stubs(:[]).with(:debug).returns(true)
      @resource_app.setup
      Puppet::Log.level.should == :debug
    end

    it "should set log level to info if --verbose was passed" do
      @resource_app.options.stubs(:[]).with(:debug).returns(false)
      @resource_app.options.stubs(:[]).with(:verbose).returns(true)
      @resource_app.setup
      Puppet::Log.level.should == :info
    end

    it "should Parse puppet config" do
      Puppet.expects(:parse_config)

      @resource_app.setup
    end
  end

  describe "when running" do
    before :each do
      @type = stub_everything 'type', :properties => []
      @resource_app.command_line.stubs(:args).returns(['mytype'])
      Puppet::Type.stubs(:type).returns(@type)

      @res = stub_everything "resource"
      @res.stubs(:prune_parameters).returns(@res)
      @report = stub_everything "report"
    end

    it "should raise an error if no type is given" do
      @resource_app.command_line.stubs(:args).returns([])
      lambda { @resource_app.main }.should raise_error(RuntimeError, "You must specify the type to display")
    end

    it "should raise an error when editing a remote host" do
      @resource_app.options.stubs(:[]).with(:edit).returns(true)
      @resource_app.host = 'host'

      lambda { @resource_app.main }.should raise_error(RuntimeError, "You cannot edit a remote host")
    end

    it "should raise an error if the type is not found" do
      Puppet::Type.stubs(:type).returns(nil)

      lambda { @resource_app.main }.should raise_error(RuntimeError, 'Could not find type mytype')
    end

    describe "with a host" do
      before :each do
        @resource_app.stubs(:puts)
        @resource_app.host = 'host'

        Puppet::Resource.indirection.stubs(:find  ).never
        Puppet::Resource.indirection.stubs(:search).never
        Puppet::Resource.indirection.stubs(:save  ).never
      end

      it "should search for resources" do
        @resource_app.command_line.stubs(:args).returns(['type'])
        Puppet::Resource.indirection.expects(:search).with('https://host:8139/production/resources/type/', {}).returns([])
        @resource_app.main
      end

      it "should describe the given resource" do
        @resource_app.command_line.stubs(:args).returns(['type', 'name'])
        Puppet::Resource.indirection.expects(:find).with('https://host:8139/production/resources/type/name').returns(@res)
        @resource_app.main
      end

      it "should add given parameters to the object" do
        @resource_app.command_line.stubs(:args).returns(['type','name','param=temp'])

        Puppet::Resource.indirection.expects(:save).
          with(@res, 'https://host:8139/production/resources/type/name').
          returns([@res, @report])
        Puppet::Resource.expects(:new).with('type', 'name', :parameters => {'param' => 'temp'}).returns(@res)

        @resource_app.main
      end
    end

    describe "without a host" do
      before :each do
        @resource_app.stubs(:puts)
        @resource_app.host = nil

        Puppet::Resource.indirection.stubs(:find  ).never
        Puppet::Resource.indirection.stubs(:search).never
        Puppet::Resource.indirection.stubs(:save  ).never
      end

      it "should search for resources" do
        Puppet::Resource.indirection.expects(:search).with('mytype/', {}).returns([])
        @resource_app.main
      end

      it "should describe the given resource" do
        @resource_app.command_line.stubs(:args).returns(['type','name'])
        Puppet::Resource.indirection.expects(:find).with('type/name').returns(@res)
        @resource_app.main
      end

      it "should add given parameters to the object" do
        @resource_app.command_line.stubs(:args).returns(['type','name','param=temp'])

        Puppet::Resource.indirection.expects(:save).with(@res, 'type/name').returns([@res, @report])
        Puppet::Resource.expects(:new).with('type', 'name', :parameters => {'param' => 'temp'}).returns(@res)

        @resource_app.main
      end
    end
  end

  describe "when handling file type" do
    before :each do
      Facter.stubs(:loadfacts)
      @resource_app.preinit
    end

    it "should raise an exception if no file specified" do
      @resource_app.command_line.stubs(:args).returns(['file'])

      lambda { @resource_app.main }.should raise_error(RuntimeError, /Listing all file instances is not supported/)
    end

    it "should output a file resource when given a file path" do
      path = File.expand_path('/etc')
      res = Puppet::Type.type(:file).new(:path => path).to_resource
      Puppet::Resource.indirection.expects(:find).returns(res)

      @resource_app.command_line.stubs(:args).returns(['file', path])
      @resource_app.expects(:puts).with do |args|
        args.should =~ /file \{ '#{Regexp.escape(path)}'/m
      end

      @resource_app.main
    end
  end
end
