#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/interface/facts'

describe Puppet::Interface::Facts do
  before do
    @interface = Puppet::Interface::Facts
  end

  it "should define an 'upload' fact" do
    @interface.should be_action(:upload)
  end

  it "should set its default format to :yaml" do
    @interface.default_format.should == :yaml
  end

  describe "when uploading" do
    it "should set the terminus_class to :facter"

    it "should set the cach_eclass to :rest"

    it "should find the current certname"
  end
end
