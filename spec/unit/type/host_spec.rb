#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

ssh_authorized_key = Puppet::Type.type(:ssh_authorized_key)

describe Puppet::Type.type(:host) do
  before do
    @class = Puppet::Type.type(:host)
    @catalog = Puppet::Resource::Catalog.new
  end

  it "should have :name be its namevar" do
    @class.key_attributes.should == [:name]
  end

  describe "when validating attributes" do
    [:name, :provider ].each do |param|
      it "should have a #{param} parameter" do
        @class.attrtype(param).should == :param
      end
    end

    [:ip, :target, :host_aliases, :comment, :ensure].each do |property|
      it "should have a #{property} property" do
        @class.attrtype(property).should == :property
      end
    end
  end

  describe "when validating values" do
    it "should support present as a value for ensure" do
      proc { @class.new(:name => "foo", :ensure => :present) }.should_not raise_error
    end

    it "should support absent as a value for ensure" do
      proc { @class.new(:name => "foo", :ensure => :absent) }.should_not raise_error
    end

    it "should accept IPv4 addresses" do
      proc { @class.new(:name => "foo", :ip => '10.96.0.1') }.should_not raise_error
    end

    it "should accept long IPv6 addresses" do
      # Taken from wikipedia article about ipv6
      proc { @class.new(:name => "foo", :ip => '2001:0db8:85a3:08d3:1319:8a2e:0370:7344') }.should_not raise_error
    end

    it "should accept one host_alias" do
      proc { @class.new(:name => "foo", :host_aliases => 'alias1') }.should_not raise_error
    end

    it "should accept multiple host_aliases" do
      proc { @class.new(:name => "foo", :host_aliases => [ 'alias1', 'alias2' ]) }.should_not raise_error
    end

    it "should accept shortened IPv6 addresses" do
      proc { @class.new(:name => "foo", :ip => '2001:db8:0:8d3:0:8a2e:70:7344') }.should_not raise_error
      proc { @class.new(:name => "foo", :ip => '::ffff:192.0.2.128') }.should_not raise_error
      proc { @class.new(:name => "foo", :ip => '::1') }.should_not raise_error
    end

    it "should not accept malformed IPv4 addresses like 192.168.0.300" do
      proc { @class.new(:name => "foo", :ip => '192.168.0.300') }.should raise_error
    end

    it "should not accept malformed IP addresses like 2001:0dg8:85a3:08d3:1319:8a2e:0370:7344" do
      proc { @class.new(:name => "foo", :ip => '2001:0dg8:85a3:08d3:1319:8a2e:0370:7344') }.should raise_error
    end

    it "should not accept spaces in resourcename" do
      proc { @class.new(:name => "foo bar") }.should raise_error
    end

    it "should not accept host_aliases with spaces" do
      proc { @class.new(:name => "foo", :host_aliases => [ 'well_formed', 'not wellformed' ]) }.should raise_error
    end

    it "should not accept empty host_aliases" do
      proc { @class.new(:name => "foo", :host_aliases => ['alias1','']) }.should raise_error
    end
  end
end
