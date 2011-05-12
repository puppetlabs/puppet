#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:config, '0.0.1'] do
  it "should use Settings#print_config_options when asked to print" do
    Puppet.settings.stubs(:puts)
    Puppet.settings.expects(:print_config_options)
    subject.print
  end

  it "should set 'configprint' to all desired values and call print_config_options when a specific value is provided" do
    Puppet.settings.stubs(:puts)
    Puppet.settings.expects(:print_config_options)
    subject.print("libdir", "ssldir")
    Puppet.settings[:configprint].should == "libdir,ssldir"
  end

  it "should always return nil" do
    Puppet.settings.stubs(:puts)
    Puppet.settings.expects(:print_config_options)
    subject.print("libdir").should be_nil
  end
end
