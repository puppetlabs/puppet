#!/usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/windows'

describe "Puppet::Util::Windows::AccessControlEntry", :if => Puppet.features.microsoft_windows? do
  let(:klass) { Puppet::Util::Windows::AccessControlEntry }
  let(:sid) { 'S-1-5-18' }
  let(:mask) { Puppet::Util::Windows::File::FILE_ALL_ACCESS }

  it "creates an access allowed ace" do
    ace = klass.new(sid, mask)

    expect(ace.type).to eq(klass::ACCESS_ALLOWED_ACE_TYPE)
  end

  it "creates an access denied ace" do
    ace = klass.new(sid, mask, 0, klass::ACCESS_DENIED_ACE_TYPE)

    expect(ace.type).to eq(klass::ACCESS_DENIED_ACE_TYPE)
  end

  it "creates a non-inherited ace by default" do
    ace = klass.new(sid, mask)

    expect(ace).not_to be_inherited
  end

  it "creates an inherited ace" do
    ace = klass.new(sid, mask, klass::INHERITED_ACE)

    expect(ace).to be_inherited
  end

  it "creates a non-inherit-only ace by default" do
    ace = klass.new(sid, mask)

    expect(ace).not_to be_inherit_only
  end

  it "creates an inherit-only ace" do
    ace = klass.new(sid, mask, klass::INHERIT_ONLY_ACE)

    expect(ace).to be_inherit_only
  end

  context "when comparing aces" do
    let(:ace1) { klass.new(sid, mask, klass::INHERIT_ONLY_ACE, klass::ACCESS_DENIED_ACE_TYPE) }
    let(:ace2) { klass.new(sid, mask, klass::INHERIT_ONLY_ACE, klass::ACCESS_DENIED_ACE_TYPE) }

    it "returns true if different objects have the same set of values" do
    expect(ace1).to eq(ace2)
    end

    it "returns false if different objects have different sets of values" do
      ace = klass.new(sid, mask)
      expect(ace).not_to eq(ace1)
    end

    it "returns true when testing if two objects are eql?" do
      ace1.eql?(ace2)
    end

    it "returns false when comparing object identity" do
      expect(ace1).not_to be_equal(ace2)
    end
  end
end
