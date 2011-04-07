#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')

describe Puppet::Faces[:facts, '0.0.1'] do
  it "should define an 'upload' fact" do
    subject.should be_action(:upload)
  end

  it "should set its default format to :yaml" do
    subject.default_format.should == :yaml
  end

  describe "when uploading" do
    it "should set the terminus_class to :facter"

    it "should set the cach_eclass to :rest"

    it "should find the current certname"
  end
end
