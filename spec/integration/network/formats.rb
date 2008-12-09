#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/formats'

describe Puppet::Network::FormatHandler.format(:s) do
    before do
        @format = Puppet::Network::FormatHandler.format(:s)
    end

    it "should support certificates" do
        @format.should be_supported(Puppet::SSL::Certificate)
    end

    it "should not support catalogs" do
        @format.should_not be_supported(Puppet::Resource::Catalog)
    end
end
