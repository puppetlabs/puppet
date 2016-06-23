#! /usr/bin/env ruby
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

  it { is_expected.to be_option :extra }

  it "should be able to return a list of indirections" do
    expect(Puppet::Indirector::Face.indirections).to be_include("catalog")
  end

  it "should return the sorted to_s list of terminus classes" do
    Puppet::Indirector::Terminus.expects(:terminus_classes).returns([
      :yaml,
      :compiler,
      :rest
   ])
    expect(Puppet::Indirector::Face.terminus_classes(:catalog)).to eq([
      'compiler',
      'rest',
      'yaml'
    ])
  end

  describe "as an instance" do
    it "should be able to determine its indirection" do
      # Loading actions here can get, um, complicated
      Puppet::Face.stubs(:load_actions)
      expect(Puppet::Indirector::Face.new(:catalog, '0.0.1').indirection).to equal(Puppet::Resource::Catalog.indirection)
    end
  end

  [:find, :search, :save, :destroy].each do |method|
    def params(method, options)
      if method == :save
        [nil, options]
      else
        [options]
      end
    end

    it "should define a '#{method}' action" do
      expect(Puppet::Indirector::Face).to be_action(method)
    end

    it "should call the indirection method with options when the '#{method}' action is invoked" do
      subject.indirection.expects(method).with(:test, *params(method, {}))
      subject.send(method, :test)
    end
    it "should forward passed options" do
      subject.indirection.expects(method).with(:test, *params(method, {'one'=>'1'}))
      subject.send(method, :test, :extra => {'one'=>'1'})
    end
  end

  it "should default key to certname for find action" do
    subject.indirection.expects(:find).with(Puppet[:certname], {'one'=>'1'})
    subject.send(:find, :extra => {'one'=>'1'})
  end

  it "should be able to override its indirection name" do
    subject.set_indirection_name :foo
    expect(subject.indirection_name).to eq(:foo)
  end

  it "should be able to set its terminus class" do
    subject.indirection.expects(:terminus_class=).with(:myterm)
    subject.set_terminus(:myterm)
  end

  it "should define a class-level 'info' action" do
    expect(Puppet::Indirector::Face).to be_action(:info)
  end
end
