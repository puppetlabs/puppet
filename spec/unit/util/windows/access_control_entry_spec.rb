#!/usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/windows'

describe "Puppet::Util::Windows::AccessControlEntry", :if => Puppet.features.microsoft_windows? do
  let(:klass) { Puppet::Util::Windows::AccessControlEntry }
  let(:sid) { 'S-1-5-18' }
  let(:mask) { Puppet::Util::Windows::File::FILE_ALL_ACCESS }

  it "creates an access allowed ace" do
    ace = klass.new(sid, mask)

    ace.type.should == klass::ACCESS_ALLOWED_ACE_TYPE
  end

  it "creates an access denied ace" do
    ace = klass.new(sid, mask, 0, klass::ACCESS_DENIED_ACE_TYPE)

    ace.type.should == klass::ACCESS_DENIED_ACE_TYPE
  end

  it "creates a non-inherited ace by default" do
    ace = klass.new(sid, mask)

    ace.should_not be_inherited
  end

  it "creates an inherited ace" do
    ace = klass.new(sid, mask, klass::INHERITED_ACE)

    ace.should be_inherited
  end

  it "creates a non-inherit-only ace by default" do
    ace = klass.new(sid, mask)

    ace.should_not be_inherit_only
  end

  it "creates an inherit-only ace" do
    ace = klass.new(sid, mask, klass::INHERIT_ONLY_ACE)

    ace.should be_inherit_only
  end

  context "when comparing aces" do
    let(:ace1) { klass.new(sid, mask, klass::INHERIT_ONLY_ACE, klass::ACCESS_DENIED_ACE_TYPE) }
    let(:ace2) { klass.new(sid, mask, klass::INHERIT_ONLY_ACE, klass::ACCESS_DENIED_ACE_TYPE) }

    it "returns true if different objects have the same set of values" do
    ace1.should == ace2
    end

    it "returns false if different objects have different sets of values" do
      ace = klass.new(sid, mask)
      ace.should_not == ace1
    end

    it "returns true when testing if two objects are eql?" do
      ace1.eql?(ace2)
    end

    it "returns false when comparing object identity" do
      ace1.should_not be_equal(ace2)
    end
  end
end
