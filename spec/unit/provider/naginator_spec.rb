#! /usr/bin/env ruby
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

    expect(@class.nagios_type).to equal(nagios_type)
  end

  it "should use the Nagios type to determine whether an attribute is valid" do
    nagios_type = mock "nagios_type"
    nagios_type.stubs :attr_accessor
    Nagios::Base.expects(:type).with(:test).returns nagios_type

    nagios_type.expects(:parameters).returns [:foo, :bar]

    expect(@class.valid_attr?(:test, :foo)).to be_truthy
  end

  it "should use Naginator to parse configuration snippets" do
    parser = mock 'parser'
    parser.expects(:parse).with("my text").returns "my instances"
    Nagios::Parser.expects(:new).returns(parser)

    expect(@class.parse("my text")).to eq("my instances")
  end

  it "should join Nagios::Base records with '\\n' when asked to convert them to text" do
    @class.expects(:header).returns "myheader\n"

    expect(@class.to_file([:one, :two])).to eq("myheader\none\ntwo")
  end

  it "should be able to prefetch instance from configuration files" do
    expect(@class).to respond_to(:prefetch)
  end

  it "should be able to generate a list of instances" do
    expect(@class).to respond_to(:instances)
  end

  it "should never skip records" do
    expect(@class).not_to be_skip_record("foo")
  end
end

describe Nagios::Base do
  it "should not turn set parameters into arrays #17871" do
    obj = Nagios::Base.create('host')
    obj.host_name = "my_hostname"
    expect(obj.host_name).to eq("my_hostname")
  end
end

describe Nagios::Parser do
  include PuppetSpec::Files

  subject do
    described_class.new
  end

  let(:config) { File.new( my_fixture('define_empty_param') ).read }

  it "should handle empty parameter values" do
    expect { subject.parse(config) }.to_not raise_error
  end
end
