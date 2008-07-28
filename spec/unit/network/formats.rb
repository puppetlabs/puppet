#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/formats'

describe "Puppet Network Format" do
    it "should include a yaml format" do
        Puppet::Network::FormatHandler.format(:yaml).should_not be_nil
    end

    describe "yaml" do
        it "should have its mime type set to text/yaml" do
            Puppet::Network::FormatHandler.format(:yaml).mime.should == "text/yaml"
        end
    end

    it "should include a marshal format" do
        Puppet::Network::FormatHandler.format(:marshal).should_not be_nil
    end

    describe "marshal" do
        it "should have its mime type set to text/marshal" do
            Puppet::Network::FormatHandler.format(:marshal).mime.should == "text/marshal"
        end
    end
end
