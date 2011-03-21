#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/interface/config'

describe Puppet::Interface::Config do
  before do
    @interface = Puppet::Interface::Config
  end

  it "should be a subclass of 'Indirection'" do
    @interface.should be_instance_of(Puppet::Interface)
  end

  it "should use Settings#print_config_options when asked to print" do
    Puppet.settings.stubs(:puts)
    Puppet.settings.expects(:print_config_options)
    @interface.print
  end

  it "should set 'configprint' to all desired values and call print_config_options when a specific value is provided" do
    Puppet.settings.stubs(:puts)
    Puppet.settings.expects(:print_config_options)
    @interface.print("libdir", "ssldir")
    Puppet.settings[:configprint].should == "libdir,ssldir"
  end
end
