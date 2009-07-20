#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/certificate/rest'

describe Puppet::SSL::Certificate::Rest do
    before do
        @searcher = Puppet::SSL::Certificate::Rest.new
    end

    it "should be a sublcass of Puppet::Indirector::REST" do
        Puppet::SSL::Certificate::Rest.superclass.should equal(Puppet::Indirector::REST)
    end

    it "should set server_setting to :ca_server" do
        Puppet::SSL::Certificate::Rest.server_setting.should == :ca_server
    end

    it "should set port_setting to :ca_port" do
        Puppet::SSL::Certificate::Rest.port_setting.should == :ca_port
    end
end
