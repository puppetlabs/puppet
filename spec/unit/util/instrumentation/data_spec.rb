#! /usr/bin/env ruby

require 'spec_helper'
require 'matchers/json'
require 'puppet/util/instrumentation'
require 'puppet/util/instrumentation/data'

describe Puppet::Util::Instrumentation::Data do
  include JSONMatchers

  Puppet::Util::Instrumentation::Data

  before(:each) do
    @listener = stub 'listener', :name => "name"
    Puppet::Util::Instrumentation.stubs(:[]).with("name").returns(@listener)
  end

  it "should indirect instrumentation_data" do
    Puppet::Util::Instrumentation::Data.indirection.name.should == :instrumentation_data
  end

  it "should lookup the corresponding listener" do
    Puppet::Util::Instrumentation.expects(:[]).with("name").returns(@listener)
    Puppet::Util::Instrumentation::Data.new("name")
  end

  it "should error if the listener can not be found" do
    Puppet::Util::Instrumentation.expects(:[]).with("name").returns(nil)
    expect { Puppet::Util::Instrumentation::Data.new("name") }.to raise_error
  end

  it "should return pson data" do
    data = Puppet::Util::Instrumentation::Data.new("name")
    @listener.stubs(:data).returns({ :this_is_data  => "here also" })
    data.should set_json_attribute('name').to("name")
    data.should set_json_attribute('this_is_data').to("here also")
  end

  it "should not error if the underlying listener doesn't have data" do
    lambda { Puppet::Util::Instrumentation::Data.new("name").to_pson }.should_not raise_error
  end

  it "should return a hash containing data when unserializing from pson" do
    Puppet::Util::Instrumentation::Data.from_data_hash({:name => "name"}).should == {:name => "name"}
  end
end
