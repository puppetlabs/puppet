require 'spec_helper'

require 'puppet/file_serving/configuration'

describe Puppet::FileServing::Configuration do
  include PuppetSpec::Files

  before :each do
    @path = make_absolute("/path/to/configuration/file.conf")
    Puppet[:trace] = false
    Puppet[:fileserverconfig] = @path
  end

  after :each do
    Puppet::FileServing::Configuration.instance_variable_set(:@configuration, nil)
  end

  it "should make :new a private method" do
    expect { Puppet::FileServing::Configuration.new }.to raise_error(NoMethodError, /private method `new' called/)
  end

  it "should return the same configuration each time 'configuration' is called" do
    expect(Puppet::FileServing::Configuration.configuration).to equal(Puppet::FileServing::Configuration.configuration)
  end

  describe "when initializing" do
    it "should work without a configuration file" do
      allow(Puppet::FileSystem).to receive(:exist?).with(@path).and_return(false)
      expect { Puppet::FileServing::Configuration.configuration }.to_not raise_error
    end

    it "should parse the configuration file if present" do
      allow(Puppet::FileSystem).to receive(:exist?).with(@path).and_return(true)
      @parser = double('parser')
      expect(@parser).to receive(:parse).and_return({})
      allow(Puppet::FileServing::Configuration::Parser).to receive(:new).and_return(@parser)
      Puppet::FileServing::Configuration.configuration
    end

    it "should determine the path to the configuration file from the Puppet settings" do
      Puppet::FileServing::Configuration.configuration
    end
  end

  describe "when parsing the configuration file" do
    before do
      allow(Puppet::FileSystem).to receive(:exist?).with(@path).and_return(true)
      @parser = double('parser')
      allow(Puppet::FileServing::Configuration::Parser).to receive(:new).and_return(@parser)
    end

    it "should set the mount list to the results of parsing" do
      expect(@parser).to receive(:parse).and_return("one" => double("mount"))
      config = Puppet::FileServing::Configuration.configuration
      expect(config.mounted?("one")).to be_truthy
    end

    it "should not raise exceptions" do
      expect(@parser).to receive(:parse).and_raise(ArgumentError)
      expect { Puppet::FileServing::Configuration.configuration }.to_not raise_error
    end

    it "should replace the existing mount list with the results of reparsing" do
      expect(@parser).to receive(:parse).and_return("one" => double("mount"))
      config = Puppet::FileServing::Configuration.configuration
      expect(config.mounted?("one")).to be_truthy
      # Now parse again
      expect(@parser).to receive(:parse).and_return("two" => double('other'))
      config.send(:readconfig, false)
      expect(config.mounted?("one")).to be_falsey
      expect(config.mounted?("two")).to be_truthy
    end

    it "should not replace the mount list until the file is entirely parsed successfully" do
      expect(@parser).to receive(:parse).and_return("one" => double("mount"))
      expect(@parser).to receive(:parse).and_raise(ArgumentError)
      config = Puppet::FileServing::Configuration.configuration
      # Now parse again, so the exception gets thrown
      config.send(:readconfig, false)
      expect(config.mounted?("one")).to be_truthy
    end

    it "should add modules, plugins, and tasks mounts even if the file does not exist" do
      expect(Puppet::FileSystem).to receive(:exist?).and_return(false) # the file doesn't exist
      config = Puppet::FileServing::Configuration.configuration
      expect(config.mounted?("modules")).to be_truthy
      expect(config.mounted?("plugins")).to be_truthy
      expect(config.mounted?("tasks")).to be_truthy
    end

    it "should allow all access to modules, plugins, and tasks if no fileserver.conf exists" do
      expect(Puppet::FileSystem).to receive(:exist?).and_return(false) # the file doesn't exist
      modules = double('modules')
      allow(Puppet::FileServing::Mount::Modules).to receive(:new).and_return(modules)

      plugins = double('plugins')
      allow(Puppet::FileServing::Mount::Plugins).to receive(:new).and_return(plugins)

      tasks = double('tasks')
      allow(Puppet::FileServing::Mount::Tasks).to receive(:new).and_return(tasks)

      Puppet::FileServing::Configuration.configuration
    end

    it "should not allow access from all to modules, plugins, and tasks if the fileserver.conf provided some rules" do
      expect(Puppet::FileSystem).to receive(:exist?).and_return(false) # the file doesn't exist

      modules = double('modules')
      allow(Puppet::FileServing::Mount::Modules).to receive(:new).and_return(modules)

      plugins = double('plugins')
      allow(Puppet::FileServing::Mount::Plugins).to receive(:new).and_return(plugins)

      tasks = double('tasks')
      allow(Puppet::FileServing::Mount::Tasks).to receive(:new).and_return(tasks)

      Puppet::FileServing::Configuration.configuration
    end

    it "should add modules, plugins, and tasks mounts even if they are not returned by the parser" do
      expect(@parser).to receive(:parse).and_return("one" => double("mount"))
      expect(Puppet::FileSystem).to receive(:exist?).and_return(true) # the file doesn't exist
      config = Puppet::FileServing::Configuration.configuration
      expect(config.mounted?("modules")).to be_truthy
      expect(config.mounted?("plugins")).to be_truthy
      expect(config.mounted?("tasks")).to be_truthy
    end
  end

  describe "when finding the specified mount" do
    it "should choose the named mount if one exists" do
      config = Puppet::FileServing::Configuration.configuration
      expect(config).to receive(:mounts).and_return("one" => "foo")
      expect(config.find_mount("one", double('env'))).to eq("foo")
    end

    it "should return nil if there is no such named mount" do
      config = Puppet::FileServing::Configuration.configuration

      env = double('environment')
      mount = double('mount')
      allow(config).to receive(:mounts).and_return("modules" => mount)

      expect(config.find_mount("foo", env)).to be_nil
    end
  end

  describe "#split_path" do
    let(:config) { Puppet::FileServing::Configuration.configuration }
    let(:request) { double('request', :key => "foo/bar/baz", :options => {}, :node => nil, :environment => double("env")) }

    before do
      allow(config).to receive(:find_mount)
    end

    it "should reread the configuration" do
      expect(config).to receive(:readconfig)

      config.split_path(request)
    end

    it "should treat the first field of the URI path as the mount name" do
      expect(config).to receive(:find_mount).with("foo", anything)

      config.split_path(request)
    end

    it "should fail if the mount name is not alpha-numeric" do
      expect(request).to receive(:key).and_return("foo&bar/asdf")

      expect { config.split_path(request) }.to raise_error(ArgumentError)
    end

    it "should support dashes in the mount name" do
      expect(request).to receive(:key).and_return("foo-bar/asdf")

      expect { config.split_path(request) }.to_not raise_error
    end

    it "should use the mount name and environment to find the mount" do
      expect(config).to receive(:find_mount).with("foo", request.environment)
      allow(request).to receive(:node).and_return("mynode")

      config.split_path(request)
    end

    it "should return nil if the mount cannot be found" do
      expect(config).to receive(:find_mount).and_return(nil)

      expect(config.split_path(request)).to be_nil
    end

    it "should return the mount and the relative path if the mount is found" do
      mount = double('mount', :name => "foo")
      expect(config).to receive(:find_mount).and_return(mount)

      expect(config.split_path(request)).to eq([mount, "bar/baz"])
    end

    it "should remove any double slashes" do
      allow(request).to receive(:key).and_return("foo/bar//baz")
      mount = double('mount', :name => "foo")
      expect(config).to receive(:find_mount).and_return(mount)

      expect(config.split_path(request)).to eq([mount, "bar/baz"])
    end

    it "should fail if the path contains .." do
      allow(request).to receive(:key).and_return('module/foo/../../bar')

      expect do
        config.split_path(request)
      end.to raise_error(ArgumentError, /Invalid relative path/)
    end

    it "should return the relative path as nil if it is an empty string" do
      expect(request).to receive(:key).and_return("foo")
      mount = double('mount', :name => "foo")
      expect(config).to receive(:find_mount).and_return(mount)

      expect(config.split_path(request)).to eq([mount, nil])
    end

    it "should add 'modules/' to the relative path if the modules mount is used but not specified, for backward compatibility" do
      expect(request).to receive(:key).and_return("foo/bar")
      mount = double('mount', :name => "modules")
      expect(config).to receive(:find_mount).and_return(mount)

      expect(config.split_path(request)).to eq([mount, "foo/bar"])
    end
  end
end
