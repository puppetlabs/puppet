#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/provider/naginator'

describe Puppet::Provider::Naginator do
  before do
    @resource_type = stub 'resource_type', :name => :nagios_test
    @class = Class.new(Puppet::Provider::Naginator)

    @class.stubs(:resource_type).returns @resource_type
  end

  it "should be able to look up the associated Nagios type" do
    nagios_type = mock "nagios_type"
    nagios_type.stubs :attr_accessor
    Nagios::Base.expects(:type).with(:test).returns nagios_type

    @class.nagios_type.should equal(nagios_type)
  end

  it "should use the Nagios type to determine whether an attribute is valid" do
    nagios_type = mock "nagios_type"
    nagios_type.stubs :attr_accessor
    Nagios::Base.expects(:type).with(:test).returns nagios_type

    nagios_type.expects(:parameters).returns [:foo, :bar]

    @class.valid_attr?(:test, :foo).should be_true
  end

  it "should use Naginator to parse configuration snippets" do
    parser = mock 'parser'
    parser.expects(:parse).with("my text").returns "my instances"
    Nagios::Parser.expects(:new).returns(parser)

    @class.parse("my text").should == "my instances"
  end

  it "should join Nagios::Base records with '\\n' when asked to convert them to text" do
    @class.expects(:header).returns "myheader\n"

    @class.to_file([:one, :two]).should == "myheader\none\ntwo"
  end

  it "should be able to prefetch instance from configuration files" do
    @class.should respond_to(:prefetch)
  end

  it "should be able to generate a list of instances" do
    @class.should respond_to(:instances)
  end

  it "should never skip records" do
    @class.should_not be_skip_record("foo")
  end
end
