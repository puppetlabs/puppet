#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/application/resource'
require 'puppet_spec/character_encoding'

describe Puppet::Application::Resource do
  include PuppetSpec::Files
  before :each do
    @resource_app = Puppet::Application[:resource]
    Puppet::Util::Log.stubs(:newdestination)
  end

  describe "in preinit" do
    it "should init extra_params to empty array" do
      @resource_app.preinit
      expect(@resource_app.extra_params).to eq([])
    end
  end

  describe "when handling options" do
    [:debug, :verbose, :edit].each do |option|
      it "should store argument value when calling handle_#{option}" do
        @resource_app.options.expects(:[]=).with(option, 'arg')
        @resource_app.send("handle_#{option}".to_sym, 'arg')
      end
    end

    it "should load a display all types with types option" do
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

      expect(@resource_app.extra_params).to eq([ :param1, :whatever ])
    end

    it "should get a parameter in the printed data if extra_params are passed" do
      tty  = stub("tty",  :tty? => true )
      path = tmpfile('testfile')
      command_line = Puppet::Util::CommandLine.new("puppet", [ 'resource', 'file', path ], tty )
      @resource_app.stubs(:command_line).returns command_line

      # provider is a parameter that should always be available
      @resource_app.extra_params = [ :provider ]

      expect { @resource_app.main }.to have_printed(/provider\s+=>/)
    end
  end

  describe "during setup" do
    before :each do
      Puppet::Log.stubs(:newdestination)
    end

    it "should set console as the log destination" do
      Puppet::Log.expects(:newdestination).with(:console)

      @resource_app.setup
    end

    it "should set log level to debug if --debug was passed" do
      @resource_app.options.stubs(:[]).with(:debug).returns(true)
      @resource_app.setup
      expect(Puppet::Log.level).to eq(:debug)
    end

    it "should set log level to info if --verbose was passed" do
      @resource_app.options.stubs(:[]).with(:debug).returns(false)
      @resource_app.options.stubs(:[]).with(:verbose).returns(true)
      @resource_app.setup
      expect(Puppet::Log.level).to eq(:info)
    end

  end

  describe "when running" do
    before :each do
      @type = stub_everything 'type', :properties => []
      @resource_app.command_line.stubs(:args).returns(['mytype'])
      Puppet::Type.stubs(:type).returns(@type)

      @res = stub_everything "resource"
      @res.stubs(:prune_parameters).returns(@res)
      @res.stubs(:to_manifest).returns("resource")
      @report = stub_everything "report"

      @resource_app.stubs(:puts)

      Puppet::Resource.indirection.stubs(:find  ).never
      Puppet::Resource.indirection.stubs(:search).never
      Puppet::Resource.indirection.stubs(:save  ).never
    end

    it "should raise an error if no type is given" do
      @resource_app.command_line.stubs(:args).returns([])
      expect { @resource_app.main }.to raise_error(RuntimeError, "You must specify the type to display")
    end

    it "should raise an error if the type is not found" do
      Puppet::Type.stubs(:type).returns(nil)

      expect { @resource_app.main }.to raise_error(RuntimeError, 'Could not find type mytype')
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

  describe "when printing output" do
    it "should ensure all values to be printed are in the external encoding" do
      resources = [
        Puppet::Type.type(:user).new(:name => "\u2603".force_encoding(Encoding::UTF_8)).to_resource,
        Puppet::Type.type(:user).new(:name => "Jos\xE9".force_encoding(Encoding::ISO_8859_1)).to_resource
      ]
      Puppet::Resource.indirection.expects(:search).with('user/', {}).returns(resources)
      @resource_app.command_line.stubs(:args).returns(['user'])

      # All of our output should be in external encoding
      @resource_app.expects(:puts).with { |args| expect(args.encoding).to eq(Encoding::ISO_8859_1) }

      # This would raise an error if we weren't handling it
      PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::ISO_8859_1) do
        expect { @resource_app.main }.not_to raise_error
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

      expect { @resource_app.main }.to raise_error(RuntimeError, /Listing all file instances is not supported/)
    end

    it "should output a file resource when given a file path" do
      path = File.expand_path('/etc')
      res = Puppet::Type.type(:file).new(:path => path).to_resource
      Puppet::Resource.indirection.expects(:find).returns(res)

      @resource_app.command_line.stubs(:args).returns(['file', path])
      @resource_app.expects(:puts).with do |args|
        expect(args).to match(/file \{ '#{Regexp.escape(path)}'/m)
      end

      @resource_app.main
    end
  end

  describe 'when handling a custom type' do
    it 'the Puppet::Pops::Loaders instance is available' do
      Puppet::Type.newtype(:testing) do
        newparam(:name) do
          isnamevar
        end
        def self.instances
          fail('Loader not found') unless Puppet::Pops::Loaders.find_loader(nil).is_a?(Puppet::Pops::Loader::Loader)
          @instances ||= [new(:name => name)]
        end
      end
      @resource_app.command_line.stubs(:args).returns(['testing', 'hello'])
      @resource_app.expects(:puts).with { |args| expect(args).to eql("testing { 'hello':\n}") }
      expect { @resource_app.main }.not_to raise_error
    end
  end
end
