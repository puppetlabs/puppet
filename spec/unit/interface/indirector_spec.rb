#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/interface/indirector'

describe Puppet::Interface::Indirector do
  before do
    @instance = Puppet::Interface::Indirector.new(:test, '0.0.1')

    @indirection = stub 'indirection', :name => :stub_indirection

    @instance.stubs(:indirection).returns @indirection
  end

  it "should be able to return a list of indirections" do
    Puppet::Interface::Indirector.indirections.should be_include("catalog")
  end

  it "should be able to return a list of terminuses for a given indirection" do
    Puppet::Interface::Indirector.terminus_classes(:catalog).should be_include("compiler")
  end

  describe "as an instance" do
    it "should be able to determine its indirection" do
      # Loading actions here an get, um, complicated
      Puppet::Interface.stubs(:load_actions)
      Puppet::Interface::Indirector.new(:catalog, '0.0.1').indirection.should equal(Puppet::Resource::Catalog.indirection)
    end
  end

  [:find, :search, :save, :destroy].each do |method|
    it "should define a '#{method}' action" do
      Puppet::Interface::Indirector.should be_action(method)
    end

    it "should just call the indirection method when the '#{method}' action is invoked" do
      @instance.indirection.expects(method).with(:test, "myargs")
      @instance.send(method, :test, "myargs")
    end
  end

  it "should be able to override its indirection name" do
    @instance.set_indirection_name :foo
    @instance.indirection_name.should == :foo
  end

  it "should be able to set its terminus class" do
    @instance.indirection.expects(:terminus_class=).with(:myterm)
    @instance.set_terminus(:myterm)
  end

  it "should define a class-level 'info' action" do
    Puppet::Interface::Indirector.should be_action(:info)
  end
end
