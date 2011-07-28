#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:exec).provider(:shell)

describe provider_class, :unless => Puppet.features.microsoft_windows? do
  before :each do
    @resource = Puppet::Resource.new(:exec, 'foo')
    @provider = provider_class.new(@resource)
  end

  describe "#run" do
    it "should be able to run builtin shell commands" do
      output, status = @provider.run("if [ 1 = 1 ]; then echo 'blah'; fi")
      status.exitstatus.should == 0
      output.should == "blah\n"
    end

    it "should be able to run commands with single quotes in them" do
      output, status = @provider.run("echo 'foo  bar'")
      status.exitstatus.should == 0
      output.should == "foo  bar\n"
    end

    it "should be able to run commands with double quotes in them" do
      output, status = @provider.run('echo "foo  bar"')
      status.exitstatus.should == 0
      output.should == "foo  bar\n"
    end

    it "should be able to run multiple commands separated by a semicolon" do
      output, status = @provider.run("echo 'foo' ; echo 'bar'")
      status.exitstatus.should == 0
      output.should == "foo\nbar\n"
    end

    it "should be able to read values from the environment parameter" do
      @resource[:environment] = "FOO=bar"
      output, status = @provider.run("echo $FOO")
      status.exitstatus.should == 0
      output.should == "bar\n"
    end
  end

  describe "#validatecmd" do
    it "should always return true because builtins don't need path or to be fully qualified" do
      @provider.validatecmd('whateverdoesntmatter').should == true
    end
  end
end
