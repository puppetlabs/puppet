#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Face[:facts, '0.0.1'] do
  it "should define an 'upload' action" do
    subject.should be_action(:upload)
  end

  describe "when uploading" do
    it "should set the terminus_class to :facter"

    it "should set the cach_eclass to :rest"

    it "should find the current certname"
  end
end
