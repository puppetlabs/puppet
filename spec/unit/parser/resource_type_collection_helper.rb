#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/parser/resource_type_collection_helper'

class RTCHelperTester
    include Puppet::Parser::ResourceTypeCollectionHelper
end

describe Puppet::Parser::ResourceTypeCollectionHelper do
    before do
        @helper = RTCHelperTester.new
    end

    it "should use its current environment to retrieve the known resource type collection" do
        env = stub 'environment'
        @helper.expects(:environment).returns env

        rtc = stub 'known_resource_types'
        env.expects(:known_resource_types).returns  rtc

        @helper.known_resource_types.should equal(rtc)
    end
end
