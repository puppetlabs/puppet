#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:selboolean), "when validating attributes" do
  [:name, :persistent].each do |param|
    it "should have a #{param} parameter" do
      Puppet::Type.type(:selboolean).attrtype(param).should == :param
    end
  end

  it "should have a value property" do
    Puppet::Type.type(:selboolean).attrtype(:value).should == :property
  end
end

describe Puppet::Type.type(:selboolean), "when validating values" do
  before do
    @class = Puppet::Type.type(:selboolean)

    @provider_class = stub 'provider_class', :name => "fake", :suitable? => true, :supports_parameter? => true
    @class.stubs(:defaultprovider).returns(@provider_class)
    @class.stubs(:provider).returns(@provider_class)

    @provider = stub 'provider', :class => @provider_class, :clear => nil
    @provider_class.stubs(:new).returns(@provider)
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

