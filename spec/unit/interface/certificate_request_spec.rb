#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/interface/certificate_request'

describe Puppet::Interface::CertificateRequest do
  before do
    @interface = Puppet::Interface::CertificateRequest
  end

  it "should be a subclass of 'Indirection'" do
    @interface.should be_instance_of(Puppet::Interface::Indirector)
  end

  it "should refer to the 'certificate_request' indirection" do
    @interface.indirection.name.should == :certificate_request
  end

  [:find, :save, :search, :save].each do |method|
    it "should have  #{method} action defined" do
      @interface.should be_action(method)
    end
  end
end
