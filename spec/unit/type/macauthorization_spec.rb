#! /usr/bin/env ruby
require 'spec_helper'

module Puppet::Util::Plist
end

macauth_type = Puppet::Type.type(:macauthorization)

describe Puppet::Type.type(:macauthorization), "when checking macauthorization objects" do

  before do
    authplist = {}
    authplist["rules"] = { "foorule" => "foo" }
    authplist["rights"] = { "fooright" => "foo" }
    provider_class = macauth_type.provider(macauth_type.providers[0])
    Puppet::Util::Plist.stubs(:parse_plist).with("/etc/authorization").returns(authplist)
    macauth_type.stubs(:defaultprovider).returns provider_class
    @resource = macauth_type.new(:name => 'foo')
  end

  describe "when validating attributes" do

    parameters = [:name,]
    properties = [:auth_type, :allow_root, :authenticate_user, :auth_class,
      :comment, :group, :k_of_n, :mechanisms, :rule,
      :session_owner, :shared, :timeout, :tries]

    parameters.each do |parameter|
      it "should have a #{parameter} parameter" do
        expect(macauth_type.attrclass(parameter).ancestors).to be_include(Puppet::Parameter)
      end

      it "should have documentation for its #{parameter} parameter" do
        expect(macauth_type.attrclass(parameter).doc).to be_instance_of(String)
      end
    end

    properties.each do |property|
      it "should have a #{property} property" do
        expect(macauth_type.attrclass(property).ancestors).to be_include(Puppet::Property)
      end

      it "should have documentation for its #{property} property" do
        expect(macauth_type.attrclass(property).doc).to be_instance_of(String)
      end
    end

  end

  describe "when validating properties" do

    it "should have a default provider inheriting from Puppet::Provider" do
      expect(macauth_type.defaultprovider.ancestors).to be_include(Puppet::Provider)
    end

    it "should be able to create an instance" do
      expect {
        macauth_type.new(:name => 'foo')
      }.not_to raise_error
    end

    it "should support :present as a value to :ensure" do
      expect {
        macauth_type.new(:name => "foo", :ensure => :present)
      }.not_to raise_error
    end

    it "should support :absent as a value to :ensure" do
      expect {
        macauth_type.new(:name => "foo", :ensure => :absent)
      }.not_to raise_error
    end

  end

  [:k_of_n, :timeout, :tries].each do |property|
    describe "when managing the #{property} property" do
      it "should convert number-looking strings into actual numbers" do
        prop = macauth_type.attrclass(property).new(:resource => @resource)
        prop.should = "300"
        expect(prop.should).to eq(300)
      end
      it "should support integers as a value" do
        prop = macauth_type.attrclass(property).new(:resource => @resource)
        prop.should = 300
        expect(prop.should).to eq(300)
      end
      it "should raise an error for non-integer values" do
        prop = macauth_type.attrclass(property).new(:resource => @resource)
        expect { prop.should = "foo" }.to raise_error(Puppet::Error)
      end
    end
  end

  [:allow_root, :authenticate_user, :session_owner, :shared].each do |property|
    describe "when managing the #{property} property" do
      it "should convert boolean-looking false strings into actual booleans" do
        prop = macauth_type.attrclass(property).new(:resource => @resource)
        prop.should = "false"
        expect(prop.should).to eq(:false)
      end
      it "should convert boolean-looking true strings into actual booleans" do
        prop = macauth_type.attrclass(property).new(:resource => @resource)
        prop.should = "true"
        expect(prop.should).to eq(:true)
      end
      it "should raise an error for non-boolean values" do
        prop = macauth_type.attrclass(property).new(:resource => @resource)
        expect { prop.should = "foo" }.to raise_error(Puppet::Error)
      end
    end
  end
end
