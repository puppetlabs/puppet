#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/file_serving/mount/tasks'

describe Puppet::FileServing::Mount::Tasks do
  before do
    @mount = Puppet::FileServing::Mount::Tasks.new("tasks")

    @environment = stub 'environment', :module => nil
    @request = stub 'request', :environment => @environment
  end

  describe "when finding task files" do
    it "should fail if no task is specified" do
      expect { @mount.find("", @request) }.to raise_error(/No task specified/)
    end

    it "should use the request's environment to find the module" do
      mod_name = 'foo'
      @environment.expects(:module).with(mod_name)

      @mount.find(mod_name, @request)
    end

    it "should use the first segment of the request's path as the module name" do
      @environment.expects(:module).with("foo")
      @mount.find("foo/bartask", @request)
    end

    it "should return nil if the module in the path doesn't exist" do
      @environment.expects(:module).with("foo").returns(nil)
      expect(@mount.find("foo/bartask", @request)).to be_nil
    end

    it "should return the file path from the module" do
      mod = mock('module')
      mod.expects(:task_file).with("bartask").returns("mocked")
      @environment.expects(:module).with("foo").returns(mod)
      expect(@mount.find("foo/bartask", @request)).to eq("mocked")
    end
  end

  describe "when searching for task files" do
    it "should fail if no module is specified" do
      expect { @mount.search("", @request) }.to raise_error(/No task specified/)
    end

    it "should use the request's environment to find the module" do
      mod_name = 'foo'
      @environment.expects(:module).with(mod_name)

      @mount.search(mod_name, @request)
    end

    it "should use the first segment of the request's path as the module name" do
      @environment.expects(:module).with("foo")
      @mount.search("foo/bartask", @request)
    end

    it "should return nil if the module in the path doesn't exist" do
      @environment.expects(:module).with("foo").returns(nil)
      expect(@mount.search("foo/bartask", @request)).to be_nil
    end

    it "should return the file path from the module" do
      mod = mock('module')
      mod.expects(:task_file).with("bartask").returns("mocked")
      @environment.expects(:module).with("foo").returns(mod)
      expect(@mount.search("foo/bartask", @request)).to eq(["mocked"])
    end
  end
end
