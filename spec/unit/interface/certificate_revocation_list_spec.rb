#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/interface/certificate_revocation_list'

describe Puppet::Interface.interface(:certificate_revocation_list) do
  before do
    @interface = Puppet::Interface.interface(:certificate_revocation_list)
  end

  it "should be a subclass of 'Indirection'" do
    @interface.should be_instance_of(Puppet::Interface::Indirector)
  end

  it "should refer to the 'certificate_revocation_list' indirection" do
    @interface.indirection.name.should == :certificate_revocation_list
  end

  [:find, :save, :search, :save].each do |method|
    it "should have  #{method} action defined" do
      @interface.should be_action(method)
    end
  end
end
