#!/usr/bin/env rspec
require 'spec_helper'

host = Puppet::Type.type(:host)

describe host do
  before do
    @class = host
    @catalog = Puppet::Resource::Catalog.new
    @provider = stub 'provider'
    @resource = stub 'resource', :resource => nil, :provider => @provider
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

    it "should have a list host_aliases" do
      @class.attrclass(:host_aliases).ancestors.should be_include(Puppet::Property::OrderedList)
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

  describe "when syncing" do

    it "should send the first value to the provider for ip property" do
      @ip = @class.attrclass(:ip).new(:resource => @resource, :should => %w{192.168.0.1 192.168.0.2})
      @provider.expects(:ip=).with '192.168.0.1'
      @ip.sync
    end

    it "should send the first value to the provider for comment property" do
      @comment = @class.attrclass(:comment).new(:resource => @resource, :should => %w{Bazinga Notme})
      @provider.expects(:comment=).with 'Bazinga'
      @comment.sync
    end

    it "should send the joined array to the provider for host_alias" do
      @host_aliases = @class.attrclass(:host_aliases).new(:resource => @resource, :should => %w{foo bar})
      @provider.expects(:host_aliases=).with 'foo bar'
      @host_aliases.sync
    end

    it "should also use the specified delimiter for joining" do
      @host_aliases = @class.attrclass(:host_aliases).new(:resource => @resource, :should => %w{foo bar})
      @host_aliases.stubs(:delimiter).returns "\t"
      @provider.expects(:host_aliases=).with "foo\tbar"
      @host_aliases.sync
    end

    it "should care about the order of host_aliases" do
      @host_aliases = @class.attrclass(:host_aliases).new(:resource => @resource, :should => %w{foo bar})
      @host_aliases.insync?(%w{foo bar}).should == true
      @host_aliases.insync?(%w{bar foo}).should == false
    end

    it "should not consider aliases to be in sync if should is a subset of current" do
      @host_aliases = @class.attrclass(:host_aliases).new(:resource => @resource, :should => %w{foo bar})
      @host_aliases.insync?(%w{foo bar anotherone}).should == false
    end

  end
end
