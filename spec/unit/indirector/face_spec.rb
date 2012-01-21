#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/indirector/face'

describe Puppet::Indirector::Face do
  subject do
    instance = Puppet::Indirector::Face.new(:test, '0.0.1')
    indirection = stub('indirection',
                       :name => :stub_indirection,
                       :reset_terminus_class => nil)
    instance.stubs(:indirection).returns indirection
    instance
  end

  it { should be_option :extra }

  it "should be able to return a list of indirections" do
    Puppet::Indirector::Face.indirections.should be_include("catalog")
  end

  it "should return the sorted to_s list of terminus classes" do
    Puppet::Indirector::Terminus.expects(:terminus_classes).returns([
      :yaml,
      :compiler,
      :rest
   ])
    Puppet::Indirector::Face.terminus_classes(:catalog).should == [
      'compiler',
      'rest',
      'yaml'
    ]
  end

  describe "as an instance" do
    it "should be able to determine its indirection" do
      # Loading actions here an get, um, complicated
      Puppet::Face.stubs(:load_actions)
      Puppet::Indirector::Face.new(:catalog, '0.0.1').indirection.should equal(Puppet::Resource::Catalog.indirection)
    end
  end

  [:find, :search, :save, :destroy].each do |method|
    it "should define a '#{method}' action" do
      Puppet::Indirector::Face.should be_action(method)
    end

    it "should call the indirection method with options when the '#{method}' action is invoked" do
      subject.indirection.expects(method).with(:test, {})
      subject.send(method, :test)
    end
    it "should forward passed options" do
      subject.indirection.expects(method).with(:test, {'one'=>'1'})
      subject.send(method, :test, :extra => {'one'=>'1'})
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
    Puppet::Indirector::Face.should be_action(:info)
  end
end
