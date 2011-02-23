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
    @app.stubs(:exit)
    @app.stubs(:puts)
  end

  describe "when calling main" do
    before do
      @app.verb = :find
      @app.name = "myname"
      @app.arguments = "myarg"
      @app.interface.stubs(:find)
    end

    it "should send the specified verb and name to the interface" do
      @app.interface.expects(:find).with("myname", "myarg")

      @app.main
    end

    it "should use its render method to render any result"

    it "should exit with the current exit code"
  end
end
