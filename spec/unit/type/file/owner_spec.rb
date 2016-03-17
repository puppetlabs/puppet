#! /usr/bin/env ruby

require 'spec_helper'

describe Puppet::Type.type(:file).attrclass(:owner) do
  include PuppetSpec::Files

  let(:path) { tmpfile('mode_spec') }
  let(:resource) { Puppet::Type.type(:file).new :path => path, :owner => 'joeuser' }
  let(:owner) { resource.property(:owner) }

  before :each do
    Puppet.features.stubs(:root?).returns(true)
  end

  describe "#insync?" do
    before :each do
      resource[:owner] = ['foo', 'bar']

      resource.provider.stubs(:name2uid).with('foo').returns 1001
      resource.provider.stubs(:name2uid).with('bar').returns 1002
    end

    it "should fail if an owner's id can't be found by name" do
      resource.provider.stubs(:name2uid).returns nil

      expect { owner.insync?(5) }.to raise_error(/Could not find user foo/)
    end

    it "should use the id for comparisons, not the name" do
      owner.insync?('foo').should be_false
    end

    it "should return true if the current owner is one of the desired owners" do
      owner.insync?(1001).should be_true
    end

    it "should return false if the current owner is not one of the desired owners" do
      owner.insync?(1003).should be_false
    end
  end

  %w[is_to_s should_to_s].each do |prop_to_s|
    describe "##{prop_to_s}" do
      it "should use the name of the user if it can find it" do
        resource.provider.stubs(:uid2name).with(1001).returns 'foo'

        owner.send(prop_to_s, 1001).should == 'foo'
      end

      it "should use the id of the user if it can't" do
        resource.provider.stubs(:uid2name).with(1001).returns nil

        owner.send(prop_to_s, 1001).should == 1001
      end
    end
  end
end
