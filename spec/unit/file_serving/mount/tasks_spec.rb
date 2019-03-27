require 'spec_helper'
require 'puppet/file_serving/mount/tasks'

describe Puppet::FileServing::Mount::Tasks do
  before do
    @mount = Puppet::FileServing::Mount::Tasks.new("tasks")

    @environment = double('environment', :module => nil)
    @request = double('request', :environment => @environment)
  end

  describe "when finding task files" do
    it "should fail if no task is specified" do
      expect { @mount.find("", @request) }.to raise_error(/No task specified/)
    end

    it "should use the request's environment to find the module" do
      mod_name = 'foo'
      expect(@environment).to receive(:module).with(mod_name)

      @mount.find(mod_name, @request)
    end

    it "should use the first segment of the request's path as the module name" do
      expect(@environment).to receive(:module).with("foo")
      @mount.find("foo/bartask", @request)
    end

    it "should return nil if the module in the path doesn't exist" do
      expect(@environment).to receive(:module).with("foo").and_return(nil)
      expect(@mount.find("foo/bartask", @request)).to be_nil
    end

    it "should return the file path from the module" do
      mod = double('module')
      expect(mod).to receive(:task_file).with("bartask").and_return("mocked")
      expect(@environment).to receive(:module).with("foo").and_return(mod)
      expect(@mount.find("foo/bartask", @request)).to eq("mocked")
    end
  end

  describe "when searching for task files" do
    it "should fail if no module is specified" do
      expect { @mount.search("", @request) }.to raise_error(/No task specified/)
    end

    it "should use the request's environment to find the module" do
      mod_name = 'foo'
      expect(@environment).to receive(:module).with(mod_name)

      @mount.search(mod_name, @request)
    end

    it "should use the first segment of the request's path as the module name" do
      expect(@environment).to receive(:module).with("foo")
      @mount.search("foo/bartask", @request)
    end

    it "should return nil if the module in the path doesn't exist" do
      expect(@environment).to receive(:module).with("foo").and_return(nil)
      expect(@mount.search("foo/bartask", @request)).to be_nil
    end

    it "should return the file path from the module" do
      mod = double('module')
      expect(mod).to receive(:task_file).with("bartask").and_return("mocked")
      expect(@environment).to receive(:module).with("foo").and_return(mod)
      expect(@mount.search("foo/bartask", @request)).to eq(["mocked"])
    end
  end
end
