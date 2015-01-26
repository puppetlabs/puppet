#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/resource/type_collection_helper'

class RTCHelperTester
  include Puppet::Resource::TypeCollectionHelper
end

describe Puppet::Resource::TypeCollectionHelper do
  before do
    @helper = RTCHelperTester.new
  end

  it "should use its current environment to retrieve the known resource type collection" do
    env = stub 'environment'
    @helper.expects(:environment).returns env

    rtc = stub 'known_resource_types'
    env.expects(:known_resource_types).returns  rtc

    expect(@helper.known_resource_types).to equal(rtc)
  end
end
