#! /usr/bin/env ruby
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
    it { is_expected.to be_action :find }
  end
end
