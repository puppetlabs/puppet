#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/application/interface_base'
require 'puppet/application/interface_base'

base_interface = Puppet::Interface.new(:basetest)
class Puppet::Application::InterfaceBase::Basetest < Puppet::Application::InterfaceBase
end

describe Puppet::Application::InterfaceBase do
  before do
    @app = Puppet::Application::InterfaceBase::Basetest.new
    @app.stubs(:interface).returns base_interface
    @app.stubs(:exit)
    @app.stubs(:puts)
    Puppet::Util::Log.stubs(:newdestination)
  end

  describe "when calling main" do
    before do
      @app.verb = :find
      @app.arguments = ["myname", "myarg"]
      @app.interface.stubs(:find)
    end

    it "should send the specified verb and name to the interface" do
      @app.interface.expects(:find).with("myname", "myarg")

      @app.main
    end

    it "should use its render method to render any result"

    it "should exit with the current exit code"
  end

  describe "during setup" do
    before do
      @app.command_line.stubs(:args).returns(["find", "myname", "myarg"])
      @app.stubs(:validate)
    end

    it "should set the verb from the command line arguments" do
      @app.setup
      @app.verb.should == "find"
    end

    it "should make sure arguments are an array" do
      @app.command_line.stubs(:args).returns(["find", "myname", "myarg"])
      @app.setup
      @app.arguments.should == ["myname", "myarg"]
    end

    it "should set the options on the interface" do
      @app.options[:foo] = "bar"
      @app.setup

      @app.interface.options.should == @app.options
    end
  end
end
