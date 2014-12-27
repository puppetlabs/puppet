#! /usr/bin/env ruby
require 'spec_helper'

computer = Puppet::Type.type(:computer)

describe Puppet::Type.type(:computer), " when checking computer objects" do
  before do
    provider_class = Puppet::Type::Computer.provider(Puppet::Type::Computer.providers[0])
    Puppet::Type::Computer.expects(:defaultprovider).returns provider_class

          @resource = Puppet::Type::Computer.new(
                
            :name => "puppetcomputertest",
            :en_address => "aa:bb:cc:dd:ee:ff",
        
            :ip_address => "1.2.3.4")
    @properties = {}
    @ensure = Puppet::Type::Computer.attrclass(:ensure).new(:resource => @resource)
  end

  it "should be able to create an instance" do
    provider_class = Puppet::Type::Computer.provider(Puppet::Type::Computer.providers[0])
    Puppet::Type::Computer.expects(:defaultprovider).returns provider_class
    expect(computer.new(:name => "bar")).not_to be_nil
  end

  properties = [:en_address, :ip_address]
  params = [:name]

  properties.each do |property|
    it "should have a #{property} property" do
      expect(computer.attrclass(property).ancestors).to be_include(Puppet::Property)
    end

    it "should have documentation for its #{property} property" do
      expect(computer.attrclass(property).doc).to be_instance_of(String)
    end

    it "should accept :absent as a value" do
      prop = computer.attrclass(property).new(:resource => @resource)
      prop.should = :absent
      expect(prop.should).to eq(:absent)
    end
  end

  params.each do |param|
    it "should have a #{param} parameter" do
      expect(computer.attrclass(param).ancestors).to be_include(Puppet::Parameter)
    end

    it "should have documentation for its #{param} parameter" do
      expect(computer.attrclass(param).doc).to be_instance_of(String)
    end
  end

  describe "default values" do
    before do
      provider_class = computer.provider(computer.providers[0])
      computer.expects(:defaultprovider).returns provider_class
    end

    it "should be nil for en_address" do
      expect(computer.new(:name => :en_address)[:en_address]).to eq(nil)
    end

    it "should be nil for ip_address" do
      expect(computer.new(:name => :ip_address)[:ip_address]).to eq(nil)
    end
  end

  describe "when managing the ensure property" do
    it "should support a :present value" do
      expect { @ensure.should = :present }.not_to raise_error
    end

    it "should support an :absent value" do
      expect { @ensure.should = :absent }.not_to raise_error
    end
  end
end
