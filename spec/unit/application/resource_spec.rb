require 'spec_helper'

require 'puppet/application/resource'
require 'puppet_spec/character_encoding'

describe Puppet::Application::Resource do
  include PuppetSpec::Files

  before :each do
    @resource_app = Puppet::Application[:resource]
    allow(Puppet::Util::Log).to receive(:newdestination)
  end

  describe "in preinit" do
    it "should include provider parameter by default" do
      @resource_app.preinit
      expect(@resource_app.extra_params).to eq([:provider])
    end
  end

  describe "when handling options" do
    [:debug, :verbose, :edit].each do |option|
      it "should store argument value when calling handle_#{option}" do
        expect(@resource_app.options).to receive(:[]=).with(option, 'arg')
        @resource_app.send("handle_#{option}".to_sym, 'arg')
      end
    end

    it "should load a display all types with types option" do
      type1 = double('type1', :name => :type1)
      type2 = double('type2', :name => :type2)
      allow(Puppet::Type).to receive(:loadall)
      allow(Puppet::Type).to receive(:eachtype).and_yield(type1).and_yield(type2)
      expect(@resource_app).to receive(:puts).with(['type1','type2'])
      expect { @resource_app.handle_types(nil) }.to exit_with 0
    end

    it "should add param to extra_params list" do
      @resource_app.extra_params = [ :param1 ]
      @resource_app.handle_param("whatever")

      expect(@resource_app.extra_params).to eq([ :param1, :whatever ])
    end

    it "should get a parameter in the printed data if extra_params are passed" do
      tty  = double("tty",  :tty? => true )
      path = tmpfile('testfile')
      command_line = Puppet::Util::CommandLine.new("puppet", [ 'resource', 'file', path ], tty )
      allow(@resource_app).to receive(:command_line).and_return(command_line)

      # provider is a parameter that should always be available
      @resource_app.extra_params = [ :provider ]

      expect {
        @resource_app.main
      }.to output(/provider\s+=>/).to_stdout
    end
  end

  describe "during setup" do
    before :each do
      allow(Puppet::Log).to receive(:newdestination)
    end

    it "should set console as the log destination" do
      expect(Puppet::Log).to receive(:newdestination).with(:console)

      @resource_app.setup
    end

    it "should set log level to debug if --debug was passed" do
      allow(@resource_app.options).to receive(:[]).with(:debug).and_return(true)
      @resource_app.setup
      expect(Puppet::Log.level).to eq(:debug)
    end

    it "should set log level to info if --verbose was passed" do
      allow(@resource_app.options).to receive(:[]).with(:debug).and_return(false)
      allow(@resource_app.options).to receive(:[]).with(:verbose).and_return(true)
      @resource_app.setup
      expect(Puppet::Log.level).to eq(:info)
    end
  end

  describe "when running" do
    before :each do
      @type = double('type', :properties => [])
      allow(@resource_app.command_line).to receive(:args).and_return(['mytype'])
      allow(Puppet::Type).to receive(:type).and_return(@type)

      @res = double("resource")
      allow(@res).to receive(:prune_parameters).and_return(@res)
      allow(@res).to receive(:to_manifest).and_return("resource")
      @report = double("report")

      allow(@resource_app).to receive(:puts)
    end

    it "should raise an error if no type is given" do
      allow(@resource_app.command_line).to receive(:args).and_return([])
      expect { @resource_app.main }.to raise_error(RuntimeError, "You must specify the type to display")
    end

    it "should raise an error if the type is not found" do
      allow(Puppet::Type).to receive(:type).and_return(nil)

      expect { @resource_app.main }.to raise_error(RuntimeError, 'Could not find type mytype')
    end

    it "should search for resources" do
      expect(Puppet::Resource.indirection).to receive(:search).with('mytype/', {}).and_return([])
      @resource_app.main
    end

    it "should describe the given resource" do
      allow(@resource_app.command_line).to receive(:args).and_return(['type','name'])
      expect(Puppet::Resource.indirection).to receive(:find).with('type/name').and_return(@res)
      @resource_app.main
    end

    before :each do
      allow(@res).to receive(:ref).and_return("type/name")
    end

    it "should add given parameters to the object" do
      allow(@resource_app.command_line).to receive(:args).and_return(['type','name','param=temp'])

      expect(Puppet::Resource.indirection).to receive(:save).with(@res, 'type/name').and_return([@res, @report])
      expect(Puppet::Resource).to receive(:new).with('type', 'name', {:parameters => {'param' => 'temp'}}).and_return(@res)

      resource_status = instance_double('Puppet::Resource::Status')
      allow(@report).to receive(:resource_statuses).and_return({'type/name' => resource_status})
      allow(resource_status).to receive(:failed?).and_return(false)
      @resource_app.main
    end
  end

  describe "when printing output" do
    it "should not emit puppet class tags when printing yaml" do
      Puppet::Type.newtype(:stringify) do
        ensurable
        newparam(:name, isnamevar: true)
        newproperty(:string)
      end

      Puppet::Type.type(:stringify).provide(:stringify) do
        def exists?
          true
        end

        def string
          Puppet::Util::Execution::ProcessOutput.new('test', 0)
        end

        def string=(value)
        end
      end

      @resource_app.options[:to_yaml] = true
      allow(@resource_app.command_line).to receive(:args).and_return(['stringify', 'hello', 'ensure=present', 'string=asd'])
      expect(@resource_app).to receive(:puts).with(<<~YAML)
      ---
      stringify:
        hello:
          ensure: present
          string: test
      YAML
      expect { @resource_app.main }.not_to raise_error
    end

    it "should ensure all values to be printed are in the external encoding" do
      resources = [
        Puppet::Type.type(:user).new(:name => "\u2603".force_encoding(Encoding::UTF_8)).to_resource,
        Puppet::Type.type(:user).new(:name => "Jos\xE9".force_encoding(Encoding::ISO_8859_1)).to_resource
      ]
      expect(Puppet::Resource.indirection).to receive(:search).with('user/', {}).and_return(resources)
      allow(@resource_app.command_line).to receive(:args).and_return(['user'])

      # All of our output should be in external encoding
      expect(@resource_app).to receive(:puts) { |args| expect(args.encoding).to eq(Encoding::ISO_8859_1) }

      # This would raise an error if we weren't handling it
      PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::ISO_8859_1) do
        expect { @resource_app.main }.not_to raise_error
      end
    end
  end

  describe "when handling file type" do
    before :each do
      allow(Facter).to receive(:loadfacts)
      @resource_app.preinit
    end

    it "should raise an exception if no file specified" do
      allow(@resource_app.command_line).to receive(:args).and_return(['file'])

      expect { @resource_app.main }.to raise_error(RuntimeError, /Listing all file instances is not supported/)
    end

    it "should output a file resource when given a file path" do
      path = File.expand_path('/etc')
      res = Puppet::Type.type(:file).new(:path => path).to_resource
      expect(Puppet::Resource.indirection).to receive(:find).and_return(res)

      allow(@resource_app.command_line).to receive(:args).and_return(['file', path])
      expect(@resource_app).to receive(:puts).with(/file \{ '#{Regexp.escape(path)}'/m)

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

      allow(@resource_app.command_line).to receive(:args).and_return(['testing', 'hello'])
      expect(@resource_app).to receive(:puts).with("testing { 'hello':\n}")
      expect { @resource_app.main }.not_to raise_error
    end
  end
end
