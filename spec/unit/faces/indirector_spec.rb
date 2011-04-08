#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/faces/indirector'

describe Puppet::Faces::Indirector do
  subject do
    instance = Puppet::Faces::Indirector.new(:test, '0.0.1')
    indirection = stub('indirection',
                       :name => :stub_indirection,
                       :reset_terminus_class => nil)
    instance.stubs(:indirection).returns indirection
    instance
  end

  it "should be able to return a list of indirections" do
    Puppet::Faces::Indirector.indirections.should be_include("catalog")
  end

  it "should be able to return a list of terminuses for a given indirection" do
    Puppet::Faces::Indirector.terminus_classes(:catalog).should be_include("compiler")
  end

  describe "as an instance" do
    it "should be able to determine its indirection" do
      # Loading actions here an get, um, complicated
      Puppet::Faces.stubs(:load_actions)
      Puppet::Faces::Indirector.new(:catalog, '0.0.1').indirection.should equal(Puppet::Resource::Catalog.indirection)
    end
  end

  [:find, :search, :save, :destroy].each do |method|
    it "should define a '#{method}' action" do
      Puppet::Faces::Indirector.should be_action(method)
    end

    it "should call the indirection method with options when the '#{method}' action is invoked" do
      subject.indirection.expects(method).with(:test, "myargs", {})
      subject.send(method, :test, "myargs")
    end
    it "should forward passed options" do
      subject.indirection.expects(method).with(:test, "action", {'one'=>'1'})
      subject.send(method, :test, 'action', {'one'=>'1'})
    end
  end

  it "should be able to override its indirection name" do
    subject.set_indirection_name :foo
    subject.indirection_name.should == :foo
  end

  it "should be able to set its terminus class" do
    subject.indirection.expects(:terminus_class=).with(:myterm)
    subject.set_terminus(:myterm)
  end

  it "should define a class-level 'info' action" do
    Puppet::Faces::Indirector.should be_action(:info)
  end
end
