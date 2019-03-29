require 'spec_helper'

require 'puppet/provider/naginator'

describe Puppet::Provider::Naginator do
  before do
    @resource_type = double('resource_type', :name => :nagios_test)
    @class = Class.new(Puppet::Provider::Naginator)

    allow(@class).to receive(:resource_type).and_return(@resource_type)
  end

  it "should be able to look up the associated Nagios type" do
    nagios_type = double("nagios_type")
    allow(nagios_type).to receive(:attr_accessor)
    expect(Nagios::Base).to receive(:type).with(:test).and_return(nagios_type)

    expect(@class.nagios_type).to equal(nagios_type)
  end

  it "should use the Nagios type to determine whether an attribute is valid" do
    nagios_type = double("nagios_type")
    allow(nagios_type).to receive(:attr_accessor)
    expect(Nagios::Base).to receive(:type).with(:test).and_return(nagios_type)

    expect(nagios_type).to receive(:parameters).and_return([:foo, :bar])

    expect(@class.valid_attr?(:test, :foo)).to be_truthy
  end

  it "should use Naginator to parse configuration snippets" do
    parser = double('parser')
    expect(parser).to receive(:parse).with("my text").and_return("my instances")
    expect(Nagios::Parser).to receive(:new).and_return(parser)

    expect(@class.parse("my text")).to eq("my instances")
  end

  it "should join Nagios::Base records with '\\n' when asked to convert them to text" do
    expect(@class).to receive(:header).and_return("myheader\n")

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
