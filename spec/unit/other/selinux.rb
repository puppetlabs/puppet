#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/type/selboolean'
require 'puppet/type/selmodule'

describe Puppet.type(:file), " when manipulating file contexts" do
	before :each do
	        @file = Puppet::Type::File.create(
			:name => "/tmp/foo",
			:ensure => "file",
			:seluser => "user_u",
			:selrole => "role_r",
			:seltype => "type_t",
			:selrange => "s0" )
	end
	it "should use :seluser to get/set an SELinux user file context attribute" do
		@file.property(:seluser).should == "user_u"
	end
	it "should use :selrole to get/set an SELinux role file context attribute" do
		@file.property(:selrole).should == "role_r"
	end
	it "should use :seltype to get/set an SELinux user file context attribute" do
		@file.property(:seltype).should == "type_t"
	end
	it "should use :selrange to get/set an SELinux range file context attribute" do
		@file.property(:seltype).should == "s0"
	end
	after :each do
		Puppet::Type::File.clear()
	end
end

describe Puppet.type(:selboolean), " when manipulating booleans" do
	before :each do
		@bool = Puppet::Type::Selboolean.create(
			:name => "foo",
			:value => "on",
			:persistent => true )
	end
	it "should be able to access :name" do
		@bool[:name].should == "foo"
	end
	it "should be able to access :value" do
		@bool.property(:value).should == :on
	end
	it "should set :value to off" do
		@bool[:value] = :off
		@bool.property(:value).should == :off
	end
	it "should be able to access :persistent" do
		@bool[:persistent].should == :true
	end
	it "should set :persistent to false" do
		@bool[:persistent] = false
		@bool[:persistent].should == :false
	end
	after :each do
		Puppet::Type::Selboolean.clear()
	end
end

describe Puppet.type(:selmodule), " when checking policy modules" do
	before :each do
		@module = Puppet::Type::Selmodule.create(
			:name => "foo",
			:selmoduledir => "/some/path",
			:selmodulepath => "/some/path/foo.pp",
			:syncversion => true)
	end
	it "should be able to access :name" do
		@module[:name].should == "foo"
	end
	it "should be able to access :selmoduledir" do
		@module[:selmoduledir].should == "/some/path"
	end
	it "should be able to access :selmodulepath" do
		@module[:selmodulepath].should == "/some/path/foo.pp"
	end
	it "should be able to access :syncversion" do
		@module.property(:syncversion).should == :true
	end
	it "should set the syncversion value to false" do
		@module[:syncversion] = :false
		@module.property(:syncversion).should == :false
	end
	after :each do
		Puppet::Type::Selmodule.clear()
	end
end

