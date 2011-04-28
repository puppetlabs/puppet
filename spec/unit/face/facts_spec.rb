#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:facts, '0.0.1'] do
  it "should define an 'upload' action" do
    subject.should be_action(:upload)
  end

  describe "when uploading" do
    it "should set the terminus_class to :facter"
    it "should set the cache_class to :rest"
    it "should find the current certname"
  end

  describe "#find" do
    it { should be_action :find }

    it "should fail without a key" do
      expect { subject.find }.to raise_error ArgumentError, /wrong number of arguments/
    end
  end
end
