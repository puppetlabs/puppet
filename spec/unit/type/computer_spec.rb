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
    computer.new(:name => "bar").should_not be_nil
  end

  properties = [:en_address, :ip_address]
  params = [:name]

  properties.each do |property|
    it "should have a #{property} property" do
      computer.attrclass(property).ancestors.should be_include(Puppet::Property)
    end

    it "should have documentation for its #{property} property" do
      computer.attrclass(property).doc.should be_instance_of(String)
    end

    it "should accept :absent as a value" do
      prop = computer.attrclass(property).new(:resource => @resource)
      prop.should = :absent
      prop.should.must == :absent
    end
  end

  params.each do |param|
    it "should have a #{param} parameter" do
      computer.attrclass(param).ancestors.should be_include(Puppet::Parameter)
    end

    it "should have documentation for its #{param} parameter" do
      computer.attrclass(param).doc.should be_instance_of(String)
    end
  end

  describe "default values" do
    before do
      provider_class = computer.provider(computer.providers[0])
      computer.expects(:defaultprovider).returns provider_class
    end

    it "should be nil for en_address" do
      computer.new(:name => :en_address)[:en_address].should == nil
    end

    it "should be nil for ip_address" do
      computer.new(:name => :ip_address)[:ip_address].should == nil
    end
  end

  describe "when managing the ensure property" do
    it "should support a :present value" do
      lambda { @ensure.should = :present }.should_not raise_error
    end

    it "should support an :absent value" do
      lambda { @ensure.should = :absent }.should_not raise_error
    end
  end
end
