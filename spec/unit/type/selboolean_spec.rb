require 'spec_helper'

describe Puppet::Type.type(:selboolean), "when validating attributes" do
  [:name, :persistent].each do |param|
    it "should have a #{param} parameter" do
      expect(Puppet::Type.type(:selboolean).attrtype(param)).to eq(:param)
    end
  end

  it "should have a value property" do
    expect(Puppet::Type.type(:selboolean).attrtype(:value)).to eq(:property)
  end
end

describe Puppet::Type.type(:selboolean), "when validating values" do
  before do
    @class = Puppet::Type.type(:selboolean)

    @provider_class = double('provider_class', :name => "fake", :suitable? => true, :supports_parameter? => true)
    allow(@class).to receive(:defaultprovider).and_return(@provider_class)
    allow(@class).to receive(:provider).and_return(@provider_class)

    @provider = double('provider', :class => @provider_class, :clear => nil)
    allow(@provider_class).to receive(:new).and_return(@provider)
  end

  it "should support :on as a value to :value" do
    Puppet::Type.type(:selboolean).new(:name => "yay", :value => :on)
  end

  it "should support :off as a value to :value" do
    Puppet::Type.type(:selboolean).new(:name => "yay", :value => :off)
  end

  it "should support :true as a value to :persistent" do
    Puppet::Type.type(:selboolean).new(:name => "yay", :value => :on, :persistent => :true)
  end

  it "should support :false as a value to :persistent" do
    Puppet::Type.type(:selboolean).new(:name => "yay", :value => :on, :persistent => :false)
  end
end

